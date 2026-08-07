# PRIOR ART — the morning-briefing job prompt

**NOT DEPLOYED.** Recovered by ticket `018` from `4ed7e63^` (v0.14, titan) and stripped.
This is the prompt half of `morning_briefing.sh` — the script's stdout is what it operates
on. Ticket `023` writes the real brief prompt; this is the shape it starts from.

Only one of the `.md`/`.txt` pair was recovered. Ticket `02` #5: the pair was itself a drift
source, so keep one, never both.

## Carried forward — the rendering half of the STATUS contract

The script emits per-source status lines; **this is where the rule that a failed source is
never rendered as an empty one actually lives.** Three things survive:

1. **The STATUS rendering rules** — the agent's side of the contract.
2. **The VERBATIM rule** — the agent may reformat a `<verbatim>` block's layout but never
   its content.
3. **The rule that the date comes from the `META` line, never from the model.**

Plus the BLUF-first ordering, and the one-phone-screen length target.

## Stripped, and why

- 🔴 **DEFECT ① — every instruction to deliver the brief.** The original opened with
  *"Deliver Mattias's morning briefing to Telegram"* and closed with *"Then send the finished
  briefing to Mattias on Telegram."* Ticket `01` measured scheduled jobs as running with the
  **messaging toolset disabled**, so both lines are unexecutable *and* invite the exact
  failure this map exists to catch: the agent reporting it sent the brief while nothing
  arrives. **Delivery is job configuration, never prompt text.** Do not reintroduce either
  line, in any wording, in any prompt in this deployment.
- **The 🗓 calendar, 🌦 weather and 📰 news rendering rules**, with them the `colorId`
  owner-tagging scheme — all three sources are out of scope in spec `015`.
- **The 🩸 labs and 💊 medication rules** — their v0.14 sources are gone. Ticket `13` has
  since landed a machine-readable dose block in the vault; `024` writes that section fresh
  against it rather than porting these rules.
- **The whole deployment checklist** — titan paths, the timezone fix, `~/hermes-vault/Areas/
  Health/Medication.md`, and the manual symlink/`cp` dance that step 1 needed *because the
  `hermes-agent` module was commented out on the live host*. That disabled-but-present
  declarative path is the failure ticket `03` designs out: helium has no opt-in list to
  comment out.

## The surviving prompt

⚠️ **Two known corrections before `023` reuses this**, both recorded rather than silently
applied — the text below is prior art, not a draft:

- **The `count=0` → OMIT rule is superseded.** Spec `015` and ticket `06`: a section may
  collapse **if and only if its source can distinguish *empty* from *exhausted***. Defect ②
  is this exact rule quietly eating a health source. Blanket omission is what `023` must not
  carry forward.
- **The engine prepends a silence instruction to every scheduled job**, so `023`'s prompt has
  to *countermand* it. Nothing in the text below does that yet.

```
Persona per SOUL.md: a concise, professional executive assistant — no greetings,
endearments, or exclamation marks.

You are given the output of the briefing data script. Each section begins with a
status line. Render the briefing using these rules:

STATUS (critical):
- "STATUS=OK" with data: render those items. Do not invent, merge, reorder, or
  drop items, and never add anything from your own knowledge.
- "STATUS=OK count=0": the source is healthy and empty.   [see correction above]
- "STATUS=ERROR …": render one line, "⚠️ <section>: unavailable", and NEVER
  present that source as empty, quiet, or clear.

VERBATIM: a <verbatim>…</verbatim> block is safety-critical text. You may change
how it is laid out — drop markdown checkboxes, group items under headings — but
never add, omit, rename, or change a value inside it.

FORMAT (Telegram — it does NOT render markdown headers): use *bold* section
labels, each with one leading emoji, used as a functional marker and never
decoratively. One item per line. Keep it to one phone screen (~150–250 words).
Use the date/weekday from the META line — do not compute dates yourself.

ORDER:
1. First line — "Top priority: …": the single most consequential or
   time-sensitive thing today, or "quiet day — nothing time-critical".
2. Then one section per source, in the order the script emitted them.
```
