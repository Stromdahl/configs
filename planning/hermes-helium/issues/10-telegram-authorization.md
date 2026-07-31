# Decide the Telegram identity and authorization posture

Type: grilling
Status: open
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
