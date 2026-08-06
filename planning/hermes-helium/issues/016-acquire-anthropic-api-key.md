# 016 — Acquire the Anthropic API key

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: none — can start immediately
Labels: needs-human

## What to build

The credential every model call in this deployment depends on, held where ansible can
template it.

**This is a human step and cannot be automated.** Ticket `09` established there is **no API
key and no provider profile on krypton**, so this is a **new metered API account** — not the
existing Claude Code subscription, and a real new cost. ⚠️ It is also governed by different
terms than the subscription: the API's no-training and 30-day-retention posture is what
`09` accepted, so the account must be an API account, not a reused login.

The key lands in the same sops-encrypted secrets material that feeds the service's
environment file, alongside the Telegram credentials from `017`. Nothing else in the build
should carry it, and it must never appear in plaintext in this repo — **this repo is public**.

Prove it works before closing: one direct call to the provider from helium, using the key as
ansible will hand it over, returning a real completion. A key that exists but was never
exercised is the shape of failure this map exists to prevent.

## Acceptance criteria

- [ ] An Anthropic **API** account exists, distinct from the Claude Code subscription, with
      billing configured.
- [ ] The key is stored in the repo's sops-encrypted secrets and decrypts on helium.
- [ ] The key appears nowhere in plaintext in git.
- [ ] One live call from helium using that key returns a completion, and the command used is
      recorded in this ticket so a later session can re-run it rather than re-derive it.
- [ ] The monthly ceiling from `09` ($25) is recorded as a **token** count with the price and
      the date it was priced — a hardcoded price table goes stale silently.

## Blocked by

- None — can start immediately.
