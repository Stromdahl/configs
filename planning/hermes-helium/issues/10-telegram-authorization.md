# Decide the Telegram identity and authorization posture

Type: grilling
Status: resolved
Blocked by: 03

## Question

**How does the conversational (pull) mode establish that it is *you* messaging** —
given the agent can read `finance/`, `health/`, `journal/` and `people/`, and files
into the live vault?

This graduated out of the map's **Not yet specified** section once ticket `03`
resolved. The fog note said it needed the deployment shape first; it now has it,
plus a verified mechanism name.

### Inherited from ticket `03` (verified 2026-07-31 — don't re-derive)

- **Deny-by-default is the shipped posture.** A real boot of the pinned image with
  `gateway run` logs:

  > `WARNING gateway.run: No env user allowlists configured. Messaging platforms
  > default to pairing/allowlist policies and will deny unknown senders unless you
  > configure platform allowlists (e.g., TELEGRAM_ALLOWED_USERS=your_id) or
  > explicitly opt in with GATEWAY_ALLOW_ALL_USERS=true plus dm_policy/group_policy:
  > open on the platform.`

  So the failure mode is *silence*, not exposure — which is the right direction, but
  it also means a misconfigured allowlist presents as "Hermes ignores me", and that
  is indistinguishable from the gateway being dead unless `05`'s probe separates them.
- **`TELEGRAM_ALLOWED_USERS` is the mechanism**, and `GATEWAY_ALLOW_ALL_USERS=true`
  is the anti-pattern to name explicitly so no later session reaches for it.
- **Secrets path is settled**: the bot token comes from
  `host_vars/helium/secrets.sops.yml` → the ansible-templated
  `/data/ssd/appdata/hermes/.env` (`0600`, owner `1000:1000`). Nothing secret goes
  into compose `environment:`. If the allowlist is *not* a secret, decide whether it
  belongs in `vars.yml` instead — it is an authorization control, and config-vs-secret
  placement changes who can read it.
- Ticket `01` found the gateway has a **layered user-authorization system**, not only
  a chat-id pin. That layering is the thing to actually understand here.

### What the answer must settle

1. **Which identifier, and is it sufficient?** The v0.14 setup pinned a single chat
   id (`8468278488`). Is a numeric Telegram user/chat id an adequate authentication
   factor for an agent with this read surface, or is it merely an *addressing*
   control that happens to also gate access? Name what it does and does not defend
   against (e.g. a compromised Telegram account is game over; that may be accepted).
2. **The layers.** What `pairing` adds over an allowlist, whether both should be on,
   and what `dm_policy` / `group_policy` should be. Groups matter: decide whether
   Hermes may ever operate in a group chat at all.
3. **Recovery.** If the allowlist is wrong you get silence. What is the
   out-of-band way to fix it (`docker exec`? re-run the playbook?), and how does the
   owner tell "not allowlisted" apart from "gateway dead" — coordinate with `05`.
4. **Rebuild.** The token is needs-human on a rebuild (`03`). Is the *allowlist*
   captured declaratively so a rebuild doesn't silently come back deny-all?

### Out of scope for this ticket

Whether a *second* human (e.g. Hanna) is ever authorized — that is a scope question
for the map, not an authorization mechanism. Note it if it comes up; don't decide it here.

## Answer

**Resolved 2026-08-06.** Six probes against the pinned digest ran **before** any question
was asked, and they collapsed the ticket's four items into **two** genuine owner calls —
the shape `08` set. Items 3 and 4 turned out to be facts, not preferences, once the
mechanism was measured; they were presented, not asked. Transcripts, commands and source
citations in [assets/10-telegram-authz-probe.md](../assets/10-telegram-authz-probe.md).

The owner confirmed all four propositions put to them: the identity ceiling (D1), DM-only
enforced in-container (D2), sops placement (D5), and the healthcheck rider (D6).

🔴 **The find that shaped the ticket: `TELEGRAM_ALLOWED_USERS` is not "who may talk to
Hermes" — it is "whose messages are authorized, *wherever they arrive*."** Measured: with
the owner's id allowlisted, the owner is authorized in **group** chats too, and with the
shipped response-gate defaults (`TELEGRAM_REQUIRE_MENTION=false`, `allowed_chats` empty)
a **plain, unmentioned group message** already triggers a reply. So the founding leak is
not an attacker — it is the owner, months later, typing a question out of habit in a
family group the bot was once added to, and receiving `finance/` or `health/` content in
front of everyone. Nothing in the deny-by-default posture `03` inherited addresses this.

**One-line proposal: the allowlist is one numeric Telegram user id, held in sops and
templated into `03`'s `.env`; groups are structurally impossible via an in-container
response gate, not via BotFather; and pull-mode liveness rides `03`'s healthcheck because
a dead Telegram cannot report its own death over Telegram.**

### D1 — Identity: a numeric user id, and a compromised account is game over (owner's call)

`from_user.id`, string-compared — an **addressing** label that Telegram authenticates on
its side, not an authentication factor Hermes possesses. Named explicitly, because the
ticket asked for it:

- **Defends against:** strangers who find the bot; anyone who adds it to a group; forging
  another user's id (Telegram will not emit a client-chosen `from_user.id`); channel and
  anonymous-admin posts, which carry no identity and are denied outright.
- **Does not defend against:** anyone holding a live session on the owner's Telegram
  account — an unlocked handed-over phone, a stolen device before revocation, an account
  takeover. They get `finance/`, `health/`, `journal/`, `people/` and the `inbox/` write
  surface, in full.

**Accepted as the ceiling.** No Hermes-side second factor: a passphrase-in-chat would sit
in the very history the attacker already owns, and the real controls live where the
account lives (Telegram 2FA / cloud password, device lock). The honest mitigation is the
**revocation path** — BotFather `/revoke` invalidates the token instantly from any device,
which is a faster kill switch than editing an allowlist on helium and re-running ansible.
The offered alternative — keeping `finance/`/`health/` readable only by the push brief and
never answerable on demand — was declined; it would have gutted the pull mode's
highest-value use cases for a threat model the owner accepts.

### D2 — Groups: never, and enforced in the container (owner's call)

**`TELEGRAM_ALLOWED_CHATS=0`, in the same sops-fed `.env` as everything else.** Measured to
block all five group shapes — plain, `/cmd@bot`, bare `/cmd`, `@mention`, reply-to-bot —
while leaving DMs untouched. `0` is not a reachable Telegram chat id (users positive,
groups negative), so the sentinel cannot collide with a real chat.

✅ **The env var, not `config.yaml` — and that is a decision, not a detail.**
`_telegram_allowed_chats` (`adapter.py:7765`) reads `config.extra["allowed_chats"]` *first*
and falls back to `os.getenv("TELEGRAM_ALLOWED_CHATS")`. The image seeds an 88 KB
`config.yaml` into the volume (`03`) whose entire `platforms:` block ships **commented
out** — verified in the seeded file — so `config.extra` is empty and the env var governs.
Landing this control in a `config.yaml` nobody templates would recreate the exact
hand-wired-live-host shape `03` designed out, on the one control D2 leans on; the `.env` is
already ansible-templated and probe 4 proved it reaches `os.environ` before the gateway
reads it. **The trap to write down:** because `config.extra` wins, uncommenting
`platforms.telegram.allowed_chats` later — even to an empty value — silently disables this
block. `config.extra` is checked for `None`, not for emptiness.

⚠️ **`TELEGRAM_ALLOWED_CHATS` and `TELEGRAM_GROUP_ALLOWED_CHATS` are one word apart and do
opposite things.** The first (set to `0`) is the response gate that closes groups; the
second (never set) is the authorization footgun from probe row 3 that would open a group to
*every* sender in it, anonymous posts included. A later session skimming "set the chats one
to a weird sentinel, never set the group chats one" will conflate them, so both names are
spelled out here and in the template comment.

Two riders that are part of the decision, not commentary:

- **`guest_mode` must stay `false`** (its default). It is the single documented bypass of
  this gate, and it bypasses by explicit @mention — i.e. exactly the gesture a curious
  future session would use to "test whether groups work".
- **`TELEGRAM_GROUP_ALLOWED_CHATS` is never set.** Probe row 3: it authorizes *every*
  sender in the listed chat, including identity-less anonymous-admin and channel posts,
  because the chat-scoped check deliberately runs before the no-user-id guard.

**BotFather `/setjoingroups disable` goes on top, and is deliberately NOT the load-bearing
control.** BotFather state is invisible to ansible, absent from git and therefore invisible
to `03`/`05`'s rebuild drill — a control that looks configured forever with no verification
path, which is this map's enemy class reached through its own defence. Telegram's privacy
mode (on by default) is likewise belt-and-braces only: it still delivers `/cmd@thisbot`,
and it is bypassed entirely for a bot added as a group **admin**.

**The sentinel is itself a silent-failure shape** — a config whose meaning is "no groups"
but whose form is "a chat id" invites a later session to tidy the odd value away and
silently reopen groups. The *why* therefore belongs as a comment in the ansible template,
not only in this ticket. Suggested wording:

```bash
# TELEGRAM_ALLOWED_CHATS=0 — "0" is not a reachable Telegram chat id; it is a
# sentinel meaning "answer in no group, ever" (ticket 10/D2). An empty value
# does NOT mean "no groups", it means ALL groups. Do not remove or "fix" this.
# Not to be confused with TELEGRAM_GROUP_ALLOWED_CHATS, which does the opposite
# (authorizes everyone in a listed chat) and must stay unset.
```

**Accepted cost:** no shared-household Hermes, no asking it in a family group. Reopening
that is a deliberate decision, not a config drift — and per this ticket's scope line,
**whether Hanna is ever authorized at all remains undecided and belongs to the map.**

### D3 — Pairing: never reached, and that is a property, not a policy

Measured: any configured allowlist flips `_get_unauthorized_dm_behavior` to `ignore`, the
pairing code is generated **only** in the `pair` branch, and `hermes pairing approve`
needs a pending code to approve. So allowlist and pairing are **mutually exclusive in
practice** — the ticket's "should both be on?" dissolves. Pairing is the open-gateway
default this deployment never reaches.

Worth recording because it closes a config-drift path rather than merely avoiding it:
`PairingStore._approve_user` → `_sync_allowlist_add` → `save_env_value` writes
**`$HERMES_HOME/.env`** — the file ansible templates from sops. Had pairing been usable, an
approval would have edited an ansible-managed file and been silently reverted by the next
`--tags compose` run, leaving a user who paired successfully mysteriously locked out days
later. Under D5 the path is unreachable; it is the reason enrollment stays declarative.

`GATEWAY_ALLOW_ALL_USERS=true` and `TELEGRAM_ALLOWED_USERS=*` are named here so no later
session reaches for either: probe row 4 shows `*` authorizes **every stranger** in DMs.

### D4 — Recovery: a three-way differential, from log lines that already exist

The ticket's item 3 worry — "a misconfigured allowlist presents as *Hermes ignores me*,
indistinguishable from the gateway being dead" — is answered by evidence already emitted.
DM the bot, then read `logs/gateway.log` (or `docker logs`):

| what you see | what it means | fix |
|---|---|---|
| `WARNING [Telegram] Blocked unauthorized user <id> in chat <id>` | allowlist is wrong — **and the line carries the exact id to add** | put `<id>` in sops, re-run `--tags compose` |
| `✗ telegram failed to connect` / `Reconnect telegram failed, next retry in 60s` | transport is down: bad/revoked token, or Telegram unreachable | new token via BotFather `/token`, or wait out the outage |
| nothing at all, and `✓ telegram connected` is the last transport event | the message never arrived — bot handle wrong, or you are messaging a different bot | check the handle |

Out-of-band fix path is `--tags compose` (the safe scoped redeploy, per
`project_helium_stack_deploy_and_pin_gotchas`), **not** `docker exec`. An `exec`-time edit
of `.env` is reverted by the next playbook run — the same drift D3 found, reached
deliberately instead of accidentally.

### D5 — Placement: sops, and the id must be re-acquired (owner's call)

**`ansible/host_vars/helium/secrets.sops.yml`, alongside the bot token, templated into the
one `.env`.** Verified rather than inherited: `gh repo view` reports
`Stromdahl/configs` is **PUBLIC**. A Telegram user id is not a credential — knowing it
grants nobody anything — but it is a permanent personal identifier that would link this
repo to the owner's Telegram account, and the safer option costs *nothing*: the sops-fed
template already exists, so `vars.yml` buys no simplicity. The alternative (cleartext, on
the argument that an authorization control should be auditable at a glance) was put and
declined; `sops -d` is available any time.

✅ **Verified this placement actually works, because it was not obvious.**
`_get_unauthorized_dm_behavior` tests allowlist presence with a bare `os.getenv`, not the
`secret_scope`-aware helper used elsewhere. Test and control: with the allowlist in
`.env` only, `03`'s `No env user allowlists configured` warning is **absent** (count 0);
without it, it fires (count 1) — both boots reading the token from that same file. Had
this failed, the gateway would have DM'd **pairing codes to strangers** while appearing
locked down, and this ticket could not have resolved on the current mechanism.

⚠️ **`8468278488` has no provenance and must not be carried forward as fact.** It appears
in this map only in this ticket's own body; `git grep` over `4ed7e63^` finds no Telegram
config in version control at all (`env.example` carries only `OPENROUTER_API_KEY` and
`OBSIDIAN_VAULT_PATH`, consistent with `02`'s finding that the live host was hand-wired).
Given its shape it could as easily be the **bot's** id as the owner's.

🟢 **Resolved by [ticket 017](017-acquire-telegram-identity.md), 2026-08-12: it was the right
number.** A fresh `getUpdates` call (new bot, new token) returned the owner's real id as
`8468278488` — the same digits, now with real provenance (`is_bot: false`, distinct from the
bot's own id). Coincidence, not vindication of the old unverified value: this paragraph's
warning was correct at the time it was written, and the fix was acquiring provenance, not
picking a different number.

**Acquiring it is a needs-human step outside ansible**, in the same class as `09`'s API key
and `029`'s Proton login — recorded here rather than spun into a blocker ticket:

1. BotFather: reuse the old bot if it still exists (`/token` regenerates), else `/newbot`.
   Then `/setjoingroups disable` (D2) and confirm `/setprivacy` is enabled.
2. DM the new bot once, then
   `curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[-1].message | {from: .from.id, chat: .chat.id}'`.
3. **Both numbers come out of that one call, and for a DM they are the same number** —
   `from.id` is the allowlist value (this ticket), `chat.id` is the `--deliver telegram`
   target (`06`'s). Stated explicitly so no later session concludes one of them is wrong.
4. Both into `secrets.sops.yml` with the token; `--tags compose`.

**Rebuild (item 4) is therefore fully declarative.** `03`'s falsifiable test is "git **plus
the age key**", and under this decision the allowlist rebuilds under exactly that
precondition — a rebuilt Hermes cannot silently come back deny-all. Nothing in the
authorization posture is needs-human on a rebuild; only the *initial* acquisition is, and
only once. The one exception is named honestly: **BotFather's group setting does not
rebuild**, which is precisely why D2 does not lean on it.

### D6 — Pull-mode liveness rides `03`'s healthcheck (owner's call)

🔴 **A correction to closed work.** Measured: a rejected token leaves the gateway **up and
running cron**, retrying every 60 s, and `gateway/run.py:6987` does this on purpose
(*"Keep the gateway alive so cron jobs still run"*) — so a **runtime** token revocation
lands in the same state. `03`'s healthcheck greps cron liveness, so it reports **healthy
while pull mode is dead**. This is the second such correction to `03`'s probe after `05`'s
`ticker_last_success` find, and the pattern is worth naming: that healthcheck was designed
to answer "is cron alive?", and it keeps being asked "is Hermes working?"

**Why `05`'s existing answer does not cover it:** `05` rests on *the brief always arrives,
so silence is the alarm*, and the brief is delivered `--deliver telegram`. When Telegram
is what is broken, **the failure of the delivery channel cannot be reported over the
delivery channel** — `05`'s failed-jobs-always-deliver primitive has the same circularity.
The one failure class that takes out *both* modes at once was the one class neither mode
reported.

**Resolution:** extend `03`'s healthcheck with one further assertion — **fail if a telegram
connect-failure line appears in `logs/gateway.log` within the last 15 minutes**. It rides the existing
`HEALTHCHECK` → docker2mqtt → HA path (`046`), so **no new job and no new topic**; `09`'s
cost tripwire stays the only extra job on that path. Consistent with `03`'s own rule of
parsing output rather than exit codes — and a **third exit-code trap** is recorded here to
make the rule stick: `hermes gateway status` prints `✗ Gateway is not running` and **exits
0**, after `hermes cron status` (`03`) and `hermes doctor` (`05`).

Exact strings, so the check is written rather than described:

| state | line |
|---|---|
| up | `✓ telegram connected` (`run.py:10650`), `✓ telegram reconnected successfully` (`:11743`) |
| down | `✗ telegram failed to connect` (`:10652`), `Reconnect telegram failed, next retry in %ds` (`:11799`) |

🔴 **Why "last event wins" was rejected, and why absence must mean *healthy*.** The obvious
form — "the most recent connect/disconnect event is a success" — silently stops checking:
`gateway.log` is a `RotatingFileHandler` (default **5 MB × 3 backups**,
`hermes_logging.py:312`), so at steady state the `✓ telegram connected` line ages out and
the check finds *no event at all*. Absent-means-healthy would then be a check that has
quietly retired; absent-means-unhealthy would false-alarm after every rotation. This is the
same shape as the OTLP trap already in the map's **Out of scope** ("never succeeded is an
*absent* metric, not a zero"). The monotone form has no such hole, and the reason it is
sound is measured: a retryable failure re-logs **indefinitely at a 300 s backoff cap**
(`_RECONNECT_BACKOFF_CAP = 300`, `run.py:3342`), so while telegram is down a failure line
cannot be more than 5 minutes old — comfortably inside a 15-minute window. And the one case
that *would* go quiet is covered by the other half of the alert path: a **non-retryable**
failure drops the platform out of the reconnect queue, which takes the `not self.adapters
and not self._failed_platforms` branch (`:6983`) and **stops the gateway** — so the
container dies and `05`'s `state` entity catches it. Retryable → recurring log lines;
non-retryable → container down. No third case.

**Accepted cost, stated plainly:** a Telegram-side outage — or the seconds around a normal
restart — marks the container unhealthy while cron is fine, so "unhealthy" stops meaning
"cron is dead" and starts meaning "one of the two halves is down", with the log line
saying which. That is `03`'s own accepted direction (false alarms over silence). The
alternative — a separate `no_agent` job publishing its own MQTT topic — was put and
declined: cleaner separation, but one more moving part that can itself fail silently.

### What this hands to other tickets

- **`03`** — the healthcheck gains a second assertion (D6), and `.env` gains
  `TELEGRAM_ALLOWED_USERS` from sops (D5). Its "irreducibly needs-human on a rebuild" list
  is unchanged: the id rides the same sops file as the token.
- **`05`** — a fourth liveness fact for the alarm story: the transport can die while the
  container stays healthy, and it cannot announce that over itself. No re-open; the rider
  is D6 and it lands in `03`'s probe, on `05`'s existing path.
- **`06`** — the `--deliver telegram` chat id comes out of the *same* `getUpdates` call as
  the allowlist and is the *same number* (D5, step 3). `06` does not need its own
  acquisition step.
- **The map** — a second human (Hanna) is still undecided and still the map's question,
  not this ticket's. Nothing here forecloses it: adding an id to the allowlist is a
  one-line sops change, and D2's group block is orthogonal to it.
