# Design the loud-failure / verification story

Type: grilling
Status: claimed
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
  git **plus the age key** must yield a working but amnesiac Hermes.* `03` split
  rebuild state by authorship (human-authored → git/ansible; agent-accumulated →
  restic), and that test is what makes the split falsifiable. If it fails, something
  is hand-installed and the v0.14 trap has been rebuilt. **Designing how that test is
  actually run — and how often — is this ticket's.**
  - **Mind the precondition; it is not pedantry.** `.env` sits on *both* sides of the
    split — ansible templates it from sops, *and* restic holds it because it lives in
    `/data/ssd/appdata/hermes`. Since the secrets are sops-encrypted in git, a
    rebuild from git *without* the age key yields a Hermes that **boots and cannot
    talk to anything**: gateway up, healthcheck arguably green, no provider, no
    Telegram. That is a plausible-looking half-success, which is precisely the class
    this ticket exists to catch — so the verification story should be able to
    distinguish "amnesiac" from "mute", not just "up" from "down".
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
5. **An audit trail you can read without asking the agent.** ~~`~/vault` is a git
   repo, so every vault write Hermes makes is a commit-able, diffable, revertable
   record.~~ **Struck 2026-08-01 — stale, and it contradicted this same ticket's
   §03 block.** `.stignore` excludes `.git`, so helium's replica **has no repo at
   all**; `.gitignore` untracks finance data; and versioning was off on every krypton
   folder (`03`, `11`). There is nothing on helium to `git log`. So the real question:
   **what constitutes the readable write record, given the trail is now
   `$HERMES_HOME/logs` (restic-covered, `03`) plus author-agnostic Syncthing
   versioning on krypton (`11`)?** Specifically — can you answer *"what did Hermes
   change in the vault yesterday?"* without shelling into the container or asking the
   agent; does the answer distinguish Hermes' writes from the owner's own (Syncthing
   versioning cannot); and is `/journey` part of the trail given it is **CLI-only**?
6. **A periodic proof-of-correctness, not just proof-of-life.** The fake-weather bug
   would have survived every liveness check ever written. What check would have
   caught it?

### Deliberately deferred to the resolution, not pre-decided

Whether this needs its own monitoring plumbing or can ride entirely on what helium
already has (MQTT→HA, Homepage, restic/timer alerting). Prefer riding existing
plumbing — new monitoring is one more thing that can fail silently.

---

## Verified on helium 2026-08-01 (this ticket's own AFK pass — don't re-derive)

Method: the pinned image
(`nousresearch/hermes-agent@sha256:b869e64d…`) is present on helium; findings are
from reading its source (`docker run --entrypoint sh`) and running its CLI, not
from docs. Items 05 flagged as *"confirm rather than inherit"* are settled below.

**✅ The `Ticker heartbeat: NNs ago` format is stable — `03`'s parse worry is
unfounded.** `hermes_cli/cron.py:306` is
`print(f"  Ticker heartbeat: {int(hb_age)}s ago")` — unconditional integer
seconds. There is no `2m ago` rendering at any age. `03`'s sed parse is safe.

**🔴 But `03`'s probe has a real hole, and it is this map's enemy class exactly.**
`hermes cron status` tracks **two** markers, not one — `ticker_heartbeat` and
`ticker_last_success` — and upstream's own comment says why:

> *"a ticker stuck failing every tick would otherwise keep the plain heartbeat
> fresh and falsely report healthy (#32612, #32895)"*

`cron status` has four branches. The `Ticker heartbeat:` line is printed **only in
the healthy branch**, so `03`'s probe accidentally gets the right verdict on the
two degraded ones (their text doesn't yield a parsable age). **The hole is the
fourth case: `ok_age is None`** — `ticker_last_success` never written, i.e. *no
tick has ever succeeded*. The `elif` requires `ok_age is not None`, so that state
falls through to the healthy `else`: prints `✓ Gateway is running` **plus a fresh
heartbeat**. `03`'s probe reports **HEALTHY while cron has never once fired.**
Upstream's field example is a root-owned `jobs.json` (#68483) that failed every
tick for ~14 h. **The probe must read `$HERMES_HOME/cron/ticker_last_success`
directly and treat *missing* as unhealthy** (past the start-period), not lean on
`cron status` prose — absence-means-healthy is the exact bug this map exists to kill.

**🔴 `hermes doctor` exits 0 with unaddressed `✗` failures.** Ran it on a fresh
`HERMES_HOME`: it printed `✗ ~/./.env file missing` and *"Found 5 issue(s) to
address"*, and **exited 0**. `03` warned this class may not be unique to
`cron status`; it isn't. Anything built on `doctor` must parse output. (The
earlier `141` seen here was SIGPIPE from `head`, not doctor.)

**🔴 `doctor`'s `SOUL.md` check cannot detect the failure `02` warned about.** On a
**fresh, empty** `HERMES_HOME` the image auto-creates a **513-byte default
`SOUL.md`**, and doctor reports `✓ ~/./SOUL.md exists (persona configured)`.
Existence is all it tests — so the stock default is **green**, and the titan
failure (`02`: *"the original there was the empty default"*) would pass. **Verifying
`SOUL.md` must assert on content** (grep the two anti-fabrication sentences), never
on doctor's tick.

**✅ The image does not clobber an existing `SOUL.md`.** Seeded a marker file,
booted, marker intact and byte count unchanged — so `03`'s ansible placement is
safe, and a content assertion is meaningful.

**✅ Restore exists, but it is not called restore.** `hermes backup [-q]` creates;
**`hermes import`** restores ("Restore a Hermes backup from a zip file"). There is
no `hermes restore` — a rebuild runbook that greps for one finds nothing.

**🟡 A content-free telemetry projection already exists — likely the cheapest real
answer to item 4.** `agent/monitoring/cron_health.py` exports
`hermes.cron.scheduler.heartbeat_age_seconds`, `…last_success_age_seconds`,
`…catch_up_occurrences`, `hermes.cron.jobs.enabled`, `…jobs.running`, and — the
strong one — **`hermes.cron.jobs.overdue`** (a job whose `next_run_at` passed
beyond its grace window). `hermes monitoring status` inspects it; transport is
**OTLP** to an operator-configured endpoint, in-process and *"fail-open"*,
*"content-free by construction — no prompts, messages, tool args/results"* (so it
clears the egress posture). **Two cautions:** OTLP is *not* helium's existing
MQTT→HA plumbing, so riding it means a collector; and each metric is appended
**only `if value is not None`**, so `last_success_age_seconds` is *absent* rather
than zero in the never-succeeded case — an alert rule keyed on the metric's value
silently never fires. **Alert on metric absence, or don't use it.**

**🟢 The `[SILENT]` risk is narrower than inherited — and nastier.** `01` recorded
the hazard as *"any response **containing** `[SILENT]`"*. Not so
(`gateway/response_filters.py`): a token buried mid-sentence **is** delivered.
Suppression fires when the marker is the whole response, **sits on its own first
or last line**, or opens the response as `[SILENT] …`. So the real trap is a
genuine briefing whose **last line** canonicalizes to a marker — the *entire*
brief is dropped, not the line. Also note `is_intentional_silence_agent_result`:
markers suppress **only successful turns**, which is consistent with `01`'s
"failed jobs always deliver".

---

## Decisions taken (running log — owner rulings, in order)

### D1 — The brief always arrives. Silence is never "nothing to report". *(owner, 2026-08-01)*

Settles **item 2 (the no-news problem)**. The evening brief is delivered **every
day, unconditionally**, in the **adaptive-length** shape: a quiet day renders one
line plus a compact status footer (`✓ mail 12 · vault ok · HA ok`); any source in
`ERROR` expands into a full `⚠` section. Chosen over an always-full footer because
alarm fatigue is itself a silent failure — a brief the owner stops reading cannot
alert him.

Three consequences, none of them optional:

1. **No job prompt may ever instruct `[SILENT]`.** The always-report rule and the
   cron framework's silence affordance are mutually exclusive; this map picks
   always-report. (`02` already found the inverse defect — three recovered prompts
   ordered a Telegram send that cron cannot perform.)
2. **The renderer must guard its own last line.** Verified above: a marker on the
   response's **first or last line** suppresses the *whole* brief. A brief that
   happens to end with a line canonicalizing to a marker vanishes entirely — and
   the suppression is indistinguishable from a calm day. Assert the rendered brief
   does not begin or end with a silence marker before handing it to delivery.
3. **A human noticing an *absent* message is not a control.** The owner cannot be
   the watchdog for a non-event, so D1 is necessary but not sufficient — the
   machine-side staleness alarm (item 4) is required alongside it, not instead of
   it. Owner agreed this rides regardless of the brief's shape.

### D2 — Provenance is structural; the variance tripwire backs it up. No cross-fetch. *(owner, 2026-08-01)*

Settles **item 6 (proof-of-correctness)**. First, the reframe that shaped it:

**There are two fabrication surfaces, not one, and this map has been conflating
them.** `SOUL.md` (per `02`, the only defence against fabricated content) guards
the **model** confabulating. The v0.14 fake weather was **hardcoded constants in
the gathering script** — the model never lied; it faithfully rendered numbers the
script fabricated. **`SOUL.md` would not have caught it.** Script-side fabrication
needs its own control, and that is what D2 is.

- **(A) Provenance timestamps — primary.** Every emitter reports the **upstream's
  own** last-updated time beside the value (HA `last_changed`; IMAP message dates;
  vault file mtimes). A value whose provenance exceeds its per-source bound renders
  `⚠ stale`, never as a number. This is chosen because it is **structural, not
  detective**: a hardcoded constant has no provenance to report, so an emitter
  physically cannot produce a fresh upstream timestamp without querying. It makes
  the fake-weather bug *unwritable* rather than merely observable. Extends `02`'s
  `<name>: STATUS=OK count=<n>` contract with a provenance field rather than
  replacing it.
- **(B) Variance tripwire — near-free backstop.** Flag any numeric field
  byte-identical across N consecutive days. Catches what A cannot: a **real but
  wedged** source whose timestamp keeps advancing while its value never moves (a
  stuck HA sensor passes A cleanly). Accepts occasional false positives on
  genuinely static values — the correct failure direction.
- **(C) Independent re-fetch — rejected.** A second script cross-checking each
  source duplicates every integration, and the duplicate rots exactly as the
  original did; the result is two things to trust instead of one. Explicitly
  offered for the mail path (the most-repeated real failure) and explicitly
  declined — the dead-bridge case is covered by A, since an unauthenticated IMAP
  session yields no message dates at all and therefore no provenance.

**Carry into `07`:** A gives the email-triage contract its freshness primitive for
free — "newest message date" *is* the inbox's provenance, so a bridge session that
dies live-but-unauthenticated surfaces as `⚠ stale`, not as an empty inbox.

### D3 — Alerts ride the existing MQTT→HA path, keyed on `state`, never on `health` *(agent decision on settled facts, 2026-08-01)*

Settles **item 4 (where alerts land when the agent itself is down)**. Not put to the
owner: 05 pre-committed to *"prefer riding existing plumbing"*, and the plumbing
question turned out to be already answered on the box.

**What actually exists** (verified on helium + `issues/046`): a real MQTT broker at
`192.168.1.99`, with `docker2mqtt` on helium publishing under topic prefix
`containers` as an **outbound-only client — no listening port**, ansible-applied,
through the read-only socket proxy. `046` is effectively landed (7 of 8 acceptance
criteria met). So the path `HEALTHCHECK` → docker2mqtt → MQTT → HA → phone exists
today and costs this map nothing.

**🔴 But `03`'s one-line version of that path is wrong, and wrong in this map's own
failure direction.** `03` says *"`HEALTHCHECK` → docker2mqtt health entity → MQTT →
HA"*. `046`'s own verified caveat contradicts it:

> *"the separate **health** entity does not clear when a container stops, so
> **state** is the liveness signal, not health."*

So if the Hermes container **stops**, the health entity **retains its last value** —
plausibly `healthy`. An automation keyed on the health entity therefore stays green
across the most basic failure there is. **Alert on the `state` entity for "is it
running", and use `health` only to distinguish degraded-while-running.** Both are
needed; neither alone is sufficient. (Cited from `046`, which records it as
measured; not independently re-verified here — a broker subscribe was blocked.)

**Three alarms, and every one of them fires on *absence*, not on a bad value** —
absence-means-healthy is the bug class this map exists to kill:

1. **Container state** — `state != running`, from docker2mqtt. Catches the crash
   loop `03` found (default CMD exits 0), because s6 stopping the container flips
   `state`.
2. **Container health** — the `HEALTHCHECK` from `03`, **with the hole fixed**: it
   must read `$HERMES_HOME/cron/ticker_last_success` directly and fail when that
   file is **missing** past the start-period, not merely when it is stale. As shown
   above, `hermes cron status` renders "never succeeded" inside its *healthy* branch.
3. **Brief-arrival staleness** — an HA entity stamped each time the evening brief is
   delivered; if it ages past ~26 h, alert. This is the control that makes **D1**
   real: it is the machine noticing the non-event, which the owner cannot be relied
   on to do. It is also the only one of the three that survives "gateway healthy,
   delivery target silently misconfigured" — a documented upstream failure where the
   job runs and the response is dropped.

**Rejected: the OTLP exporter**, despite `hermes.cron.jobs.overdue` being the single
best signal in the system. It needs a collector helium does not have, and standing
one up to watch the watchman is one more thing that fails silently. Revisit only if
a collector arrives for another reason. **Also rejected: a Homepage tile** — `05`'s
evidence already records that a Homepage container-status tile was the *only* tell
built for the Proton bridge and it *"does not catch a live-but-unauthenticated
bridge"*. A dashboard nobody is looking at is not an alarm.
