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

### Inherited from ticket `02` (verified 2026-07-31 — don't re-derive)

The prior art this ticket kept referring to has now been read and judged
([verdict table](02-recover-briefings-branch-inventory.md#answer)). Four things:

- **`SOUL.md` is a control, not decoration — assert on it.** It already states, in
  prose, the two rules §4 found no primitive enforces: *"When data is missing or a
  source failed, say so plainly. Never paper over a gap or present a failed lookup
  as 'nothing to report'"* and *"Only state what you can verify from the data in
  front of you. Do not invent events, news, or reminders from prior knowledge."*
  Given that nothing catches plausible-but-fabricated content, **this file is
  currently the only defence** — so verification must confirm it is present and
  loaded (it was hand-copied on titan, and the original there was the empty
  default), not assume it.
- **The reusable contract, exactly as written:** each source emits
  `<name>: STATUS=OK count=<n>` or `<name>: STATUS=ERROR reason="…"`; the renderer
  shows OK-with-data, omits `count=0`, and surfaces `ERROR` as `⚠️ <section>:
  unavailable` — *never* as empty or quiet. Plus `<verbatim>…</verbatim>` for
  character-for-character passthrough of safety-critical text, and all date math in
  the script so the model never computes a date.
- **A worked example of exactly the failure this ticket hunts — in the file that
  fixed the previous one.** `emit_labs` hardcodes a month list (`2026-05..2026-10`,
  `2027-01`, `2027-04`) and its fallthrough emits `STATUS=OK count=0`, which the
  prompt then *omits*. From **2027-05** a health source silently vanishes forever
  while reporting healthy-and-empty. Generalize it: **an expired or exhausted
  schedule must be `ERROR`, not `count=0`** — "no data because the config ran out"
  and "no data because nothing is due" must not share a status.
- **One prompt line is now unexecutable, and its failure mode is silent.** All three
  recovered prompts end with *"Then send the finished briefing to Mattias on
  Telegram"* — impossible inside a cron job (`messaging` disabled; delivery is
  scheduler-only). An agent instructed to do something it cannot may well report
  having done it. Delivery is job configuration; keep it out of prompt text.
- **No artifact to purge — the threat is unchanged:** the fake-weather script was
  **never in this repo** — the recovered `emit_weather` genuinely queries HA and returns
  `STATUS=ERROR` on every failure path. The bug lived only on titan, outside version
  control. The lesson is the per-source status lines, which is why they are the thing
  to keep.

### Inherited from ticket `03` (verified on the box 2026-07-31 — don't re-derive)

Every item here was produced by booting the pinned image on helium, not read from
docs. See [ticket 03's Answer](03-deployment-shape-and-state.md#answer).

- **This ticket inherits an acceptance test, agreed with the owner:** *a rebuild from
  git alone must yield a working but amnesiac Hermes.* `03` split rebuild state by
  authorship (human-authored → git/ansible; agent-accumulated → restic), and that
  test is what makes the split falsifiable. If it fails, something is hand-installed
  and the v0.14 trap has been rebuilt. **Designing how that test is actually run — and
  how often — is this ticket's.**
- **A probe now exists and `03` guarantees only one property**: it cannot report
  healthy while cron is dead. What it *alerts*, to whom, and how loudly is yours.
  The path `HEALTHCHECK` → docker2mqtt health entity → MQTT → HA already exists
  (issue `046`).
- **Two silent-success traps were found and closed; treat them as the calibration for
  what else to look for.**
  1. **The image's default CMD exits 0.** It is the interactive `hermes` CLI; with no
     TTY it completes, and s6-overlay stops the container when its main program ends.
     Under `restart: unless-stopped` that is a restart loop reporting success.
     `command: ["gateway", "run"]` fixes it. `main-hermes` is a no-op `sleep infinity`
     by design — the gateway is *not* an s6 service unless you ask for it.
  2. **`hermes cron status` exits 0 even when the gateway is dead.** It prints
     `✗ Gateway is not running — cron jobs will NOT fire` and returns 0. **The exit
     code is unusable**; the healthcheck parses output. Assume this class is not
     unique to this one command — check the exit code of anything else you build on.
- **There is no HTTP endpoint to probe.** Nothing listens on `9119` (dashboard,
  opt-in via `HERMES_DASHBOARD`) or `8642` (API server, needs `API_SERVER_KEY` +
  `API_SERVER_HOST`). Upstream warns the dashboard *"stores API keys; exposing it on
  LAN without auth is unsafe … do NOT pass `--insecure --host 0.0.0.0`"*, so `03`
  ruled out a Traefik router. This corrects ticket `01`'s "Gateway API on `8642`".
- **`hermes cron status` reports `Ticker heartbeat: NNs ago`** — a real liveness
  signal, and the healthcheck bounds it at 180 s. **Caveat to confirm rather than
  inherit:** only the `NNs ago` format was observed. If longer ages render as
  `2m ago` the parse fails → false alarm. `03` accepted false alarms as the correct
  failure direction, but the format itself is unverified.
- **Two building blocks exist that you should not rebuild:**
  - `hermes backup --quick` — snapshots "config, state.db, .env, auth, cron". Ticket
    `01` established rollback needs the previous digest **and** the pre-upgrade state
    together; this is the state half. **Making the *restore* a tested path is yours** —
    `03`'s whole argument against a restore-only rebuild story is that an unrestored
    blob is not a backup.
  - `hermes doctor` — built-in diagnostics (`hermes_cli/doctor.py`), including
    per-provider connectivity checks with a `supports_health_check` notion.
- **`SOUL.md` is now placed declaratively** by ansible, not hand-copied as on titan.
  Ticket `02` said `05` must *verify it loads* rather than assume — that check is now
  meaningful rather than aspirational.
- **The write record lives in `$HERMES_HOME/logs`**, which is restic-covered. `03`
  moved traceability there deliberately, because the git-audit-trail idea died (see
  its Answer) and Syncthing versioning — the replacement undo — is author-agnostic.
- **A failure mode to separate from a dead gateway:** messaging platforms
  **deny unknown senders by default**, so a wrong Telegram allowlist presents as
  "Hermes ignores me" — indistinguishable from a dead gateway unless this ticket's
  verification story tells them apart. See [ticket 10](10-telegram-authorization.md).

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
