# Give health/kineret-schedule.md a machine-readable block

Type: task
Status: claimed
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
