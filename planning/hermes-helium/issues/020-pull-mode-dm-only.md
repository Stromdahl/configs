# 020 — Pull mode: a DM is answered, a group is refused

Type: execution
Status: resolved
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [016](016-acquire-anthropic-api-key.md), [017](017-acquire-telegram-identity.md), [019](019-service-boots-healthy.md)

## What to build

The first thing the owner can actually use: message Hermes from his phone and get an answer.
And the boundary that makes that safe — **it answers him, in DMs, and nobody else anywhere**.

- **One numeric user id in the allowlist**, from `017`, held in the sops-fed environment file.
- 🔴 **An allowlisted user is authorized *wherever they message*, groups included** — and with
  the shipped response-gate defaults (no mention required, empty chat list meaning
  **unrestricted**) even a plain unmentioned group message gets a reply. The leak this guards
  is not an attacker: it is the owner, months later, asking a question out of habit in a family
  group and getting his finances on a group screen.
- **The group block is the chat-allowlist variable set to a sentinel that is not a reachable
  chat id** — measured in `010` to stop all five group shapes while DMs pass. It goes in the
  **environment file, not the YAML config**, whose platforms block ships commented out and
  **would win if anyone uncommented it**.
- **Guest mode stays false** — the one bypass never to enable.
- **Pairing dissolves rather than being rejected**: any allowlist flips unauthorized DMs to
  silent-ignore, so no pairing code can ever be generated. ⚠️ This also closes a drift path
  where an in-app approval writes the ansible-templated environment file and is silently
  reverted on the next run.
- **The BotFather join-groups setting is deliberately not load-bearing** — BotFather state is
  invisible to ansible and to `027`'s rebuild drill, which would be this map's enemy class
  reached through its own defence.
- **Inference is Anthropic direct with the key from `016`, no router and no fallback chain.**
  🔴 A router is ruled out because the routing-preference object has six axes and **the
  scheduled path forwards only four**, silently dropping the privacy-relevant ones — so a
  restriction would hold on every DM the owner can see and be **inert on the evening brief**.
  Going direct makes that defect unreachable rather than mitigated.

A compromised Telegram account is accepted as total compromise; there is no second factor.

## Acceptance criteria

- [x] A DM from the owner gets a real answer from the model. See Progress.
- [x] The **same message in a group gets no reply.** ⚠️ Only one group shape was exercised live
      (a fresh basic group) — not all five `010` measured. The other four are covered by source
      verification, not a live test; see Progress for why that's judged sufficient here.
- [x] A DM from any other account is silently ignored, and **no pairing code is ever emitted.**
      Verified by source reading (no second Telegram account exists to test live) — see Progress.
- [x] Guest mode is off, and the YAML platforms block is left commented out. Verified on the
      live `config.yaml` on helium, not just the repo template.
- [x] An ansible re-run does not revert or duplicate the allowlist. See Progress — took three
      real runs to get a clean answer, and that's recorded honestly below.
- [x] The provider is Anthropic direct: no router configuration and no fallback chain exists.
      True by construction — `hermes.env.j2` sets no `provider`/router object at all.
- [x] The provider and model that served the exchange are recoverable afterwards from the
      state database's per-session usage table. See Progress — queried live.

## Blocked by

- [016 — Acquire the Anthropic API key](016-acquire-anthropic-api-key.md) — no answer without it.
- [017 — Acquire the real Telegram numeric id](017-acquire-telegram-identity.md) — the allowlist
  is meaningless with an unverified id.
- [019 — Hermes boots healthy](019-service-boots-healthy.md) — the service and its secrets file.

## Progress (2026-08-12)

`hermes.env.j2` now renders `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` (from `017`'s
verified id), and `TELEGRAM_ALLOWED_CHATS='0'`, in the same file and the same change as `016`'s
key — never landed separately, per `10`'s D5/D2. `TELEGRAM_GROUP_ALLOWED_CHATS` is left unset.
`config.yaml`'s `platforms:` block was left untouched.

Verified against the pinned image's own source before writing the template, not assumed from
the map's prior research:

- `gateway/config.py`'s `_apply_env_overrides`: a non-empty `TELEGRAM_BOT_TOKEN` alone
  auto-enables the platform (`_enable_from_env`) — so leaving `config.yaml`'s commented-out
  `platforms:` block alone is correct, not an oversight.
- `plugins/platforms/telegram/adapter.py`'s message-gate (`~8618-8633`): DMs return
  authorized **before** `_telegram_allowed_chats()` is ever consulted — the gate only runs for
  group/supergroup chats. `TELEGRAM_ALLOWED_CHATS='0'` therefore cannot block the owner's own
  DMs; it only ever excludes groups, since no real Telegram chat id is `0`.
- `authz_mixin.py` confirms `TELEGRAM_GROUP_ALLOWED_CHATS` is the *opposite* knob (opts specific
  groups back in) — setting it, even to `0`, would not carry the same meaning as leaving it
  unset, so it was correctly left out of the template.
- Read the **live** `config.yaml` on helium (not just the repo) in case the gateway had
  persisted its own `platforms:` block via `persist_home_channel`'s `setdefault("enabled",
  True)`: it hasn't — the file on disk still has `platforms:` and `guest_mode` fully commented
  out, so nothing overrides the env vars.

`ansible-playbook site.yml --limit helium --tags compose --check --diff` runs clean (only the
`.env` render task shows `changed`, as expected for a new template block; `no_log: true`
suppresses the secret values from the diff). Committed as `3b45a8b`, template only.

## Progress (2026-08-12, continued — deploy and live test)

Deployed for real: `ansible-playbook site.yml --limit helium --tags compose`. The `.env` render
task went `changed`, its handler restarted `hermes-agent`, and the **positive control from
`10`** passed — the "No env user allowlists configured" warning, present on every prior boot
(confirmed by grepping the full log history), is **absent** from this boot's log. Telegram
connected within ~11s (`✓ telegram connected`, `Gateway running with 1 platform(s)`).

⚠️ **`docker logs` only surfaces WARNING+ — it looked hung at "attempt 1/8" for several minutes
when it wasn't.** The full story (`Connected to Telegram (polling mode)` at INFO level) is only
in `$HERMES_HOME/logs/agent.log`, not the container's own stdout stream. Worth remembering for
any future "is it actually stuck" check on this container — check `agent.log`, not `docker logs`,
before concluding a hang.

**Live acceptance test**, both halves run by the owner from his phone:
- DM `"Ping"` to `@harmes_helium_bot` → answered. `agent.log`: `conversation turn: ...
  platform=telegram history=0 msg='Ping'` → `response ready: platform=telegram chat=8468278488
  time=8.4s api_calls=1 response=291 chars`, `model=claude-opus-4-6 provider=anthropic`.
- The same text sent in a freshly-created group (bot added as a member, `can_join_groups: true`
  since BotFather's `/setjoingroups disable` was never run, deliberately not load-bearing per
  this ticket's own design) → **zero log activity of any kind** — no `conversation turn`, no
  `response ready`, nothing. That silence is the expected shape: the message-gate at
  `adapter.py:8633` returns `False` before ever reaching the agent, and there's no log statement
  on that path. The owner also confirmed no reply appeared in the group. Only this one group
  shape (a plain new group) was exercised live — the other four `010` measured (forum/topic,
  supergroup variants, etc.) rest on the source reading recorded above, not a live test.

**Criterion 3** (a DM from any *other* account) has no live test — there's no second Telegram
account to send from. Judged sufficient from the source reading already on record: the
allow-list check in `authz_mixin.py` gates on `TELEGRAM_ALLOWED_USERS` for every DM, the
pairing-code path is only reachable when *no* allowlist is configured (10's D5, and this
boot's absent warning already proves an allowlist *is* configured), so an unlisted DM sender
falls to the same silent-ignore branch a group does.

**Criterion 5 (idempotent re-run) took three real runs to answer honestly, not two:**
1. Deploy run — `changed`, restarted the agent (expected, this was the real activation).
2. A repeat real run minutes later, run to test idempotency — **also `changed`**, and it
   restarted the agent a second time, unprompted and unwanted. The file's content hash actually
   differed byte-for-byte between these two runs (confirmed via `md5sum`, never printing the
   file), despite the template and the sops secrets being provably identical (`git status` showed
   no drift). Ran the same template through two `template` tasks back-to-back inside one
   ad-hoc playbook to isolate it — both produced identical output. Never got a diagnosis for why
   the *cross-process* render differed once; noted here rather than hidden, since a template
   that's non-deterministic exactly once is exactly the kind of thing that should be visible to
   whoever next touches this file, even without a root cause.
3. A third real run, right after — `ok`, no change, no restart. Stable from here.

Net effect: `hermes-agent` was restarted twice more than strictly necessary during this
session's own verification work (not by the design being wrong), each restart harmless
(Telegram reconnects cleanly, no state lost) but worth knowing about if anyone is comparing
gateway uptime against a deploy timestamp.

**Criterion 7**, queried live rather than assumed: `docker exec hermes-agent python3` against
`/opt/data/state.db`'s `session_model_usage` table, filtered to the DM's own `session_id`
(`20260812_133822_fcdf41d6`, read off `agent.log`) — one row with `billing_provider='anthropic'`,
`model='claude-opus-4-6'`, `task=''` (the actual conversation turn), and a second row
`billing_provider='auto'`, `task='title_generation'` (the auxiliary call that names the
conversation, unrelated to the answer itself). Confirms the provider and model are recoverable
per-session, as `020` requires.

Ticket `020` is now the third resolved tracer-bullet in a row (`016`, `017`, `020`) — Hermes
answers the owner over Telegram and refuses everyone else. `018`/`019` remain the only other
resolved tickets; the map's frontier for anything beyond pull-mode DM answering is unstaffed
until the owner opens a new ticket.
