# Ticket 10 — Telegram authorization probes

Premise checks run **2026-08-06** before the grilling, per wayfinder step 3.

**Where these were established.** All five probes ran **on krypton** against the pinned
digest `nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d…` — the same image helium
will run — following ticket `08`'s precedent (helium holds no Hermes container yet).
Authorization is pure in-process logic over env vars and message shape, so nothing here
is host-dependent. Nothing was verified against a **real** Telegram bot: no token exists
yet (see D5). Probes 4 and 5 used a deliberately invalid token, which is itself the
subject of probe 5.

Source read under `/opt/hermes`; line numbers are the image's, not upstream `main`'s.

---

## 1. ✅ Identity is `from_user.id`, compared as a string

`plugins/platforms/telegram/adapter.py:960` `_source_from_message_for_auth` builds the
`SessionSource` the authorization path consumes:

```python
user_id = str(getattr(user, "id", "")).strip() or None
```

with `user` = `message.from_user`. Username is carried only as `user_name` (display), and
`gateway/authz_mixin.py:733` ends in `bool(check_ids & allowed_ids)` — plain set
membership over comma-split strings. No username matching for Telegram (SimpleX gets a
display-name fallback at `:726`; Telegram does not), no normalization, no second factor.

Channel posts with no `from_user` fall back to `sender_chat.id` (`:978`) so a broadcast
cannot slip in unauthenticated.

## 2. ✅ The authorization matrix, measured

Ran `GatewayAuthorizationMixin._is_user_authorized` directly against constructed
`SessionSource`s (the mixin needs only `adapters`/`config`/`pairing_store`, all empty
here — the bare-runner path the docstrings describe):

```bash
docker run --rm -v $SP/probe10.py:/tmp/probe10.py:ro --entrypoint bash \
  nousresearch/hermes-agent@sha256:b869e64d… \
  -c 'cd /opt/hermes && HERMES_HOME=/opt/data python /tmp/probe10.py'
```

`OWNER=8468278488` (placeholder — see D5), `OTHER=111222333`, `GROUP=-1001234567890`.

| env | DM owner | DM other | group owner | group other | anon group | channel |
|---|---|---|---|---|---|---|
| *(none)* | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `TELEGRAM_ALLOWED_USERS=<owner>` | ✅ | ❌ | **✅** | ❌ | ❌ | ❌ |
| … `+ TELEGRAM_GROUP_ALLOWED_CHATS=<group>` | ✅ | ❌ | ✅ | **✅** | **✅** | **✅** |
| `TELEGRAM_ALLOWED_USERS=*` | ✅ | **✅** | ✅ | ✅ | ❌ | ❌ |

`_get_unauthorized_dm_behavior` was read in the same run: **`pair` in row 1, `ignore` in
every other row.**

Three findings:

- **Row 2 is the leak.** `TELEGRAM_ALLOWED_USERS` is platform-wide and authorizes the
  owner in group chats too — `authz_mixin.py:686` says so in as many words
  (*"TELEGRAM_ALLOWED_USERS remains the platform-wide allowlist and still works
  everywhere for backward compatibility"*).
- **Row 3 is why `TELEGRAM_GROUP_ALLOWED_CHATS` is never used.** It authorizes *every*
  sender in the listed chat, including anonymous-admin and channel posts that carry no
  user identity at all — the chat-scoped check at `:424` deliberately runs **before** the
  `if not user_id: return False` guard at `:475`.
- **Row 1 explains `03`'s startup warning.** With no allowlist the owner is denied too;
  enrollment then runs through pairing.

## 3. ✅ Allowlist and pairing are mutually exclusive in practice

From the same run: any configured allowlist flips `_get_unauthorized_dm_behavior` to
`ignore` (`authz_mixin.py:829`). The pairing code is generated **only** inside the
`== "pair"` branch (`gateway/run.py:13687`), and `approve_code` / `approve_request`
require a pending entry. So with an allowlist set, no pending code can ever exist and
`hermes pairing approve` has nothing to approve.

This matters beyond tidiness. `PairingStore._approve_user` → `_sync_allowlist_add`
(`gateway/pairing.py:116`) → `hermes_cli.config.save_env_value`, and that function writes
**`get_hermes_home() / ".env"`** (`hermes_cli/config.py:690`) — i.e.
`/data/ssd/appdata/hermes/.env`, the file ansible templates from sops. A pairing approval
would therefore edit an ansible-managed file and be silently reverted on the next
`--tags compose` run. Under the chosen posture the path is unreachable; it is recorded as
the reason enrollment stays declarative.

## 4. ✅ The allowlist is visible when it lives **only** in `$HERMES_HOME/.env`

Load-bearing because `_get_unauthorized_dm_behavior` tests allowlist presence with a bare
`os.getenv` (`authz_mixin.py:829`), not the `secret_scope`-aware `_auth_env` used by
`_is_user_authorized`. Had `.env` not been bridged into `os.environ`, the gateway would
have DM'd pairing codes to strangers while appearing locked down.

Test and control — identical boots, differing only in one `.env` line, allowlist passed
via **no** `-e` flag:

```bash
printf 'TELEGRAM_BOT_TOKEN=…\nTELEGRAM_ALLOWED_USERS=8468278488\nANTHROPIC_API_KEY=…\n' > $D/.env
chmod 600 $D/.env && chown 1000:1000 $D/.env
timeout 45 docker run --rm -e HERMES_UID=1000 -e HERMES_GID=1000 -e HERMES_HOME=/opt/data \
  -v $D:/opt/data nousresearch/hermes-agent@sha256:b869e64d… gateway run
grep -c "No env user allowlists configured" $D/logs/gateway.log
```

| `.env` contains `TELEGRAM_ALLOWED_USERS` | `No env user allowlists configured` |
|---|---|
| yes | **0** |
| no (control) | **1** |

Both boots reached `Connecting to telegram...` and were rejected by the API, proving the
token was read from the same `.env` in both cases.

## 5. ✅ A dead Telegram transport leaves a live, cron-healthy container

Boot with a syntactically valid but unregistered token. `logs/gateway.log`:

```
INFO  gateway.run: Connecting to telegram...
ERROR …telegram.adapter: [Telegram] Failed to connect to Telegram: The token `123456789:***` was rejected by the server.
WARNING gateway.run: ✗ telegram failed to connect
WARNING gateway.run: Gateway started with no connected platforms — 1 platform(s) queued for retry: telegram: …
WARNING gateway.run: No adapter could be created for any of the 1 configured platform(s). … Gateway will continue for cron job execution.
INFO  gateway.run: Starting reconnection watcher for 1 failed platform(s): telegram
INFO  gateway.run: Reconnecting telegram (attempt 2)...
INFO  gateway.run: Reconnect telegram failed, next retry in 60s
```

The container ran until `timeout` killed it at 75 s. This is **deliberate upstream
behaviour, not an artifact of the fake token** — `gateway/run.py:6986`:

```python
elif not self.adapters and self._failed_platforms:
    # All platforms are down and queued for background reconnection.
    # Keep the gateway alive so:
    #   • cron jobs still run
```

(the `elif` at `:6987`) so a **runtime** token revocation lands in the same state as a bad
token at boot. Only when a platform is *not* retryable and nothing is queued does the
gateway stop (`:6983`).

Log strings for the healthcheck (D6), both sides:

| state | line |
|---|---|
| up | `✓ telegram connected` (`run.py:10650`), `✓ telegram reconnected successfully` (`:11743`) |
| down | `✗ telegram failed to connect` (`:10652`), `Reconnect telegram failed, next retry in 60s` (`:11799`) |

**And a third exit-code trap**, after `hermes cron status` (`03`) and `hermes doctor`
(`05`):

```console
$ hermes gateway status
✗ Gateway is not running
RC=0
```

## 6. ✅ The group response gate — every shape, measured

`_should_process_message` driven directly on constructed messages (bot id 999, handle
`@hermes_probe_bot`, `guest_mode` unset → `false`):

| message in a supergroup | defaults | `allowed_chats: "0"` |
|---|---|---|
| plain, no mention | **responds** | ignored |
| `/status@hermes_probe_bot` | responds | ignored |
| bare `/status` | responds | ignored |
| `@hermes_probe_bot balance?` | responds | ignored |
| reply to a bot message | responds | ignored |
| **DM** | responds | **responds** |

`TELEGRAM_REQUIRE_MENTION` defaults to `"false"` (`adapter.py:7686`) — hence the first
row under defaults. `_telegram_allowed_chats` (`:7757`) documents *"group messages from
chats NOT in this set are silently ignored unless `guest_mode` is enabled … DMs are never
filtered"*, and the gate at `:8634` is `if allowed and chat_id_str not in allowed: return
guest_mention`. `guest_mode` (`:7705`, default `false`) is the **only** bypass, and it
bypasses via explicit @mention — so it is the one setting that must never be turned on.

`0` is not a reachable Telegram chat id (users are positive, groups negative), so the
sentinel cannot collide with a real chat.

**Deployment surface:** the probe set `config.extra`, but `_telegram_allowed_chats` reads
`config.extra["allowed_chats"]` first and falls back to `os.getenv("TELEGRAM_ALLOWED_CHATS")`.
The volume-seeded `config.yaml` ships its whole `platforms:` block **commented out**
(verified: lines 967/973 are comments), so `config.extra` is empty and the env var is the
live path — which probe 4 already proved reaches `os.environ` from `.env`. Note the
precedence: the fallback fires only when `config.extra` returns `None`, so uncommenting
`platforms.telegram.allowed_chats` to an *empty* value would silently disable the block.

**Rotation, for the D6 check:** `gateway.log` is a `RotatingFileHandler`, default 5 MB ×
3 backups (`hermes_logging.py:312-313`), so any check keyed on "the last connect event"
loses that line at steady state. Retry cadence bounds the alternative:
`_RECONNECT_BACKOFF_CAP = 300` (`run.py:3342`), retried indefinitely for retryable
failures — so a failure line is never more than 5 minutes stale while the transport is
down.

---

## What was NOT verified

- **Nothing against a live bot.** No token exists (D5). The connect/deny paths above are
  source- and log-level facts, not an end-to-end message round-trip. The first real DM is
  the acceptance test.
- **`8468278488` is unverified and probably wrong.** It appears in this map only in
  ticket `10`'s own body; `git grep` over `4ed7e63^` finds no Telegram config in version
  control at all (`configs/hermes-agent/env.example` carries only `OPENROUTER_API_KEY` and
  `OBSIDIAN_VAULT_PATH`). Used as a placeholder in every probe above; it must be
  re-acquired, and could as easily be the bot's id as the owner's.
- **BotFather-side state.** `/setjoingroups` and `/setprivacy` were read from
  [core.telegram.org/bots/features](https://core.telegram.org/bots/features) (privacy mode
  is on by default; bots added as group **admins** receive everything regardless). Neither
  was exercised — no bot exists yet.
