# 023 — The brief skeleton: it always arrives at 20:00

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [022](022-interrupt-channel.md)

## What to build

The evening brief, with one source in it — and every structural property that makes silence
impossible and fabrication unwritable. **This is the map's primary seam**; get the contract right
here and `024`, `025` and `026` are additions to it rather than renegotiations of it.

- **20:00, always arrives, adaptive length.** No condition renders nothing, so **silence is
  itself the alarm** — which is the whole reason `026`'s missing-brief alarm can be simple.
- **BLUF first line, then sections, then a footer** that never collapses. One phone screen.
- **The gathering script runs before the agent and hands it pre-gathered facts**, each stamped
  with **its upstream's own last-updated time**. This is what makes the fake-weather class
  *unwritable* rather than merely detectable: a fabricated fact has no source to cite.
- **The footer is load-bearing, not cosmetic.** 🔴 It is what makes the script **incapable of
  empty output**, which closes a verified silent-skip path: **empty stdout makes the engine skip
  the agent call entirely**. 🔴 A second such path exists — **a trailing wake-gate marker in the
  output skips the whole run** — and this design emits structured blocks by construction, so no
  emitted block may be readable as that marker.
- ⚠️ **The engine prepends a silence instruction to every scheduled job**, so the prompt must
  **countermand** it. An earlier ticket's "no prompt may instruct silence" is unachievable as
  written.
- **A section may collapse if and only if its source can distinguish *empty* from *exhausted*.**
  Establish that rule here; `024`'s dose section is the first thing it licenses.
- **An unreachable source renders `ERROR` and is never omitted** — the per-source
  `STATUS=OK/ERROR` contract recovered in `018`.
- **A variance tripwire** for sources that are alive but wedged (unchanged when they shouldn't be).
- **Delivery is job configuration**, and the one agent job is the only place judgment happens.

The single source for this slice is the board's dated items — already computed by `022`, so this
ticket proves the frame rather than gathering new data.

## Acceptance criteria

- [ ] A brief arrives at 20:00 on a day with **nothing to report**, carrying BLUF and footer.
- [ ] The brief carries the board source's **own** last-updated time, not the run time.
- [ ] With the source unreachable, the brief renders `ERROR` for it — not an omission, not silence.
- [ ] **Negative test:** the gathering script's output can never be empty, asserted directly.
- [ ] **Negative test:** no emitted block can be parsed as a wake-gate marker.
- [ ] The rendered brief neither begins nor ends with a silence marker, and the prompt
      demonstrably countermands the engine's prepended instruction.
- [ ] A stale-but-alive source trips the variance tripwire.
- [ ] The collapse rule is implemented and documented: a source that cannot distinguish empty
      from exhausted does not collapse.
- [ ] The gathering script is tested off-box against fixtures — output asserted as text, with no
      model in the test.

## Blocked by

- [022 — The interrupt channel](022-interrupt-channel.md) — reuses its script-on-volume,
  scheduled-job and delivery path, and its date source.
