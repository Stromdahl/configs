# Give health/kineret-schedule.md a machine-readable block

Type: task
Status: resolved
Blocked by: 06

## Question

Apply [ticket 06](06-urgent-vs-digest-policy.md)'s **D6** to the vault file the 💊
brief section will read. Nothing to decide — the decision was taken in `06`; this is
the mechanical follow-through, the same shape as
[ticket 04](04-respec-vault-serve-004-send-receive.md) and
[ticket 11](11-vault-undo-riders-to-vault-serve-004.md): a decision in this map that
changes a file **outside** it.

It exists as a ticket because `06` left it ownerless — "rides the brief's
implementation issue" names no artifact, and **no implementation issue exists yet**.
`06`'s Done-when #6 verifies the *behaviour*; nothing made anyone do the *edit*.

### The change

`~/vault/health/kineret-schedule.md` (created 2026-08-02) is prose plus a parity
table: **anchor Wednesday 2026-07-29**, phase 1 every-other-night for three months,
then phase 2 every third day. `06` **D6** ruled the 💊 section must compute from
machine-readable fields, not from the prose and not from a hardcoded parity rule —
because `August = even` is a constant that looks like a query and goes silently wrong
when phase 1 ends (~**2026-10-29**). That is `02`'s `emit_labs` bug and the fake
weather in a third costume.

Add a block the gathering script can parse — shape to settle when doing it, but it
must carry at least:

- `anchor: 2026-07-29`
- `interval_days: 2`
- `phase_1_ends: 2026-10-29` (the field that makes exhaustion detectable)

### Constraints

- **Edit on krypton**, the authoritative Syncthing side — not on helium's replica.
  Per `04`, that replica is **Send-Receive**, so a helium-side edit propagates to
  krypton *and* the phone.
- **HITL on the numbers.** The dates are the owner's medical schedule; the file's own
  header says the arithmetic came from what they described on 2026-08-02 and that
  dosing belongs to their prescriber. Confirm the three values rather than deriving
  them, and change **no** prose.
- **Do not move the file or restructure `health/`.** `health/README.md` routes to it
  by name, and `06` **D6** depends on that path.
- The block is **additive** — the prose and parity table stay, since the file's stated
  purpose is that a human mostly reads the table.

### Done when

1. The three fields exist in `~/vault/health/kineret-schedule.md` on krypton, values
   confirmed by the owner.
2. A trivial parse (the eventual emitter, or a one-liner standing in for it) reads all
   three and computes tonight's answer, agreeing with the file's own parity table for
   the current month.
3. The prose and the parity table are unchanged.

## Answer

Applied on **krypton** 2026-08-06 (`~/vault` `8c77436`, `health/kineret-schedule.md`
only, **+13 / −0** — additive by construction, so Done-when 3 is satisfied by the diff
rather than by inspection). Shape: **YAML frontmatter**, owner's choice over a fenced
block — it is how the rest of the vault stores data (`templates/recipe.md`), it is what
Obsidian Bases can read, and it needs no fence-extraction step in the emitter.

```yaml
anchor: 2026-07-29
interval_days: 2
phase_1_ends: 2026-10-29
phase_1_ends_source: assumed
```

**Owner confirmed all three values verbatim** rather than them being re-derived, per
the HITL constraint: anchor and interval *"both correct"*, and the switch date *"still
just the guess"*.

### ✅ The block and the table cannot disagree — measured, not assumed

Before asking the owner anything, the arithmetic was checked *against the file's own
phase-1 table* — because a block that silently disagreed with the table a human reads
would be this map's enemy class delivered by its own fix. It doesn't:

```python
# run in ~/vault; parses the doc's phase-1 table out of the markdown and diffs it
# against anchor + interval_days
python3 - <<'PY'
from datetime import date, timedelta
anchor, iv, end = date(2026,7,29), 2, date(2026,10,29)
doses, d = [], anchor
while d <= end: doses.append(d); d += timedelta(days=iv)
print(len(doses), doses[0], doses[-1])   # 47 2026-07-29 2026-10-29
PY
```

- **47 computed doses vs 47 table rows, set difference empty in both directions**, first
  and last dose identical. The doc's *"47 doses"* count is right too.
- The doc's parity shortcut (**July odd · Aug even · Sep odd · Oct odd**) holds for all
  four months against the computed set — so the shortcut was never wrong, it is only
  **unsafe to hardcode**, exactly as `06` **D6** argued.

### ✅ Done-when 2 — the trivial parse

```python
import yaml, datetime, pathlib
fm = yaml.safe_load(pathlib.Path("health/kineret-schedule.md").read_text().split("---")[1])
anchor, iv, end = fm["anchor"], fm["interval_days"], fm["phase_1_ends"]
today = datetime.date.today()
if today > end: print("ERROR: phase_1_ends passed, file not updated")
else: print("💊" if (today - anchor).days % iv == 0 else "no dose")
```

Run 2026-08-06: parsed all three fields, computed **💊 INJECTION**, and **agrees with
the parity table** (August = even, and *Thu 6* is a table row).

### Two riders for whoever builds the 💊 emitter

1. ⚠️ **`yaml.safe_load` returns `datetime.date` objects, not strings** — unquoted
   ISO dates are a YAML date type. So `fm["phase_1_ends"] > "2026-10-29"` is a
   `TypeError`, and a `str()`-comparison version would *work by luck* on ISO ordering
   while being wrong in kind. Compare dates to dates.
2. **`phase_1_ends_source: assumed` is a fourth field, added beyond `06` **D6**'s
   three.** Rationale: the date is a *guess* the file's own ⚠️ section flags, and the
   owner reconfirmed it is still a guess — but a bare `phase_1_ends: 2026-10-29` in
   frontmatter reads as fact, and Obsidian's property UI can drop YAML **comments** on
   rewrite while it cannot drop a **field**. So the caveat is carried as data. The
   emitter may ignore it; a human or a later session cannot misread the date. If the
   prescriber ever confirms a switch date, the value changes and this field goes.

### Two things deliberately not done

- **No phase-2 fields.** `interval_days: 3` and a phase-2 anchor are computable from
  the doc's table and were left out on purpose: with them present an emitter counts
  straight through the boundary, and the one human confirmation this whole design turns
  on (**is the switch date real?**) never gets forced. The absence *is* the interlock
  behind `06` **D6**'s `ERROR`-not-silence rule. The frontmatter comment says so, so a
  future session doesn't "complete" the block.
- **No prose touched, file not moved, `health/README.md` untouched** — its
  route-by-name and **D6**'s path both still hold.

### One check the emitter's implementation issue still owes

**D6** sets provenance as *the file's own mtime plus the anchor it parsed*. The anchor
half is now parseable. The mtime half crosses Syncthing to helium's replica — Syncthing
does propagate modification times, so this should survive the hop, but it is **one
round-trip confirmation** (`stat` on both sides after an edit) rather than something
this ticket verified. Cheap, and worth doing before the brief cites an mtime as
freshness.
