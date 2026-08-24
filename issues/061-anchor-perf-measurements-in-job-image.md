---
title: Run the eight anchoring measurements inside the job image on helium
status: open
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

Before lumin's CI workflow can be written, eight named measurements must run **on
helium, inside the job image**, to establish whether the perf gate's committed ceilings
survive moving to a different CPU. Depends on `issues/059` (the image is the thing
being measured).

The correction that makes this a ticket rather than a checklist item: if jobs run in a
container, then the libc, the valgrind build and the benchmark tooling the perf gate
actually sees belong to the **image**, not to helium. Half of these measurements
executed in a host shell would verify the wrong environment, **come back green, and
lock the CI design on a false pass**.

Two of the eight carry the decision:

- The cheap early proxy is a digest of valgrind's synthetic CPU diagnostics. Valgrind
  masks the real CPU to a hardcoded synthetic model and returns compile-time constants,
  which is why the CPU change should not move instruction counts through the
  libc-dispatch channel at all. An identical digest to the laptop's closes that channel
  outright, for the price of one command.
- The settler is the twelve benchmark instruction counts against the committed
  calibration table. Byte-identical is the pass condition.

Run the proxy first — it predicts the settler cheaply. A mismatch is not a failure of
this ticket; it is the finding, and it hands the anchoring-authority question to
lumin's own spec work with real numbers instead of a guess.

Record the results with their provenance: the image digest alongside the toolchain and
valgrind versions, so a later drift can be attributed rather than argued about.

## Acceptance criteria

- [ ] All eight measurements were executed inside the job image on helium (evidenced,
      not asserted) — no host-shell substitutions.
- [ ] The synthetic-CPU digest is recorded and compared against the laptop's.
- [ ] The twelve instruction counts are recorded and compared byte-for-byte against the
      committed calibration table, with any deltas stated per benchmark.
- [ ] The image digest, toolchain version and valgrind version are recorded alongside
      the results.
- [ ] The outcome states plainly whether the ceilings transfer as-is, and if not, what
      the gap is.
