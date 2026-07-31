# Design the loud-failure / verification story

Type: grilling
Status: open
Blocked by: 01, 03

## Question

**How do you know Hermes is actually working — and how does it tell you when it
isn't?** Design the verification story for an agent you are trusting to watch your
email unattended.

This is the trust half of the destination. It is in scope *by construction*, not as
ops polish: the map's diagnosis is that Hermes died of host churn **and** lost
trust, and every trust loss in this homelab's history has been a **silent** one.

### Inherited from ticket `01` (verified 2026-07-31 — don't re-derive)

From [assets/01-engine-research.md](../assets/01-engine-research.md) §4, §5c. **This
is the ticket `01` said carries the map's weight** — read that before designing.

**What the engine already fails loudly about** (keep these on, don't rebuild them):

- **Model/provider drift guard, on by default.** An unpinned cron job whose global
  default changed *skips the run, makes no inference call, and alerts you.* Do not
  set `cron.model_drift_guard: false`.
- *"Failed jobs always deliver regardless of the `[SILENT]` marker — only
  successful runs can be silenced."*
- **`no_agent=True` script jobs**: non-zero exit or timeout → an error alert is
  delivered, *"so a broken watchdog can't fail silently."* No LLM in the path.
- Zero delivery targets is *"recorded as a delivery failure upstream."*
- `display.file_mutation_verifier` (default on) flags a failed `write_file`/`patch`
  that was never superseded — aimed at *"model summarises success"* over-claim.

**The gap none of it closes — and it is exactly our enemy.** Every mechanism above
catches crashes, non-delivery, and failed writes. **None catches
plausible-but-fabricated content.** The v0.14 fake weather was hardcoded constants
in the gathering script: exit 0, non-empty stdout, delivery succeeded. `no_agent`
would have shipped it too. **So this ticket must assert on freshness of content,
from outside hermes-agent's own cron.**

**Two hard constraints on how:**

- Cron jobs run with the `cronjob`, `messaging`, and `clarify` toolsets
  **disabled**. The agent **cannot message you from inside a cron job** (delivery
  is scheduler-only), and an approval escalation under `approvals.mode: smart` has
  nowhere to escalate. A heartbeat must be a `no_agent` script or fully external.
- **There is no container `HEALTHCHECK`** and the gateway auto-restarts under s6,
  so a crash-looping gateway looks healthy while cron never ticks (`03` adds the probe).

**Read ground truth, never ask the agent about itself.** `01` could not verify
that v0.14's self-internals confabulation is fixed — the upstream tracker has zero
matching issues, so there is nothing to check. Treat it as unresolved and build on
`hermes cron list`, `hermes doctor`, `hermes logs`, `~/.hermes/logs/agent.log` and
`errors.log`, and `~/.hermes/cron/jobs.json`. Note `/journey` is **CLI-only** — not
available on messaging, so memory inspection needs a shell into the container.

**Documented silent-failure paths to design against** (all from upstream's own
troubleshooting guide): misformatted schedule *"silently defaults to one-shot"*;
misconfigured delivery target *"silently drops the response"* while the job still
runs; unreadable `jobs.json` → *"the scheduler will fail silently"*; two gateway
instances → jobs *"delayed or skipped"*; any response *containing* `[SILENT]`;
and a per-job `last_error` field upstream itself hedges as *"(if available)"*.

### The evidence this ticket exists to answer

- The morning briefing shipped **hardcoded fake weather** (11.3 °C / Sunny / 63% /
  4.68 km/h — never queried HA) for an unknown span. It looked like a briefing.
- `Sync/Hermes-Claude-Bridge.md` was written to as if it were an integration;
  grep-confirmed **nothing ever read it**. Items added there silently vanished.
- The **Proton bridge session dies** when Proton invalidates it and Paperless
  surfaces **no error** — mail ingest just stops. The only tell built was a
  Homepage container-status tile, which does *not* catch a live-but-unauthenticated
  bridge.
- Hermes **confabulated its own internals** when asked how it worked — so *asking
  the agent* is not a verification channel.
- Non-Hermes but same disease: helium's HDDs return `rc=0` to spin-down commands
  and keep spinning; `/proc/mounts` reported `rw` while ext4 had aborted the
  journal (`project_helium_disk2_io_fault`).

The shared shape: **absence of output is indistinguishable from nothing to report.**
A quiet evening brief could mean a calm day or a dead agent, and there is no way to
tell from the outside. That ambiguity is the thing to design away.

### What the answer must settle

1. **Liveness vs correctness.** Two different failures: the agent is dead/stalled,
   vs the agent is running but its inputs are broken (dead bridge session, expired
   provider key, unreachable vault). Both need a tell; they are not the same tell.
2. **The no-news problem.** Does the evening brief always arrive — even as "nothing
   to report, N mails triaged, all sources OK" — so that *silence itself* is the
   alarm? Recommended shape, and the reason the v0.14 rewrite added per-source
   `STATUS=OK/ERROR` (reusable prior art, see ticket `02`). Note the cron framework
   injects a "respond `[SILENT]` if nothing to report" instruction — which is
   **directly at odds** with always-report and must be reconciled.
3. **Per-source status.** Every input Hermes depends on reports OK/ERROR explicitly,
   so a fetch failure is never rendered as an empty section. Enumerate the sources.
4. **Where alerts land when the agent itself is the thing that's down.** Telegram is
   the channel, but Hermes *sends* the Telegram messages — a dead agent cannot
   report its own death. Needs an out-of-band watchdog. Candidates: a systemd
   `OnFailure`, helium's existing storage-timer failure alerting (`issues/013`), the
   Home Assistant + MQTT path already carrying helium's metrics (`issues/046`,
   `project_helium_metrics_mqtt_ha`), or a Homepage tile. HA/MQTT is already wired
   and already reaches the phone — likely the cheapest real answer.
5. **An audit trail you can read without asking the agent.** `~/vault` is a git
   repo, so every vault write Hermes makes is a commit-able, diffable, revertable
   record — decide whether Hermes commits its own writes, or something else does,
   and whether `/journey` (v0.19 memory timeline) is part of the trail.
6. **A periodic proof-of-correctness, not just proof-of-life.** The fake-weather bug
   would have survived every liveness check ever written. What check would have
   caught it?

### Deliberately deferred to the resolution, not pre-decided

Whether this needs its own monitoring plumbing or can ride entirely on what helium
already has (MQTT→HA, Homepage, restic/timer alerting). Prefer riding existing
plumbing — new monitoring is one more thing that can fail silently.
