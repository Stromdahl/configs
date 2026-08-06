# 024 — The brief's remaining sources: dose, backlog, corrections

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [023](023-brief-skeleton.md)

## What to build

Three more sources in the brief's existing frame — and the correction loop that makes telling
Hermes something a thing that sticks.

**The dose section (💊).** Renders on injection nights only.

- **Computes from ticket `13`'s machine-readable block, never from the prose and never from a
  hardcoded parity rule.** The parity shortcut in that file is correct today and **goes silently
  wrong when the taper's first phase ends** — the same defect class as the fake weather.
- **Past the recorded phase-1 end without the file having been updated, it emits `ERROR`, never
  silence.** That exhaustion signal is the only reason `023`'s collapse rule permits an
  injection-nights-only section at all.
- ⚠️ **Two riders travel with that block** (recorded in the map's Notes): its dates deserialize as
  **date objects, not strings** — a string comparison passes by luck on ISO ordering while being
  wrong in kind — and the file's provenance timestamp **crosses Syncthing** to helium, which is
  expected to survive but is **unverified**; compare both sides after an edit before the brief
  cites it as freshness.
- **Provenance is the file's own modification time plus the anchor the script parsed.**

**The inbox backlog.** The count of undrained notes and **the age of the oldest** — so a queue
nobody is reading becomes visible rather than accumulating. Both writers (Hermes and the owner's
own capture) share that one queue, which is what makes its depth meaningful.

**The corrections loop.** 🔴 Scheduled runs have **memory writes disabled**, so a correction told
in Telegram **cannot reach the brief** — it looks accepted and silently isn't. So corrections are
a **file on the state volume that the gathering script includes verbatim**, and the footer carries
a `corrections N` count as the **falsifiable did-it-stick test**.

## Acceptance criteria

- [ ] On an injection night the dose section renders; on a non-injection night it collapses.
- [ ] With the clock past the recorded phase-1 end, the section renders `ERROR` — not a computed
      answer, not silence.
- [ ] The dose computation is fixture-tested across the phase boundary, with dates compared as
      dates.
- [ ] The dose section carries the source file's own modification time, and the Syncthing
      round-trip check on that timestamp has been run and recorded.
- [ ] The brief reports the undrained inbox count and the oldest note's age, both matching reality.
- [ ] A line written into the corrections file appears **verbatim** in the next brief.
- [ ] The footer's corrections count increments to match, and a correction told only over Telegram
      is demonstrably **not** picked up — so the limitation is proven, not assumed.

## Blocked by

- [023 — The brief skeleton](023-brief-skeleton.md) — these are sources added to its frame, and the
  corrections count rides its footer.
