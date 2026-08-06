# 020 — Pull mode: a DM is answered, a group is refused

Type: execution
Status: open
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
