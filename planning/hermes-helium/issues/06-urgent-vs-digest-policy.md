# Decide the urgent-interrupt vs evening-digest policy

Type: grilling
Status: open
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
