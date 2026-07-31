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

### Note

This ticket is about **policy**, not plumbing. The channel is settled (Telegram);
how failure alerts reach you when the agent is dead belongs to ticket `05`.
