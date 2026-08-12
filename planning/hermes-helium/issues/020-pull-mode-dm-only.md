# 020 — Pull mode: a DM is answered, a group is refused

Type: execution
Status: in-progress
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

- [ ] A DM from the owner gets a real answer from the model.
- [ ] The **same message in a group gets no reply** — tested across the group shapes `010`
      measured, not just one.
- [ ] A DM from any other account is silently ignored, and **no pairing code is ever emitted**.
- [ ] Guest mode is off, and the YAML platforms block is left commented out.
- [ ] An ansible re-run does not revert or duplicate the allowlist.
- [ ] The provider is Anthropic direct: no router configuration and no fallback chain exists.
- [ ] The provider and model that served the exchange are recoverable afterwards from the
      state database's per-session usage table.

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

**Not yet done — needs the actual deploy and live acceptance test, both of which need the
owner:**
- The real `ansible-playbook … --tags compose` run (no `--check`) against helium, restarting
  `hermes-agent` so it picks up the new `.env`.
- After restart, before calling anything verified: confirm the "no allowlists configured"
  startup warning is **absent** from the container logs (ticket `10`'s positive control that
  the allowlist actually bridged from `.env`, not silently empty).
- The live acceptance test itself — a DM from the owner answered, the identical message in a
  **group** refused. The group half needs the owner to actually add the bot to a group and send
  from it; that can't be exercised solo.
- A second post-deploy `--check` run to confirm the render task goes `ok` (idempotent), closing
  acceptance criterion 5.
- Criterion 7 (provider/model recoverable from `session_model_usage`) — query `state.db` after
  the DM exchange.
