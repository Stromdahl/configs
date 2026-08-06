# 017 — Acquire the real Telegram numeric id

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: none — can start immediately
Labels: needs-human

## What to build

The one number that authorizes the owner and addresses the evening brief — established by
measurement rather than inherited.

⚠️ **The id currently written down has no provenance.** Ticket `10` found `8468278488`
exists nowhere but a ticket body, no Telegram configuration was ever in git, and **it may be
the bot's id rather than the owner's**. Building the allowlist on it would produce a gateway
that looks locked down and answers nobody — or worse, answers the wrong account.

**One `getUpdates` call after messaging the bot yields both numbers at once**: the numeric
user id for the allowlist and the chat id the brief is delivered to. For a DM these are **the
same number**, which is why one call settles both. This is a human step: it needs the bot
token and a message actually sent from the owner's phone.

Both land in the same sops-encrypted secrets material as `016`'s key. Record which number is
which, and that they were measured rather than assumed — the next session should not have to
wonder.

## Acceptance criteria

- [ ] A `getUpdates` response is obtained showing the owner's own numeric user id, and the
      command used is recorded here.
- [ ] The id is confirmed to be the **owner's**, not the bot's, by identifying which side of
      the message it came from.
- [ ] The bot token and the id are stored in the repo's sops-encrypted secrets and decrypt on
      helium; neither appears in plaintext in git.
- [ ] It is written down that the delivery chat id and the allowlist id are the same number,
      and why.
- [ ] The stale `8468278488` is struck wherever it appears, so no later session treats it as
      verified.

## Blocked by

- None — can start immediately.
