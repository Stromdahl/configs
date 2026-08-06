# Choose the inference provider under full egress

Type: grilling
Status: resolved
Blocked by: 01

## Question

Egress is settled: **full egress, accepted deliberately** (map Notes). helium has
no GPU and a local LLM is an explicit PRD non-goal, so vault contents —
`finance/`, `health/`, `journal/`, `people/`, the live `tasks.md` board — and the
Proton inbox stream to a third-party inference endpoint continuously and
unattended. **The map's own Notes say provider choice "therefore carries the
weight."** This ticket carries it.

**Which provider, on what retention and no-training posture, reached how?**

### Why this is now answerable

It was fog until ticket `01` resolved, because a non-hermes-agent engine would
have changed the option set entirely. `01` settled that, and settled two things
that shape this ticket (see
[assets/01-engine-research.md](../assets/01-engine-research.md) §8):

- **Bring-your-own-key stayed first-class.** Nous Portal is *"the recommended
  way"* — recommended, not required. 30+ providers configure by plain env var in
  `~/.hermes/.env`, `OPENROUTER_API_KEY` among them, which is the exact titan
  setup. So this is a genuinely open choice, not a Portal-or-nothing one.
- **Unattended spend is separately routable.** `cron.model` routes cron jobs
  independently of the interactive default, and the drift guard fails a cron job
  *closed* rather than let it silently inherit a switch to a paid provider/model.
  So the push path and the pull path may legitimately use different providers.

### What makes this non-obvious

- **Data posture is the whole point, and it is per-provider, not per-key.**
  OpenRouter is a *router*: it forwards to upstream labs whose retention and
  training policies differ, and the effective policy is the *downstream* one, not
  OpenRouter's. Nous Portal is likewise documented as routing per-model to
  varying backends, and *"the routing for a given model can change over time."*
  A posture that depends on which backend served a request is not a posture.
  Going direct to one lab trades that away for a single, checkable policy.
- **The old setup was openrouter + BYO key.** Sunk knowledge argues for it, the
  routing opacity argues against it. This ticket has no incumbent-wins-ties rule
  — that rule was scoped to `01`.
- **Two modes, two cost shapes.** Pull is bursty and latency-sensitive; push is a
  predictable handful of scheduled runs per day, each potentially long. A
  subscription and a metered key price those very differently.
- **Failure behaviour matters more than price.** An unattended provider outage
  must be loud, not silent — this couples to `05`. What does hermes-agent's
  fallback-provider chain do to the *verification* story, and does a fallback
  hop silently change the retention posture the whole decision rested on?
- **Egress is accepted, not unbounded.** "Full egress" settled that we won't
  maintain a read include-list. It did not settle whether some things (the
  Kronofogden mail, `health/`) get a *different* provider than the rest, or
  whether that distinction is theatre for the same reason the read include-list
  was.

### What the answer must contain

1. **The provider (or providers) chosen**, and whether pull and push share one.
2. **The retention / no-training posture actually obtained**, and the mechanism —
   a published policy, an account setting, a contractual term. Name where it is
   checked, so it can be re-checked later.
3. **How routing opacity is handled** if a router or the Portal is chosen: either
   pinned single-backend models, or an explicit acceptance that the effective
   posture varies per request.
4. **Credential shape and placement** — BYO key vs OAuth vs subscription; and
   where the secret lives given the repo's sops+age convention and the fact that
   `~/.hermes/.env` is on the state volume, not in git.
5. **Fallback-provider policy**, and what a fallback hop does to (a) the
   retention posture and (b) `05`'s verification story.
6. **A cost sanity-check** at the expected push cadence, enough to notice if an
   unattended job starts running away.

`/grilling` + `/domain-modeling`. **HITL** — never answer the owner's side of it.

## Answer

**Resolved 2026-08-06.** **D1 — the one question genuinely the owner's — was put to them and
answered: *"let's do anthropic".*** The route there is worth recording, because the owner's
first response was not agreement but a clarifying question — *"Whats antropic direct?"* — and
answering it surfaced the fact that made the choice a real decision rather than a rubber
stamp: **there is no Anthropic API key and no `~/.config/anthropic` profile on krypton**
(checked; existence only, no values printed), so this is a **new metered API account**, not a
reuse of the Claude Code subscription. The administratively cheaper option — OpenRouter, where
titan-era credit may still sit — was named alongside the recommendation rather than buried,
with an explicit offer to re-spec around it. The owner took Anthropic anyway.

**D6's ceiling is called on the proposed default of $25/month**, named as a default: it is a
tripwire threshold, trivially changed later, and the owner gave a clear go-ahead without
objecting to the figure. The other five items are likewise called on defaults, the pattern
`08` set. Every capability claim below was probed against the pinned digest — transcripts,
source citations and policy quotes in
[assets/09-provider-policy.md](../assets/09-provider-policy.md).

**One execution consequence, since it is needs-human and easy to lose:** creating the API key
at `console.anthropic.com` is an owner action outside ansible's reach, in the same class as
`029`'s Proton Bridge login. `03`'s `.env` cannot be populated until it exists.

**One-line proposal: Anthropic direct, one provider for both paths, BYO API key, no
fallback chain — chosen because it is the only option where the posture does not depend on
a control the unattended path silently discards.**

### 🔴 The find that rules out routers: cron drops `data_collection`

*(It decides nothing about **this** deployment — under **D1** there is no `provider` object
to populate. It is an argument against routers and a binding constraint on any future
reversal.)*

The ticket framed routing opacity as *"a posture that depends on which backend served a
request is not a posture."* The engine turns out to make that worse in a way no reading of
the docs would surface. `provider_routing` has six axes; the gateway (pull) path forwards
all six, and **the cron (push) path forwards four** — `provider_require_parameters` and
`provider_data_collection` are simply not passed
([asset §1.3](../assets/09-provider-policy.md), `cron/scheduler.py:3490-3493` vs
`gateway/run.py:4467-4472`, plus a runtime probe of the image's own
`_provider_preferences_for_agent`). `AIAgent` defaults them to `False`/`None`, and the
preference builder omits falsy axes, so the field never reaches the wire. OpenRouter's
documented default for `data_collection` is **`"allow"`**.

So on a router, `provider_routing.data_collection: deny` sits in `config.yaml`, is honoured
on every Telegram exchange the owner can see, and is **inert on the 20:00 brief** — the one
run nobody watches, and the only one that reads `finance/` and `health/` unattended.
`hermes doctor` does not contradict it. That is the fake-weather bug wearing a different
hat, reached through the privacy control rather than the weather section.

**Two corollaries, both load-bearing:**

- **The one axis that survives to cron is `only`** — the one that actually pins the
  upstream. A router posture is therefore salvageable, but *only* through
  `provider_routing.only`, and `data_collection: deny` may never again be cited as a
  push-path control anywhere in this map.
- **Going direct makes the defect unreachable rather than mitigated.** With
  `api_mode: anthropic_messages` there is no `provider` object, no downstream lab, and no
  axis to drop. This is the difference between a boundary and an intention — the same
  distinction `08` drew at the mount layer.

### D1 — Provider: **Anthropic direct, one provider for both paths** (owner's call)

`provider: anthropic`, `base_url: https://api.anthropic.com`, native Messages API. Pull and
push share it. Four reasons, in the order they actually weigh:

1. **The posture is checkable in one place and does not vary per request.** No router, no
   per-model backend, nothing that "can change over time."
2. **No-training is a contractual term, not a toggle.** Commercial Terms §B: *"Anthropic may
   not train models on Customer Content from Services."* Contrast OpenRouter, where the
   router's own no-training promise is immediately followed by *"Some Model Providers may
   use your Inputs and Outputs for model training or improvement"*, and the mitigation is an
   **account setting** that no `no_agent` script in this design checks.
3. **The cron defect above.** Any router choice ships a privacy control that is live on the
   watched path and dead on the unwatched one.
4. ✅ **Measured, not assumed: the vault already streams to Anthropic.**
   `~/.claude/projects/-home-ms-vault/` holds **90 Claude Code sessions with `~/vault` as
   cwd, 79 MB of transcripts, 2026-07-07 → today**. This map's own charting is in that
   number — `07` read `finance/notes/email-ingest-plan.md`, `06` read
   `health/kineret-schedule.md`, `08` measured `tasks.md`. So Anthropic adds a new
   **workload**, not a new **counterparty**; every other candidate would be a genuinely new
   counterparty for exactly the data the Notes call the sensitive class. ⚠️ It does *not*
   establish matching postures — Claude Code on a subscription is governed by the consumer
   retention article, a BYO API key by the Commercial Terms plus 30-day API retention. The
   API path is the **stricter** of the two.

**Nous Portal is ruled out on its own documentation**, not on suspicion: *"OpenRouter-specific
request extensions (such as `provider` routing preferences …) are not part of the Portal's
API contract and may be ignored depending on which backend serves the model."* The single
axis that survives to cron is documented as ignorable there, so no configuration pins the
backend. Its retention default also looks like **opt-out** (a "Privacy Mode" the user
enables) — ⚠️ flagged rather than asserted: `portal.nousresearch.com/privacy` returned 429
twice and the claim rests on a search summary, so re-fetch before citing it.

**OpenRouter is not rejected as bad, it is rejected as unverifiable here.** The ticket noted
it has no incumbent-wins-ties rule; sunk knowledge from titan is real but buys nothing that
transfers, because the titan setup never had an unattended privacy posture to keep.

**Model pinning** (a default, not the owner's call): pin the cron job to
`provider: anthropic` + an explicit model rather than leaning on `cron.model` or the drift
guard. Pinned axes carry **no** drift snapshot by design
(`cron/jobs.py:1198`) — which is correct, because pinning is strictly stronger than a guard
against drift. Proposed: **`claude-sonnet-5` for the brief** (its job is summarising
already-gathered script output, not open-ended reasoning) and the interactive default left
to the owner. Cheap to raise later; **D6**'s tripwire makes the actual served model visible
either way.

⚠️ **A correction to `01`, said out loud rather than left to quietly stop applying.** `01`
handed forward *"Keep `cron.model_drift_guard` on."* Under this pin it becomes **inert for
this job** — pinned axes carry no creation-time snapshot, so the guard never engages. Leave
the setting on (it costs nothing and covers any future unpinned job), but do **not** count it
as a control here. Pinning is strictly stronger against drift; **D6**'s served-model check is
what actually verifies the pin held.

### D2 — Posture obtained, and exactly where it is re-checked

| Claim | Mechanism | Checked at |
|---|---|---|
| Inputs/outputs are **not** used for training | Contractual term (Commercial Terms §B) | <https://www.anthropic.com/legal/commercial-terms> |
| Inputs/outputs deleted within **30 days** | Published policy | <https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-personal-data> |

Named exceptions carried forward rather than buried: longer-retention or zero-retention
**agreements**, safety enforcement, legal compliance; content flagged for a Usage Policy
violation is kept *"up to 2 years"* (classifier scores 7 years). Re-check both URLs
annually and on any provider change. **ZDR is deliberately not specced** — it is an
arrangement, not a self-serve toggle, and a design that assumed it would be asserting a
posture nobody obtained.

### D3 — Routing opacity: dissolved, with a written-down contingency

Going direct removes the question: no router, no per-request variation, nothing to pin. The
ticket's item 3 asked for *either* pinned single-backend models *or* explicit acceptance of
per-request variation; the answer is neither, because the third option — remove the router —
was available.

Recorded so a future reversal starts from the truth rather than the docs:

- If a router is ever chosen, the config **must** carry `provider_routing.only: [<one
  upstream slug>]`, because that is the only axis reaching cron.
- `data_collection: deny` is **pull-path-only**. Never cite it as a push-path control.
- `allow_fallbacks` and `zdr` are not in `_provider_preferences_for_agent` at all, so
  neither is settable from Hermes config on any path; OpenRouter's `allow_fallbacks` stays
  at its default `true`.
- The cron gap is worth reporting upstream as a bug. Filing it is **not** this map's work.

### D4 — Credential shape and placement (default)

**BYO API key, `ANTHROPIC_API_KEY`, in the single sops-fed `.env` on the state volume** that
`03` already specced. The `anthropic` profile declares `auth_type="api_key"`, so this is the
supported path, and it is what makes `03`/`05`'s rebuild drill pass: *a rebuild from git plus
the age key must yield a working but amnesiac Hermes.*

**Rejected: OAuth / subscription.** The profile also accepts `CLAUDE_CODE_OAUTH_TOKEN`, and
taking it would break the drill — the token is not in sops and need not survive a rebuild —
besides raising a subscription-terms question about unattended use that this map has no
business hand-waving. A metered key is also the only shape that makes **D6** measurable.

One inherited protection worth noting: `01` found the always-on denylist blocks `write_file`
and `patch` against `.env` **anywhere on disk**, so Hermes cannot rewrite its own key
through the write tools — though the `terminal` tool escapes that, as `08` established, so
this is defence-in-depth and not a boundary.

### D5 — Fallback policy: **no chain. Fail loud instead.**

Leave `fallback_providers` unset. It is empty by default and stays empty. This is a
resolution of item 5, not a gap in it:

- **A hop is invisible to every control this map has.** The drift guard runs *before* the
  agent is built and compares creation-time snapshots to current config; a hop happens
  inside the run and changes nothing it inspects. The one-shot switch notice goes to
  `_emit_status`, and cron jobs have `messaging` disabled. The executions ledger has **no
  model or provider column at all** (asset §1.5) — the same shape of gap `08` found in
  `$HERMES_HOME/logs`.
- **A hop would silently void D2.** The whole posture rests on one provider's contractual
  term; a fallback to a second provider means the brief that read `health/` was served under
  a policy nobody chose.
- **Loud failure is already built.** A provider outage makes the cron job fail, which
  `05`'s failed-jobs-always-deliver reports, and the brief's absence is itself the alarm
  because it always arrives.

**Accepted cost, stated plainly:** an Anthropic outage at 20:00 means no brief that evening.
That is the correct failure direction for this map, and `05`'s three liveness alarms make it
noisy rather than silent.

### D6 — Cost sanity check, and the line that makes runaway visible

**The push path is nearly free by construction, and that is a design consequence, not luck.**
`06` made the interrupts a `--no-agent` script — **zero inference** — so the entire
unattended inference budget is *one agent run per day*.

Sizing it from figures other tickets already measured: `08`'s always-load read surface is
**~16,300 tokens**, plus the gathering script's stdout, `SOUL.md`, the engine's system prompt
and tool schemas. Take **~30 k input / ~2 k output** per run:

| Model | per run | per month (30 runs) |
|---|---|---|
| `claude-sonnet-5` ($3 / $15 per MTok) | ~$0.12 | **~$3.60** |
| `claude-opus-5` ($5 / $25) | ~$0.20 | ~$6.00 |
| `claude-haiku-4-5` ($1 / $5) | ~$0.04 | ~$1.20 |

Auxiliary calls (compression, titles) default to `claude-haiku-4-5-20251001` and are
rounding error. **The pull path dominates and is owner-paced** — a heavy Telegram day lands
in the low tens of dollars a month, helped by the engine's native 4-breakpoint prompt caching
(cache reads ≈ 0.1×). Order of magnitude for the whole system: **single-digit to low-tens of
dollars a month.**

⚠️ **Those are estimates, and this map does not get to ship an estimate as a control.** The
measurement exists and is `no_agent`-readable: `state.db`'s **`session_model_usage`** table
is keyed `(session_id, model, billing_provider, billing_base_url, billing_mode, task)` and
carries `api_call_count`, all five token counters, `estimated_cost_usd` and
`actual_cost_usd` (asset §1.6).

#### 🔴 But it cannot ride the footer as a same-run check — the footer is written before the run

The first draft of this section said the footer line *"makes an unannounced hop visibly
contradict the pinned config."* **That is false as specced, and it is this map's own enemy
class**, so it is corrected rather than quietly reworded. `06` established the footer is
produced by the **pre-run gathering script**, and the source confirms the ordering is strict:
the script runs at `cron/scheduler.py:2961`, its stdout is baked into the prompt at `:2977`,
the session id is not even constructed until `:3004`, and `AIAgent(...)` is not called until
`:3476`. **When the script runs, tonight's session does not exist and tonight's usage row
cannot.** A pre-run script can only ever report the *previous* run.

So the mechanism splits in two, by what each half can actually know:

**(a) The footer carries the trailing figure — labelled as trailing.** One line, from the
gathering script, about the **previous** run plus month-to-date:

```
last run: served <model> via <billing_provider> · <N> calls · <in>/<out> tok · <cost> · MTD <total>
```

Being one run behind costs nothing for the thing this line is actually for — MTD spend is
inherently trailing, and a hop is still surfaced within 24 h. It must say *"last run"*; a
figure that looks current and isn't is the defect being corrected.

**(b) The tripwire is a separate `no_agent` job, in `05`'s alarm architecture.** Scheduled
shortly after the brief, it reads tonight's row and alerts over the **existing MQTT→HA path**
on: served `model`/`billing_provider` ≠ the pinned pair, or usage over ceiling. This is where
it belongs — `05` already owns absence-alerting and fail-closed alarms, and a tripwire that
only ever prints into a document nobody diffs is not a tripwire. It is `--no-agent`, so it
adds **zero** inference.

#### Two source facts that make (b) implementable, and one that constrains it

- ✅ **No watermark needed** — unlike `07`'s UID problem.
  `_cron_session_id = f"cron_{job_id}_{now:%Y%m%d_%H%M%S}"` (`:3004`) carries a
  **per-execution timestamp**, so the accumulating `api_call_count` / token / cost columns are
  scoped to one run. Per-run figures are a plain read; MTD is a sum across rows.
- ⚠️ **Do not reconstruct the session id.** After the run, `_final_cron_session_id` may be a
  **compression-tip lineage id** rather than the id constructed at `:3004` (`:3774-3785`), so
  a reader that rebuilds `cron_<job>_<timestamp>` will sometimes find nothing. Resolve by
  recency instead — join `session_model_usage` to `sessions` and order by `last_seen`.
- ⚠️ **A third cost branch, named rather than left to discovery.** Whether
  `estimated_cost_usd` or `actual_cost_usd` is populated for a direct Anthropic provider is
  unprobed — and **neither** may be. The script must **not** carry a price table to fill the
  gap: a hardcoded per-MTok constant that silently goes stale is the fake-weather bug reached
  through the cost control. So: **token counts are the enforced quantity**, because they come
  from the API and cannot drift. The ceiling is therefore a *token* ceiling, derived once from
  the owner's dollar figure at spec time and recorded **with the price and the date it was
  derived from**, so staleness is a visible dated assumption. Dollars are printed only when a
  cost column is non-zero, and the line **names which column** it used.
- **The `task` column keeps both halves honest** — auxiliary spend (`vision`, `compression`,
  `title_generation`) is separated from the main loop, so a runaway auxiliary path cannot hide
  inside a plausible main-loop total.

**Open for the owner:** the ceiling. Proposed default **$25/month** — comfortably above the
modelled ~$4–14 and low enough to catch a loop — converted once into the token ceiling
described above.

#### Bonus trap found while checking the ordering, handed to `06`

`06` found that *a pre-run script with empty stdout skips the agent call entirely*. There is a
**second, adjacent mechanism** it did not cover: `_parse_wake_gate` (`:2406`) parses the
script's **last non-empty stdout line** as JSON and, if it is an object with
`"wakeAgent": false`, **skips the agent run entirely — no LLM call, no delivery**, returning
`SILENT_MARKER`. It fails open (any other output wakes the agent), so the hazard is narrow —
but the brief's gathering script emits structured blocks by design (`06`'s machine-readable
kineret block, `08`'s manifest diff), so the rule is cheap and worth writing down: **the
gathering script must never end its stdout with a bare JSON object**, so the gate is never
consulted at all.

### D7 — A different provider for `health/` and Kronofogden mail: **rejected as theatre**

This is the map's own question, not the owner's, and it fails for the same reason the read
include-list failed. Routing `health/` to a second provider would mean: a second credential
in the blast radius, a second policy to re-check, a second retention posture, and — decisively
— **two providers is strictly worse than one for the thing being protected**, because the
`tasks.md` board interleaves finance and health items in the same file and the brief reasons
across both in a single call. Splitting the *sources* while the *reasoning* stays joined
sends the sensitive content to both providers anyway. It buys a second counterparty and no
boundary.

Kronofogden mail is already **out of scope** — `07`'s **D8** ruled Kivra out (no IMAP, no
bridge), and it stays a weekly human check.

### What this hands to other tickets

**→ `03` (deployment shape)** — one more key in the sops-fed `.env`: `ANTHROPIC_API_KEY`.
No new mount, no new network path, no Traefik router. `provider_routing` is **not** needed in
`config.yaml` at all under D1; if it ever appears, asset §1.3 binds it.

**→ `05` (loud failure)** — gains a **new `no_agent` alarm job**, not just a query: the
post-brief tripwire in **D6(b)**, riding the existing MQTT→HA path, firing on served-model /
provider mismatch or usage over ceiling. It is the same *shape* as `08`'s **D4** manifest
diff — read durable state from outside the agent — and it plugs the provider-identity hole
`05` did not know it had, since the cron `executions` ledger records no model at all. D5's
no-fallback stance means a provider outage arrives as a failed cron job, which `05` already
delivers.

**→ `06` (brief and interrupts)** — three things, one of them a constraint:
1. One **trailing** line in the always-present footer (**D6(a)**), alongside `corrections N`
   and `07`'s examined-vs-flagged ratio. It must be labelled *"last run"* — the footer is
   written before the agent runs, so a current-looking figure would be false.
2. 🔴 **A new silent-skip path to avoid:** the gathering script must never end its stdout with
   a bare JSON object, or `_parse_wake_gate` can skip the entire brief with no delivery.
   Sibling to the empty-stdout path `06` already found.
3. **`06`'s `--no-agent` interrupt design is what makes the push path cost ~$4/month** — worth
   recording as a benefit that decision earned downstream.

**→ Out of scope, recorded not buried** — reporting the cron `provider_routing` gap upstream.
It is a real defect with a two-line fix, but filing and tracking it is not this destination's
work, and under D1 it cannot affect this deployment.
