# Decide the urgent-interrupt vs evening-digest policy

Type: grilling
Status: resolved
Blocked by: 01

## Question

**What earns an interrupt, what waits for the evening brief, and how do you correct
it when it judges wrong?**

The owner's framing: *"either notify me if something urgent is coming up, or just
give me a brief at the end of the day if there's anything I need to do or know
about."* Two channels of the same push mode, and the whole value rests on the agent
routing correctly — an agent that interrupts too often gets muted, and a muted
assistant is a dead one. That is a plausible fifth death.

### What the answer must settle

1. **The urgency test.** Not a vibe — something inspectable and correctable. Time
   pressure is the obvious axis and the vault gives real examples: a `📅`-dated task
   falling due, a payment deadline (the card invoice due the 28th), a lab window
   opening, a bill that will silently escalate to collections. Contrast with things
   that are important but *not* urgent (a wedding in September).
2. **Rate limits and quiet hours.** A hard ceiling on interrupts per day, and hours
   when nothing interrupts. Both are cheap insurance against the mute reflex.
3. **The evening brief's contract.** When it fires (the old morning job was
   `0 6 * * *` Stockholm; this is an *evening* brief so pick a time), and what it
   always contains. Coordinate with ticket `05`: it should arrive even on empty days
   so silence is the alarm. Prior art worth reusing: the v0.14 rewrite's BLUF line,
   empty-section suppression, and Telegram `*bold*` formatting — all verified
   working, all recoverable per ticket `02`.
4. **The correction loop.** When it interrupts about something trivial, how do you
   teach it? v0.19 has `/learn` (skill authoring) and persistent memory, so this may
   be a built-in rather than a prompt edit — but *whether corrections actually
   stick* is the question, and it directly determines whether the thing improves or
   plateaus. This is the difference between an assistant and a notifier.
5. **Timezone correctness.** Non-obvious and previously bitten: v0.14's cron
   evaluated `0 4 * * *` **in UTC** because config `timezone: ''`, so the "morning"
   briefing drifted with DST (06:00 CEST summer, 05:00 CET winter). Fix was
   `timezone: Europe/Stockholm` **plus** correcting the expression. Whatever
   scheduling v0.19 uses (Automation Blueprints replace raw cron), confirm the
   timezone story explicitly rather than assuming it was fixed upstream.
6. **Who else is affected.** Calendar colour IDs encoded a shared world
   (11=Mattias, 5=Hanna, 2=Both). Calendar is out of scope for this map, but if an
   interrupt could concern Hanna, note it rather than discovering it later.

### Inherited from ticket `03` (verified on the box 2026-07-31 — don't re-derive)

- **`--deliver telegram` is the sanctioned delivery mechanism**, and it fixes ticket
  `02`'s worst carried-forward defect. `02` found all three recovered prompts said
  *"send the briefing to Telegram"* as a **prompt instruction**, which is
  unexecutable because cron jobs run with messaging tools disabled — inviting a
  silent non-delivery. `hermes cron create --deliver <origin|local|telegram|discord|signal|platform:chat_id>`
  is the supported path and does not depend on the agent choosing to call a tool.
- **`--no-agent` makes a script's stdout the message, verbatim** — "the script IS the
  job", and **empty stdout is silent**. That is the classic watchdog shape and it is
  directly relevant to the urgent-vs-digest split: an urgent check that emits nothing
  when all is well costs no attention, whereas a digest is an agent job. It also means
  a *broken* watchdog and a *quiet* one look identical — coordinate with `05`.
- **`--workdir <dir>` injects `AGENTS.md` / `CLAUDE.md` from that directory** into the
  job. A job with `--workdir /vault` therefore picks up the vault charter
  (`~/vault/AGENTS.md`) for free, which the map's Notes describe as *"almost exactly
  this ask"*. Relevant to how much routing policy has to be restated in each prompt.
- **`--model` / `--provider` can be pinned per job**, and the help notes this is
  user-owned — *"the agent's cronjob tool cannot set this"*. So an urgent-triage job
  and an evening-digest job can run on different models, and the agent cannot
  silently change that itself.
- **Cron jobs are seeded declaratively** by ansible via `docker exec … hermes cron
  create`, guarded by `hermes cron list` — never by patching the gateway-owned
  `jobs.json`. So whatever policy this ticket lands must be expressible as job
  definitions in git.
- **`TZ=Europe/Stockholm` is set on the container**, so "end of day" means local time.
  Ticket `01` flagged that a wrong `TZ` fires briefings at the wrong hour silently.
- **A 💊 medication section is still sourceless.** `02` found the file the old script
  read no longer exists in `~/vault`; `03` did not change that. It remains a
  prerequisite for this ticket, not an adaptation.

### Inherited from ticket `02` (verified 2026-07-31 — don't re-derive)

The prior art point 3 leans on has been read and judged
([verdict table](02-recover-briefings-branch-inventory.md#answer)). It is mostly
good, but it implements the **wrong side of a tension this ticket must resolve**:

- **Empty-section suppression and always-report are in direct conflict.** The
  recovered prompt's rule is *"`STATUS=OK count=0`: the source is healthy and empty —
  OMIT that section"*. That is the same mechanism that makes `emit_labs` disappear
  silently once its hardcoded schedule expires (see `05`). Point 3 wants the brief to
  arrive **even on empty days so silence is the alarm** — so decide explicitly which
  wins per section, and note that suppressing a section is only safe when the source
  can distinguish *nothing due* from *config exhausted*.
- **Confirmed reusable, verbatim:** the BLUF first line (`"Top priority: …"` — for an
  evening brief, reword), Telegram `*bold*` labels with one leading emoji from a
  fixed set, one item per line, ~150–250 words to fit one phone screen, and *"use the
  date/weekday from the META line — do not compute dates yourself."*
- **A section you may want has no data source.** The 💊/🩸 content came from
  `~/hermes-vault/Areas/Health/Medication.md`, which is gone; `~/vault/health/` has
  no replacement, and standing medical facts now sit as prose in
  `projects/strength-and-weight/map.md`'s Notes. Keeping either section therefore
  requires **creating a structured source first** — a prerequisite decision for this
  ticket, not an adaptation. `~/vault/health/README.md` also routes anything dated to
  `tasks.md`, which may be the better source given board ownership is out of scope.
- **Point 5 rests on a stale premise:** *"Automation Blueprints replace raw cron"* is
  wrong per `01` — v0.19 still has the gateway cron ticker, cron expressions and
  `~/.hermes/cron/jobs.json`. The timezone hazard is unchanged and real: set `TZ` in
  the container **and** `timezone: Europe/Stockholm` in config.
- **Delivery is not prompt text.** All three recovered prompts end with *"Then send
  the finished briefing to Mattias on Telegram"* — unexecutable in a cron job
  (`messaging` toolset disabled). Drop it; configure the delivery target on the job.

### Note

This ticket is about **policy**, not plumbing. The channel is settled (Telegram);
how failure alerts reach you when the agent is dead belongs to ticket `05`.

### Inherited from ticket `05` (resolved 2026-08-01 — don't re-derive)

- **The brief is unconditional.** `05`'s **D1**: it arrives **every day**, in
  **adaptive-length** shape — a quiet day is one line plus a compact status footer
  (`✓ mail 12 · vault ok · HA ok`); anything in `ERROR` expands into a full `⚠`
  section. Chosen over an always-full footer because alarm fatigue is itself a
  silent failure. **This constrains `06`: there is no "no brief today" branch to
  design.** What varies is length, not existence.
- **No job prompt may ever instruct `[SILENT]`** — and the hazard is narrower than
  `01` recorded but nastier. Verified in `gateway/response_filters.py`: a marker
  mid-sentence *is* delivered, but a marker on the response's **first or last
  line** suppresses **the entire brief**. So a brief that happens to end with such
  a line vanishes, indistinguishably from a calm day. `06` must ensure its rendered
  output cannot begin or end with a silence marker.
- **Every source carries a provenance timestamp** (`05` **D2**) — the upstream's
  *own* last-updated time, not the script's clock. `06` composes sections **from**
  that contract; a source whose provenance is stale renders `⚠ stale`, never as a
  value and never as an empty section.
- **🔴 `06` gates a prerequisite it does not itself own: Home Assistant access is
  unprovisioned.** If the brief carries household data (weather — the original
  fake-weather source), **nothing in `03` gave Hermes an HA token or a network path
  to it**, and no ticket had decided which entities it may read. That question is
  sharp enough to ticket, so it is now
  [ticket 12](12-home-assistant-access.md), **blocked by `06`**. **What `06` decides
  is whether the brief carries HA data at all** — rule it in and `12` becomes a hard
  prerequisite for building the brief; rule it out and `12` closes as out of scope.
- **The failure-alert path is settled and is not `06`'s** — `05` **D3** puts it on
  the existing MQTT→HA plumbing, keyed on docker2mqtt's **`state`** entity. `06`
  covers *content* urgency only.
- **The rebuild drill reports through you** — `05` **D5**: a failed drill surfaces
  as a `⚠` line in the brief rather than its own alert.

## Answer

**Two channels, deliberately different in kind. The interrupt is a deterministic
script that cannot fabricate and is silent when all is well; the evening brief is
the agent job, arrives unconditionally at 20:00, and is the only place judgment is
exercised.** Rationale per decision in **D1–D8**.

### Verified in the pinned image on helium (2026-08-05/06) — don't re-derive

All from `nousresearch/hermes-agent@sha256:b869e64d…`, i.e. the digest `01` pinned.

- **`skip_memory=True` for every cron job.** `cron/scheduler.py`, the `AIAgent`
  construction: `skip_memory=True,  # Cron system prompts would corrupt user
  representations`. **This ticket's own point-4 premise was false**: `~/.hermes/memories/`
  is *never* injected into a cron job, so a correction told to Hermes in Telegram —
  which it happily stores and acknowledges — **cannot** reach the evening brief. It
  looks accepted and silently does not apply. That is this map's enemy class reached
  through the correction loop, which is why **D7** exists.
- **What *does* reach a cron job:** `load_soul_identity=True` (so `SOUL.md` always —
  which is what makes `02`'s one straight keep load-bearing); `skip_context_files=not
  bool(_job_workdir)`, so `AGENTS.md`/`CLAUDE.md` are injected **only** when the job
  has a `--workdir`; and skills explicitly attached to the job.
- **Skills are attachable per job and stored in `jobs.json`** — `hermes cron create
  --skill <name>` (repeatable), `cron update --add-skills/--remove-skills/--clear-skills`.
  Resolved from `~/.hermes/skills/` plus `skills.external_dirs` in `config.yaml`;
  external entries are expanded, resolved absolute, and must exist. **A missing
  external dir is skipped at `logger.debug` level** — silently. Assert presence, never
  assume it.
- **A pre-run script's stdout is injected into the agent's prompt** under a
  `## Script Output` heading ("Use it as context for your analysis"). This is the
  mechanism **D7** rides.
- **🔴 A pre-run script with empty stdout skips the agent call entirely.**
  `_build_job_prompt`: `else: # Script produced no output — nothing to report, skip AI
  call` → `return None`. The brief is an agent job *with* a gathering script, so **the
  brief's own architecture contains a silent-skip path**. Correction to `05` D1 below.
- **🔴 A script *failure* is louder than a script *success with nothing*.** A non-zero
  script injects `## Script Error … The data-collection script failed. Report this to
  the user.` and the agent still runs. So `exit 1` is a *reported* failure while
  `exit 0` with no output is *silence*. **A gathering script must never prefer a clean
  empty exit to a loud failure.**
- **🔴 The engine instructs `[SILENT]` on every cron job and it cannot be disabled.**
  A `cron_hint` is unconditionally prepended *above* the operator's prompt: *"SILENT:
  If there is genuinely nothing new to report, respond with exactly `[SILENT]`…
  Never combine [SILENT] with content."* Correction to `05` D1 below.
- **`context_from`** lets one job consume another job's latest output (8 K char cap).
  Its miss paths are all `continue  # silent skip — no output yet`. Usable, but not
  without an own-provenance line; not used by this ticket's design.
- **Ticker every 60 s** (`gateway/run.py:24911`, `interval: int = 60`).
- **Grace = half the schedule period, clamped [120 s, 7200 s]** (`_compute_grace_seconds`).
  A daily job therefore catches up if it is at most **2 h** late; beyond that it
  fast-forwards and that day's run is skipped. **Missed runs collapse — the job fires
  ONCE on catch-up, never a burst** (`get_due_jobs`), so a container restart cannot
  produce an interrupt storm.

### Measured on the real board (`~/vault/tasks.md`, 2026-08-05)

78 lines, **19 dated items**, 3 recurring, and **zero `[x]` items** — the board is
pruned by *deletion*, so "done" leaves no trace to key on. **Six open dated items were
already past due**, the oldest `📅 2026-07-14` (three weeks). One `📅` occurrence is
line 4's *format documentation*, not a task.

**This kills the obvious rule.** *"Interrupt when a dated task is due or overdue"* is
level-triggered, so on this board it fires six times on day one and the 07-14 item
fires **every day forever** — Hermes cannot clear the board (owning `tasks.md` is out
of scope). The mute reflex would arrive in week one, i.e. the fifth death, delivered
by the very feature meant to prevent it. Hence **D2**.

### D1 — Interrupts are deterministic. Mail cannot interrupt (day one).

- **The interrupt channel is a `--no-agent` job**: the script's stdout *is* the
  Telegram message, empty stdout sends nothing. Deterministic date math over dated
  vault items. It cannot fabricate, a wrong rule is a one-line diff in git, and it
  costs **zero inference**.
- **The evening brief is the agent job.** Prose, ranking and mail semantics live
  there and nowhere else.
- **Mail is not interrupt-eligible.** `07` (the triage contract) is unresolved, so a
  mail interrupt rule would rest on undecided semantics; mail is the least trustworthy
  input in the system (the Proton bridge's signature failure is *looking fine*); and a
  false interrupt from a misread invoice is precisely the mute trigger. **Accepted
  cost:** a bill arriving 09:00 and due tomorrow waits for the 20:00 brief — ~11 h
  less warning than a mail-aware interrupt, but the same day. Escalating mail to
  interrupt-capable is a named follow-on (Out of scope on the map), not a day-one
  feature.
- **Interrupt message format:** one line — `*bold* title · 📅 date · why now`. No BLUF,
  no footer; it is a single item by construction. `02`'s verified Telegram `*bold*`
  and one-leading-emoji conventions apply.

### D2 — Edge-triggered, T-2, cold start seeded **and announced**

1. **Edge-triggered, never level-triggered.** An item fires **once**, when it
   *crosses* into the window — not because it *is* in it. State file
   `$HERMES_HOME/state/urgent-seen.json` (state volume ⇒ restic per `03`'s
   authorship split).
2. **Item key = `sha1(📅date + normalized(first bold title segment))`**, normalized
   = lowercased, markdown and punctuation stripped. The board's lines accrete prose
   heavily, so a content hash would re-fire constantly; this key costs **one**
   duplicate interrupt on a retitle and **never** a miss — the correct failure
   direction.
3. **Window T-2:** an open dated item with `date - today <= 2` fires once. Enough
   room to make a payment or a phone call; outside the already-too-late zone.
4. **Once is once.** An item that fired at T-2 and is still open does **not** fire
   again — it reappears in the **evening brief on its due date** (`🔥 Due` T-0 line).
   There is a second touch; it just is not an interrupt.
5. **Cold start is seeded, and the seeding is announced.** On first run every
   currently-dated item at or inside the window is written to the state file as
   *already announced* — zero interrupts on boot — and **the first brief says so
   explicitly** (`seeded 6 items, 0 interrupts sent`). This is deliberately the same
   move `01` flagged as a hazard in the Email gateway adapter (marks the whole inbox
   seen on first start); the difference is that ours is **announced**, so it cannot be
   the silent thing.
6. **Parse loudly.** Only `- [ ]` lines are candidates (line 4's format doc would
   otherwise parse). An **unparseable date on a real task line is `ERROR`, never a
   silent skip** — `05`'s rule.
7. **The overdue backlog is brief material, not interrupt material** — rendered as a
   level statement (`⏰ 3 overdue, oldest 2026-07-14`), where it nags without buzzing.

### D3 — `*/30 7-22`, quiet hours 22:00–07:00, ceiling 3/day

- **Cadence `*/30 7-22 * * *` Stockholm.** Crossings into T-2 happen at **midnight**,
  so the only intraday change is a freshly added near-dated item arriving over
  Syncthing; `*/30` bounds that latency at 30 min, costs one script exec and no
  inference, and keeps the ticker demonstrably alive for `05`'s liveness probe.
- **Quiet hours are expressed in the cron hours field, not as a rule inside the
  script.** Nothing to misjudge. Items crossing at midnight fire at 07:00 — delayed,
  never lost.
- **Ceiling 3 interrupts/day**, counted in the same state file keyed on date. On the
  3rd the message ends `+N more — see tonight's brief`, and **the suppressed items are
  handed to the brief**. A capped interrupt must never vanish.
- **Sizing, honestly:** with edge-triggering on a 19-item board, expected volume is
  **0–2 per week**, not per day. The ceiling is insurance against a bad rule or a bulk
  board edit, not a working constraint.

### D4 — The evening brief: `0 20 * * *`, adaptive length, always-present footer

Fires **20:00 Stockholm** — chosen over 21:00 so there is still room to act the same
evening, and late enough to have seen the day's mail.

| | Section | Source | May collapse? |
|---|---|---|---|
| 1 | BLUF — `Tomorrow's priority: …` | agent, over the sections below | no |
| 2 | 🔥 **Due** — T-0/T-1 dated items | `tasks.md` | yes |
| 3 | ⏰ **Overdue** — count + oldest date | `tasks.md` | yes |
| 4 | 📬 **Mail** — filed / needs you | Proton bridge — contract is `07`'s | yes — **but see the ratio rule** |
| 5 | 💊 **Kineret** — injection nights only | `health/kineret-schedule.md` (**D6**) | yes |
| 6 | ⚠ **Errors** — any source in `ERROR`, expanded | all sources | yes |
| 7 | 📝 **Writes** — what it actually changed | `05` D4 write list | yes |
| 8 | **Footer** — `✓ mail 12/0 · backlog 0 · vault ok · urgent 32/32 · corrections 4` | script | **never** |

- **🔴 The ratio rule — reconciling with `07` D3, which resolved concurrently with
  this ticket.** `07` requires *"the count of messages examined vs flagged"* in the
  brief so *"a suddenly-zero-flag day reads as a ratio rather than an absence"* — its
  only defence of exception-only triage's **negative space**. Section 4 collapsing on a
  zero-flag day would destroy exactly that: a drifted classifier flagging nothing would
  render as a quiet inbox. **Resolution: the ratio lives in the footer, which never
  collapses** — `mail 12/0` is examined/flagged, and `backlog N` carries `07`'s
  skipped-backlog count (also named as brief content there, and it had no section of its
  own here). Section 4 may therefore still collapse, but **only because the negative
  space is structural in the footer rather than dependent on the section rendering.** If
  the footer ever loses the ratio, section 4 stops being collapsible.
- **The general suppression rule:** *a section may collapse iff its source can
  distinguish **empty** from **exhausted**.* That is `05`'s provenance contract
  restated, and it resolves the tension `02` flagged between empty-section suppression
  and always-report. A quiet day renders as BLUF + footer — `05` D1's adaptive length.
- **The footer is load-bearing, not cosmetic.** It is what makes the gathering script
  **incapable** of empty stdout, which is the only thing standing between `05` D1 and
  the verified `return None` silent-skip path. It is also what structurally guarantees
  the rendered output cannot begin or end with a silence marker.
- **Reused verbatim from `02`'s verdict table:** BLUF first line (reworded for
  evening), Telegram `*bold*` labels with one leading emoji from a fixed set, one item
  per line, ~150–250 words to fit one phone screen, and *"use the date/weekday from the
  META line — do not compute dates yourself."*
- **Delivery is job config, never prompt text** — `--deliver telegram` per `03`, which
  retires `02`'s worst carried-forward defect.
- **Accepted consequence:** with the 2 h grace, a container down at 20:00 that
  recovers at 21:50 delivers the brief at 21:50 — occasionally inside quiet hours. A
  "never deliver after 22:00" rule would trade a rare buzz for a silently dropped
  brief, which is the wrong direction for this map. Take the buzz.

### D5 — Home Assistant is **out** as a read source

**The brief carries no household data.** The argument is not risk, it is that
**nothing in the design needs it**: weather in a 20:00 brief is near-zero value,
interrupts are date-math-only (**D1**), and everything else household-shaped is either
out of scope (calendar) or real-time in a way a once-daily brief cannot serve. Against
that, ruling it in costs a long-lived HA token inside Hermes' blast radius, a decided
network path, an entity allowlist and a whole ticket — for the least valuable row in
**D4**'s table. It also makes the founding bug **unwritable** rather than merely
detectable: there is no weather section to fabricate.

- **This does not touch `05` D3.** That path is MQTT *into* HA — outbound from
  Hermes' side, already-built plumbing, unaffected by denying HA as a read source.
- **Consequence:** [ticket 12](12-home-assistant-access.md) **closes as out of
  scope**, not resolved — the owner's words: *"HA out. we might revisit in the
  future."* Reopening costs the token + path + allowlist, no more.

### D6 — 💊 is no longer sourceless, and gets a machine-readable source

**Correction to `02`:** `~/vault/health/kineret-schedule.md` was created
**2026-08-02**, two days *after* `02`'s inventory declared a 💊 section sourceless.
It is an operating doc — anchor **Wednesday 2026-07-29**, phase 1 every-other-night
for three months, then phase 2 every third day — and `health/README.md` deliberately
keeps it off the board (its *"anything with a date → tasks"* rule addresses the
vårdcentral to-dos, not a recurring injection schedule that would swamp `tasks.md`).

The trap: **the parity rule is a constant that looks like a query.** Hardcode
`August = even` and it is correct until phase 1 ends ~**2026-10-29**, then silently
wrong. That is `02`'s `emit_labs` bug and the fake weather in a third costume.

**Ruling: add a small machine-readable block to `kineret-schedule.md`** — `anchor:
2026-07-29`, `interval_days: 2`, `phase_1_ends: 2026-10-29` — and compute the section
deterministically from it. Provenance is **the file's own mtime plus the anchor it
parsed**. Once today passes `phase_1_ends` without the file having been updated it
emits **`ERROR`**, never silence.

Rejected: (a) no section — it is genuinely easy to lose track of an every-other-night
dose; (b) letting the agent read the prose — an LLM doing date arithmetic across phase
boundaries with nothing to check it against is exactly what `05` exists to prevent.

**Renders on injection nights only** — and note the interlock: that is a *suppressed*
section, which **D4**'s rule permits only because the machine-readable block makes
*exhausted* distinguishable from *nothing tonight*. (b) plus injection-nights-only
would have been the unsafe combination.

Prerequisite: **one human edit on krypton** (the authoritative side). ~~No new ticket —
it rides the brief's implementation issue.~~ **Struck 2026-08-06: that named no artifact
and no implementation issue existed, so the edit was ownerless.** It got
[ticket 13](13-kineret-machine-readable-block.md), now **resolved** — the block is live in
`~/vault/health/kineret-schedule.md` (`8c77436`), values owner-confirmed, and verified to
reproduce **47 of 47** rows of the file's own phase-1 table. Two riders land on whoever
builds the emitter: `yaml.safe_load` yields `datetime.date` (not `str`), and **phase 2's
interval is deliberately absent** so this **D6**'s `ERROR` genuinely fires at the boundary.

### D7 — The correction loop: two tiers, and a falsifiable "did it stick?"

Forced by `skip_memory=True`: memory is not a correction channel for the push mode,
so corrections must live in something the job provably reads.

- **Tier 1 — standing policy → git.** The urgency rules, the section list, the brief's
  format: a skill in a git-tracked directory, bind-mounted read-only, registered via
  `skills.external_dirs`, attached with `--skill`. Changing policy is a commit and a
  deploy, which is the right friction. **Assert the dir and skill are present** — a
  missing external dir is skipped at debug level.
- **Tier 2 — corrections → `$HERMES_HOME/state/corrections.md`.** *"Stop nagging me
  about the Loopia invoice"* is an exception, not a policy change. Hermes appends;
  **the gathering script cats the file into `## Script Output`**, so it is in the
  brief's context with no memory involved. On the **state volume, not the vault** —
  correcting it in conversation is the natural gesture and `08`'s vault write surface
  stays untouched (accepted cost: no phone editing by hand). Restic covers it.
- **Whether corrections stick is *testable*, not promised.** The footer carries
  `corrections N` (count + file mtime). Correct something; if the count does not move,
  **the correction did not land**. Every append also shows in `05` D4's write list.
- **Bounded:** over a size cap the script emits `ERROR` rather than truncating
  quietly. Graduating an accreted correction into Tier 1 policy is a human act.

### D8 — Single recipient: the owner only

Several urgent-eligible items are jointly owned (the wedding, shared finance), so
this is not hypothetical. **Nothing is ever delivered to Hanna.** A second recipient
would receive content derived from a vault that also holds `health/`, `journal/` and
`people/`; every interrupt and every brief would then need a per-recipient filter,
and there is no version of that filter which fails safely on day one. `10`'s
deny-by-default allowlist already points here. Anything concerning her is the owner's
to relay — exactly as today, so nothing regresses.

### Timezone (item 5 — settled, not grilled)

`02` already killed the *"Automation Blueprints replace raw cron"* premise. Set
**`TZ=Europe/Stockholm` on the container** (`03` already does) **and**
`timezone: Europe/Stockholm` in `config.yaml`, and write both expressions for local
time. No further decision.

### Corrections this ticket makes to already-closed work

- **`05` D1's `[SILENT]` rule is unachievable as written.** *"No job prompt may ever
  instruct `[SILENT]`"* cannot hold: the engine prepends that instruction to **every**
  cron job, above the operator's prompt, with no way to disable it. The requirement
  is rewritten: **the brief's prompt must explicitly countermand the engine's hint** —
  always produce the brief, never respond `[SILENT]`, the footer is always content.
- **`05` D1's "the brief always arrives" needs a mechanism, and now has one.** The
  verified `return None` on empty script stdout is a silent-skip path *inside* the
  brief's own architecture. The always-present footer (**D4**) is what makes empty
  stdout impossible; `05`'s ~26 h brief-staleness alarm remains the backstop.
- **`02`'s "a 💊 section is a prerequisite, not an adaptation" is stale** — the source
  exists as of 2026-08-02 (**D6**).
- **`05`'s brief-staleness alarm and the 2 h grace are a matched pair** — grace covers
  a ≤2 h outage, the alarm covers everything longer. Do not "fix" one without the
  other.

### Carried forward

- **→ `07` (resolved concurrently — reconciled, not deferred):** its topical-not-severity
  labels and this ticket's routing ownership fit without collision, and its **D3 ratio
  requirement is honoured in the footer** rather than the section — see the ratio rule in
  **D4**. Mail is **not** interrupt-eligible (**D1**) — its only channel is
  **D4**'s section 4, whose contract `07` owns. Tier 2 corrections (**D7**) are the
  natural home for mail-triage exceptions too, so `07` should assume that file exists.
- **→ `08`:** **`06` adds nothing to the vault write surface.** The corrections file
  is on the state volume by decision (**D7**), and the only vault-side change is one
  *human* edit on krypton (**D6**). `08` is free to keep the write surface as narrow
  as it likes.
- **→ `09`:** this ticket sizes the inference bill — **one agent call per day** (the
  brief) plus **zero** for the interrupt channel (`--no-agent`). Per-job `--model`
  pinning is user-owned, so the brief can run on a stronger model than anything
  conversational without the agent being able to change it.
- **→ implementation:** the two job definitions, the two scripts, the `urgent-seen.json`
  schema, the Tier 1 skill dir and its `skills.external_dirs` wiring, the countermand
  in the brief's prompt, and the one `kineret-schedule.md` edit.

### Done-when (falsifiable)

1. The gathering script **cannot** emit empty stdout — the footer is unconditional;
   verified by running it on a day with nothing in every section.
2. The brief's prompt countermands the engine's `[SILENT]` hint, and a rendered brief
   never begins or ends with a silence marker.
3. Cold start on the real board sends **zero** interrupts and the first brief reports
   the seeded count.
4. An item retitled between runs fires at most one duplicate interrupt; no dated item
   inside T-2 is ever missed.
5. A `📅` line with an unparseable date renders `⚠`, not a skipped item.
6. Past `phase_1_ends`, the 💊 section renders `⚠`, not absence.
7. `corrections N` in the footer increments after a correction, and the corrected
   behaviour is visible in the next brief.
7b. **A zero-flag mail day still shows the examined/flagged ratio** (`mail 12/0`) and
   the skipped-backlog count — verified by rendering a brief with section 4 collapsed.
8. `hermes cron list` shows both jobs with `--deliver telegram`, the brief with its
   `--skill` attached, and the skill resolvable inside the container.

**Status: resolved.**
