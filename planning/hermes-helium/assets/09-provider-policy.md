# Asset — provider policy + routing-control probe (ticket 09)

Companion to [issues/09-choose-inference-provider.md](../issues/09-choose-inference-provider.md).
Two halves: **§1** is what hermes-agent can actually enforce, probed against the pinned
digest; **§2** is the published policy of each candidate, quoted with a URL so item 2's
*"name where it is checked"* is satisfied.

Tag legend — **✅ probed** on the pinned image / on the box; **[SRC]** read from the
image's own source; **[DOC]** quoted from vendor docs (URL + fetch date); **⚠️** caveat.

Probes run **2026-08-06 on krypton** against
`nousresearch/hermes-agent@sha256:b869e64d6496…` (the `01` pin), source extracted from
`/opt/hermes`. helium was not required — every finding here is image- or docs-level.

---

## 1. What the engine can enforce

### 1.1 The provider registry and the Anthropic profile

34 provider plugins ship under `plugins/model-providers/`. The `anthropic` one matters
most for the decision below:

```python
# plugins/model-providers/anthropic/__init__.py            [SRC]
anthropic = AnthropicProfile(
    name="anthropic",
    aliases=("claude", "claude-oauth", "claude-code"),
    api_mode="anthropic_messages",
    env_vars=("ANTHROPIC_API_KEY", "ANTHROPIC_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"),
    base_url="https://api.anthropic.com",
    auth_type="api_key",
    default_aux_model="claude-haiku-4-5-20251001",
)
```

Three things this settles:

- **`auth_type="api_key"`** — a plain key in `~/.hermes/.env`, which is what `03`'s
  sops-fed `.env` already carries. **This is what makes the rebuild drill pass**
  (`03`/`05`: *rebuild from git + the age key ⇒ working but amnesiac Hermes*). An OAuth
  or subscription login would not: the token is not in sops and need not survive a
  rebuild.
- **`api_mode="anthropic_messages"`** — the native Messages API, not an
  OpenAI-compatible shim. So there is no router in the path at all.
- **`default_aux_model`** — auxiliary calls (compression, title generation, vision)
  route to `claude-haiku-4-5-20251001` by default. **Auxiliary calls are a second,
  quieter egress path**, and they are billed and recorded separately (see §1.6's
  `task` column).

### 1.2 `provider_routing` — the six axes, and where they are read

`config.yaml` carries a `provider_routing` block. The loader:

```python
# gateway/run.py:7994                                       [SRC]
def _load_provider_routing() -> dict:
    ...
    return cfg.get("provider_routing", {}) or {}
```

Its keys map onto OpenRouter's top-level `provider` object via
`_provider_preferences_for_agent`:

| `provider_routing` key | → OpenRouter `provider.*` |
|---|---|
| `only` | `only` |
| `ignore` | `ignore` |
| `order` | `order` |
| `sort` | `sort` |
| `require_parameters` | `require_parameters` |
| `data_collection` | `data_collection` |

The image's own tip strings confirm the intent [SRC `hermes_cli/tips.py:375-376`]:

> `provider_routing.data_collection: deny excludes data-storing providers on OpenRouter.`
> `provider_routing.require_parameters: true only routes to providers that support every param in your request.`

**Not reachable at all:** `allow_fallbacks` and `zdr` are absent from
`_provider_preferences_for_agent`, so neither can be set from Hermes config on any path.
OpenRouter's `allow_fallbacks` therefore stays at its documented default of `true`.

### 1.3 🔴 The load-bearing defect: cron drops two of the six axes

The gateway (pull) path forwards all six:

```python
# gateway/run.py:4467-4472                                  [SRC]
providers_allowed=pr.get("only"),
providers_ignored=pr.get("ignore"),
providers_order=pr.get("order"),
provider_sort=pr.get("sort"),
provider_require_parameters=pr.get("require_parameters", False),
provider_data_collection=pr.get("data_collection"),
```

The cron (push) path forwards **four**:

```python
# cron/scheduler.py:3490-3493                               [SRC]
providers_allowed=pr.get("only"),
providers_ignored=pr.get("ignore"),
providers_order=pr.get("order"),
provider_sort=pr.get("sort"),
# provider_require_parameters — NOT PASSED
# provider_data_collection    — NOT PASSED
```

`AIAgent` defaults them to `False` / `None` [SRC `run_agent.py:458-459`], and
`_provider_preferences_for_agent` omits any falsy axis — so the key is simply absent from
the request body.

✅ **Probed** — the two paths' preference objects, built by the image's own function:

```
$ docker run --rm --entrypoint bash <pinned digest> -c 'cd /opt/hermes && python - <<EOF
from agent.chat_completion_helpers import _provider_preferences_for_agent as f
...
gateway : {'only': ['anthropic'], 'require_parameters': True, 'data_collection': 'deny'}
cron    : {'only': ['anthropic']}
```

**Why this is exactly this map's enemy class:** `data_collection: deny` sits in
`config.yaml`, `hermes doctor` does not contradict it, and it *works* every time the owner
chats over Telegram. It is inert only on the unattended path — the one nobody watches, and
the one that streams `finance/`, `health/` and the inbox. A privacy control that looks
configured and silently is not, on the push path, is the fake-weather bug wearing a
different hat.

**And the one axis that survives is the one that actually binds.** `only` — which pins the
upstream to a named provider slug — *is* forwarded to cron. So a router posture is
salvageable, but only through `only`, never through `data_collection`.

### 1.4 Fallback chain — opt-in, and invisible to every existing control

- **Empty unless configured.** `get_fallback_chain(cfg)` merges `fallback_providers` and
  legacy `fallback_model`; with neither key present it returns `[]`
  [SRC `hermes_cli/fallback_config.py:71`]. Cron passes
  `fallback_model = get_fallback_chain(_cfg) or None` [SRC `cron/scheduler.py:3436`].
- **It fires inside the run**, on retry exhaustion / rate-limit / billing failure
  (`try_activate_fallback`, [SRC `agent/chat_completion_helpers.py:1694`]), swapping the
  client, model slug and provider in place.
- 🔴 **The drift guard cannot see it.** The guard runs *before* the agent is constructed
  and compares creation-time snapshots against current global config
  [SRC `cron/scheduler.py:3368-3435`]. A fallback hop happens later, inside the run, and
  changes nothing it inspects.
- 🔴 **The switch notice cannot reach anyone unattended.** It is emitted once via
  `_emit_status` [SRC `run_agent.py:1113`] — and `01` established that cron jobs have the
  `messaging` toolset disabled.
- ⚠️ **Also worth knowing about the guard:** it snapshots **only unpinned axes** —
  *"Pinned axes and no-agent script jobs intentionally carry no snapshot"*
  [SRC `cron/jobs.py:1198-1231`] — and an axis resolved from an explicit `cron.model` is
  *not* treated as drift [SRC `cron/scheduler.py:3162-3163`]. Pinning is strictly stronger
  than the guard; it is not a hole.

### 1.5 The cron executions ledger records no model or provider

```sql
-- cron/executions.py:38-51                                 [SRC]
CREATE TABLE IF NOT EXISTS executions (
  id, job_id, source, process_id, pid, process_started_at,
  status, claimed_at, started_at, finished_at, error
)
```

So *"which model actually served last night's brief"* is **not** answerable from the cron
ledger. That is the same shape of gap `08` found in `$HERMES_HOME/logs` for the write
surface.

### 1.6 ✅ But `state.db` does record it — per model, per provider, with cost

```sql
-- hermes_state_common.py:218 / hermes_state_schema.py:521   [SRC]
CREATE TABLE session_model_usage (
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  model TEXT NOT NULL,
  billing_provider TEXT NOT NULL DEFAULT '',
  billing_base_url TEXT NOT NULL DEFAULT '',
  billing_mode TEXT NOT NULL DEFAULT '',
  task TEXT NOT NULL DEFAULT '',        -- '' = main loop; 'vision'/'compression'/…
  api_call_count INTEGER NOT NULL DEFAULT 0,
  input_tokens, output_tokens, cache_read_tokens,
  cache_write_tokens, reasoning_tokens INTEGER NOT NULL DEFAULT 0,
  estimated_cost_usd REAL NOT NULL DEFAULT 0,
  actual_cost_usd REAL NOT NULL DEFAULT 0,
  cost_status TEXT, cost_source TEXT, first_seen REAL, last_seen REAL,
  PRIMARY KEY (session_id, model, billing_provider, billing_base_url, billing_mode, task)
)
```

This is the falsifiable hook for **both** item 5 and item 6, and it is `no_agent`-readable
(plain SQLite on the state volume, same file `05` already reaches for `ticker_last_success`):

- **Item 5** — a fallback hop writes a *second row* for the same `session_id` with a
  different `model` / `billing_provider`. Printing the served model in the brief footer
  makes an unannounced hop visibly contradict the pinned config.
- **Item 6** — `api_call_count` + token columns + `estimated_cost_usd` give a real spend
  figure per run, and the `task` column separates the main loop from auxiliary calls, so
  a runaway auxiliary path can't hide inside a plausible main-loop total.

⚠️ **`estimated_cost_usd` vs `actual_cost_usd`** — both columns exist with a `cost_status`
/ `cost_source` pair; which one is populated for a given provider was **not** probed, and
**neither** may be. A consumer must print whichever is non-zero and name it — and must not
substitute a hardcoded price table, which would go stale silently.

### 1.7 ✅ Ordering: the pre-run script runs before the session exists

Probed by reading the run path in order [SRC `cron/scheduler.py`]:

| line | step |
|---|---|
| `:2961` | `prerun_script = _run_job_script_with_claim_heartbeat(job, script_path)` |
| `:2963` | `_parse_wake_gate(_script_output)` — a trailing `{"wakeAgent": false}` **skips the agent entirely** |
| `:2977` | `prompt = _build_job_prompt(job, prerun_script=prerun_script)` — stdout baked into `## Script Output` |
| `:3004` | `_cron_session_id = f"cron_{job_id}_{now:%Y%m%d_%H%M%S}"` — session id first exists here |
| `:3476` | `AIAgent(...)` constructed |

⇒ **A pre-run gathering script cannot read its own run's `session_model_usage` row** — the
session id does not exist yet, let alone the row. Any same-run cost or served-model check
must be a *separate, later* job. A pre-run script can only report the **previous** run.

Two riders:

- ✅ **Per-execution scoping, so no watermark is needed.** The session id embeds a
  `%Y%m%d_%H%M%S` timestamp, so the accumulating counters in §1.6 are scoped to one run.
  Contrast `07`'s UID-watermark problem — that shape does not recur here.
- ⚠️ **Do not reconstruct the id.** After the run, `_final_cron_session_id` may resolve to a
  **compression-tip lineage id** instead of the constructed one
  [SRC `cron/scheduler.py:3774-3785`], so a reader that rebuilds `cron_<job>_<ts>` will
  sometimes find no row. Resolve by recency — join to `sessions`, order by `last_seen`.

### 1.8 ⚠️ `_parse_wake_gate` — a second silent-skip path

```python
# cron/scheduler.py:2406                                    [SRC]
"""...if the last stdout line is JSON like ``{"wakeAgent": false}``, the agent is
skipped entirely — no LLM run, no delivery. Any other output (non-JSON, missing
flag, gate absent, or ``wakeAgent: true``) means wake the agent normally."""
```

It **fails open** — only an explicit `false` skips — so the hazard is narrow. But it parses
the last non-empty stdout line of *every* pre-run script, and this design's gathering script
emits structured blocks by construction (`06`'s machine-readable kineret block, `08`'s
manifest diff). Sibling to the empty-stdout skip `06` already documented; the cheap rule is
to never end stdout with a bare JSON object.

### 1.9 Prompt caching is implemented, natively, with 4 breakpoints

> *"The default layout uses 4 cache_control breakpoints: the static system…"*
> [SRC `agent/prompt_caching.py:3`]

`apply_anthropic_cache_control` / `strip_anthropic_cache_control` exist, and
`_use_prompt_caching` is refreshed on a fallback hop [SRC `agent/conversation_loop.py:900`].
This materially changes the **pull**-path cost shape: a long Telegram conversation re-reads
its prefix at cache-read rates rather than full input rates.

---

## 2. Provider policy — quoted, dated, and where to re-check

Fetched **2026-08-06**.

### 2.1 Anthropic (direct API, BYO key)

**No-training is a contractual term, not a setting.** Commercial Terms of Service, §B
(Customer Content) — <https://www.anthropic.com/legal/commercial-terms>:

> "Anthropic may not train models on Customer Content from Services."

**Retention is a published number.** <https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-personal-data>:

> "For Anthropic API users, we automatically delete inputs and outputs on our backend
> within 30 days of receipt or generation"

…with named exceptions: longer-retention agreements, **zero-data-retention agreements**,
safety enforcement, and legal compliance. Content flagged for a Usage Policy violation is
retained *"for up to 2 years and trust and safety classification scores for up to 7 years."*

⚠️ **Two caveats to carry forward, not to bury:**

1. **ZDR is an agreement, not a toggle.** The page lists it as an exception to the 30-day
   default, reachable by arrangement. Do **not** spec a posture that assumes it.
2. **The consumer article is a different document.** <https://privacy.claude.com/en/articles/10023548-how-long-do-you-store-my-data>
   opens by saying it covers *"Claude Free, Pro, Max and when accounts from those plans use
   Claude Code"* and points elsewhere for *"the Anthropic API"*. So Claude Code on a
   subscription and the API are governed by **different** documents — see §3's note.

### 2.2 OpenRouter (router; the titan incumbent)

<https://openrouter.ai/privacy>:

> "OpenRouter does not use your Inputs or Outputs for model training."

…immediately followed by the caveat that makes it a router and not a provider:

> "Some Model Providers may use your Inputs and Outputs for model training or improvement."

<https://openrouter.ai/docs/features/privacy-and-logging>:

> "If you opt out of training in your account settings, OpenRouter will not route to
> providers that train."

…and per-request, users can *"restrict individual requests to only use providers with a
certain data policy."* Note also: *"This setting has no bearing on OpenRouter's own
policies and what we do with your prompts."*

<https://openrouter.ai/docs/features/provider-routing> — the `provider` object:

| field | values | default |
|---|---|---|
| `data_collection` | `"allow"` \| `"deny"` | **`"allow"`** |
| `allow_fallbacks` | boolean | **`true`** |
| `require_parameters` | boolean | `false` |
| `only` / `ignore` / `order` | provider slugs | — |
| `zdr` | boolean | — |

`data_collection: "deny"` means *"use only providers which do not collect user data"*.

🔴 **Cross-referencing §1.3:** the default is `"allow"`, and the cron path never sends the
field. So on OpenRouter, **an unattended Hermes job routes to data-collecting upstreams by
default, no matter what `config.yaml` says.** The account-level training opt-out is a
partial mitigation — it excludes providers that *train* — but it is a different predicate
from *collect*, and it is an account setting no `no_agent` script in this design checks.

### 2.3 Nous Portal (the vendor's "recommended way")

**Its own docs disclaim the control this decision would rest on.**
<https://hermes-agent.nousresearch.com/docs/integrations/nous-portal>:

> "Under the hood, the Portal routes each model to the backend best suited for it — some
> models go through OpenRouter, others through proprietary or secondary providers, and the
> routing for a given model can change over time."

> "OpenRouter-specific request extensions (such as `provider` routing preferences,
> `session_id` sticky routing, or top-level `cache_control`) are not part of the Portal's
> API contract and may be ignored depending on which backend serves the model."

So on the Portal, `only` — the one axis that survives to cron (§1.3) — is **documented as
ignorable**. There is no configuration that pins the backend.

⚠️ **Retention posture (lower-confidence source).** <https://portal.nousresearch.com/privacy>
returned **HTTP 429** on two direct fetch attempts; the following is from a search-result
summary of that page and is **not** a verbatim quote — re-fetch before relying on it:

> Users may elect to enable "Privacy Mode," which allows them to opt out of the storage and
> use of certain inference payloads for training, product improvement, and support purposes.

If that summary is accurate, the Portal's default is **opt-out** — payloads stored and used
for training unless Privacy Mode is switched on — which is the opposite default from
Anthropic's contractual no-training. Flagged rather than asserted.

### 2.4 Pricing, for the item-6 arithmetic

From the `claude-api` skill's model table (cached **2026-06-24** — re-check at
<https://platform.claude.com/docs/en/pricing>), USD per million tokens:

| Model | Input | Output |
|---|---|---|
| Claude Opus 5 (`claude-opus-5`) | $5.00 | $25.00 |
| Claude Sonnet 5 (`claude-sonnet-5`) | $3.00 (intro $2.00 through 2026-08-31) | $15.00 (intro $10.00) |
| Claude Haiku 4.5 (`claude-haiku-4-5`) | $1.00 | $5.00 |

Prompt caching: cache **reads** ≈ 0.1×, cache **writes** ≈ 1.25× (5-minute TTL).

---

## 3. ✅ The vault already streams to Anthropic — measured, not assumed

The Notes call full egress *"streamed to an inference endpoint"* as a new sensitivity
class. For **Anthropic specifically** that ship has sailed, and it is checkable on the box:

```
$ ls ~/.claude/projects/-home-ms-vault/*.jsonl | wc -l
90
$ du -sh ~/.claude/projects/-home-ms-vault
79M
   oldest: Jul  7 23:17      newest: Aug  6 07:45
```

**90 Claude Code sessions with `~/vault` as the working directory, 79 MB of transcripts,
over the last month — the newest today.** This map's own charting is part of that: `07`
read `~/vault/finance/notes/email-ingest-plan.md`, `06` read
`~/vault/health/kineret-schedule.md`, and `08` measured `~/vault/tasks.md`. All three files
exist and all three were read by Claude Code sessions.

⚠️ **What this does and does not establish.** It establishes **which company** already holds
vault content — so choosing Anthropic adds a new *workload*, not a new *counterparty*. It
does **not** establish that the postures match: per §2.1's second caveat, Claude Code on a
subscription is governed by the consumer article, while a BYO API key is governed by the
Commercial Terms plus the 30-day API retention. Those are different documents, and the
API-key path is the **stricter** of the two (contractual no-training). Any other provider
would be a genuinely new counterparty for this data.
