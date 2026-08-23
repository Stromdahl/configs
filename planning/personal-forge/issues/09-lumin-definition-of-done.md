# lumin's definition of done, once the deep tier is remote

Type: grilling
Status: open
Blocked by: 02, 04

## Question

The CI split is decided: **fast tier local (`just check`), deep tier on CI, on
push, asynchronously.** That decision has a consequence the owner flagged but has
not yet resolved — it **breaks lumin's own spec**.

`lumin/.scratch/qa-pipeline/spec.md` states two principles that now conflict with
the plan:

- **"One entry point."** *"`just qa` runs every gate and is the definition of done.
  No git hooks, no Claude Code hooks — enforcement is the entry point plus
  `AGENTS.md` rules."* Under the new split, done means "`just check` green locally
  **and** the CI verdict green" — two places to look, and an agent that runs
  `just qa` locally is now doing work it was meant to offload.
- **"Blessing is human."** Goldens and perf Ceilings regenerate only on explicit
  human request, and a bless run never reports green. Blessing on a remote runner
  is a different act than blessing on the laptop.

Decide, with ticket 02's measurements in hand (especially whether callgrind
Ceilings survive the move to an i5-9400, and whether the smoke gate can run
headless at all):

1. **What is the new definition of done**, stated as precisely as the current spec
   states its own? Does `just qa` remain runnable locally as an escape hatch, and
   if so what is it *for*?
2. **Which gates actually move?** All six deep gates, or does anything stay local
   because CI cannot host it (candidate: the smoke gate) or because its results are
   host-dependent (candidate: the perf gate)?
3. **Where do Ceilings and Goldens get anchored** — laptop or runner? If both must
   agree and they cannot, one of them stops being authoritative; say which.
4. **How does an agent know?** `lumin/AGENTS.md` currently encodes the rule that
   `just qa` green is the gate. What replaces that instruction, and how does an
   agent working on lumin wait for or read a remote verdict?
5. **Does the spec get amended, and by whom?** This is a change to lumin's locked
   QA spec — it needs a version bump / amendment note, not a silent drift.

Output: the amended definition of done, precise enough to edit into lumin's spec
and `AGENTS.md` as a follow-on execution issue.

## Amendment (2026-08-23, from ticket 02) — this ticket's real content

Ticket 02 came back **feasible on all three questions**, which narrows this ticket
rather than widening it. The hardware fears are dead:

- **The perf gate's `Ir` does port.** Valgrind masks `CPUID` to a synthetic
  *Haswell*, so the glibc AVX-512-vs-AVX2 `memcpy` dispatch that would have moved
  `BLIT_IR` cannot fire under callgrind. Verified in Valgrind 3.24.0 source.
- **The smoke gate runs headless** — `WLR_BACKENDS=headless` + `WLR_RENDERER=pixman`
  creates no session and touches no DRM device. So it does **not** have to stay
  local, and question 2 of this ticket largely answers itself.

**What is left is the actual finding, and it is a spec gap: §4.5 assumes exactly
one machine measures `Ir`.** Ceilings are committed to source, Blessing is
human-only, the Anchoring rule gates a bless on the wall-clock bars passing — but
there is **no rule for which host owns the Ceilings**, and `just bless-perf` has no
notion of "which machine's". With uniform 10% headroom, any residual shift is a
false green (helium lower — the dangerous, silent one) or a false red, and a
re-anchor on either host rewrites what the other is measured against.

**Choose between three resolutions** (asset §1.6, in the researcher's order of
preference):

1. **The CI host is the anchoring authority.** Ceilings mean "as measured on helium
   under valgrind 3.24 / glibc 2.41 / rustc 1.94.1"; krypton becomes advisory.
   Looks available — krypton measured the particles frame at 1.07 ms of a 16.67 ms
   budget (~15× headroom), so at ~1.6× slower single-thread helium still has ~10×,
   satisfying the Anchoring rule. **Confirm with measurement M8 before committing.**
2. **Require agreement and gate on it** — keep krypton's Ceilings, add a documented
   cross-host agreement rule; a divergence is an incident, not a bless.
3. **Per-host Ceilings** — honest, and the worst: doubles the bless ritual and
   admits the number isn't portable.

**Run M1 and M4 before this grilling.** M1 is a `sha256sum` of Valgrind's synthetic
CPU diagnostics (krypton:
`df7966c3f7caa6ae1dfffce3bf4ebba360e78f9679667f760625983f5ae3fc79`, 129 lines) —
an identical digest on helium closes the CPU-dispatch channel entirely. M4 is the
twelve `Ir` values vs `docs/perf-calibration.md`, where **byte-identical is the
pass condition** — that is the measurement this decision actually turns on. Both
are single cheap commands; the full list of eight is in the asset's §4.

**Also fold into the spec amendment, whichever resolution wins:** no
`RUSTFLAGS`/`target-cpu` in CI, no `CARGO_INCREMENTAL`, `GLIBC_TUNABLES` unset, and
**valgrind + glibc versions recorded in the calibration row** alongside rustc.

**Sizing context for the "is the wait tolerable" half of question 1:** deep tier is
**~25–40 min warm** (mutants dominating at ~18 min idle / 20–30 min next to a
transcode), and **60–90 min on a cold checkout**.

### Rider (from asset 02's later revision)

**M1 and M4 must be run inside the runner's job image, not in a host shell on
helium.** Under a containerised runner the glibc, valgrind build, and `LD_PRELOAD`
prefix the perf gate sees belong to the job image — so a host-shell measurement
verifies the wrong environment and can return a **false pass** that locks this
decision on bad evidence. Pin the job image to Debian 13 / glibc 2.41 / valgrind
3.24.0; **alpine/musl is disqualifying**. Record the **image digest** in
`docs/perf-calibration.md` alongside rustc and valgrind — which is itself part of
the spec amendment this ticket produces.

**A fourth thing to decide here:** where `nice`/`ionice` and `--in-place` live.
`mutants: cargo mutants` is in lumin's justfile, and spec §2 makes the justfile
*the* entry point — so either the runner wraps the invocation and passes flags by
env (lumin untouched; the gate then behaves differently in CI than locally), or the
justfile changes and goes through the spec's rule-6 flagging ritual. Note
`--in-place` is a **CI-only** truth: it mutates the checkout, which is fine in a
throwaway workspace and wrong on a developer's tree.
