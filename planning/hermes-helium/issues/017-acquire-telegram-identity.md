# 017 — Acquire the real Telegram numeric id

Type: execution
Status: resolved
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

- [x] A `getUpdates` response is obtained showing the owner's own numeric user id, and the
      command used is recorded here. See Progress.
- [x] The id is confirmed to be the **owner's**, not the bot's, by identifying which side of
      the message it came from. `from.is_bot: false`, `from.first_name: "Mattias"`, distinct
      from the bot's own id (`8853112027`, from `getMe`).
- [x] The bot token and the id are stored in the repo's sops-encrypted secrets and decrypt on
      helium; neither appears in plaintext in git.
- [x] It is written down that the delivery chat id and the allowlist id are the same number,
      and why. See Progress.
- [x] The stale `8468278488` is struck wherever it appears, so no later session treats it as
      verified. See Progress — it turned out to be the *right number*, verified for the wrong
      reason before; the fix is provenance, not a new value.

## Progress (2026-08-12)

The bot exists: BotFather created `@harmes_helium_bot` (id `8853112027`), token supplied by the
owner. `getMe` confirms it (`"username": "harmes_helium_bot"`); `getMe`'s `can_join_groups:
true` shows `/setjoingroups disable` (ticket `10`'s D2 belt-and-braces item) hasn't been run
yet — not load-bearing (the real gate is the in-container `TELEGRAM_ALLOWED_CHATS=0`, `020`'s
job), but worth doing.

**`getUpdates` after the owner DMed the bot once** ("Hi"):
```
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | python3 -m json.tool
```
```
"message": {"from": {"id": 8468278488, "is_bot": false, "first_name": "Mattias", "language_code": "sv"},
            "chat": {"id": 8468278488, "first_name": "Mattias", "type": "private"}, ...}
```

🟢 **The id is `8468278488` — the same number this ticket's own body flagged as having no
provenance.** Coincidence, not vindication: nothing before this call distinguished "correct
guess" from "verified fact," and the whole reason this ticket exists is that a number with no
provenance is unusable regardless of whether it happens to be right. It is now verified the
way `10`/`017` specified — read off a real message, `is_bot: false`, matched against `getMe`'s
distinct bot id — so the **stale flag is struck**, not the number.

`from.id` and `chat.id` are the same number (`8468278488`) because this was a DM — confirming
ticket `10`'s D5: for a private chat, the allowlist identity and the `--deliver telegram`
target are identical, by construction, not by luck.

Both secrets now in `secrets.sops.yml` (`sops set … --value-file`, same mechanism as `016`,
round-trip verified via `md5sum`, never decrypted to stdout): `telegram_bot_token` (already
landed alongside `016`'s key) and now `telegram_user_id`. Decryption confirmed:
`sops -d --extract` reproduces the same `md5sum` as the source value.

**Deliberately still not wired into the running container.** Both secrets exist in sops; the
gateway's Telegram platform stays off until `020` lands `TELEGRAM_ALLOWED_USERS` and
`TELEGRAM_ALLOWED_CHATS=0` in the same change that turns the token on — per `10`'s D5/D2, one
without the other is either mute or an open pairing surface, never a safe intermediate state.

## Blocked by

- None — can start immediately.
