# Does lumin's deep QA tier actually run on an i5-9400?

Type: research
Status: resolved

## Question

**This is the effort's sharpest technical risk.** The whole CI leg assumes lumin's
deep tier can run somewhere other than krypton. Establish whether it can —
by measurement and by reading, not by assumption.

Ground truth to work from:
- Contract: `~/projects/lumin/.scratch/qa-pipeline/spec.md`; entry point
  `~/projects/lumin/justfile`.
- Deep tier = `deny`, `proptest-deep` (`PROPTEST_CASES=10000`), `smoke`, `perf`,
  `mutants`, `coverage`.
- Pinned deps (from `just preflight`): **rustc 1.94.1**, `just`, **`cage`**,
  **`grim`**, **valgrind >= 3.20**, `cargo-machete`, `cargo-mutants`, `cargo-deny`,
  `cargo-llvm-cov`, **`gungraun-runner` 0.19.4** (must match the pinned dev-dep).
- Measured cost on krypton: 1109 mutants / 677 s of phase time for the mutants
  gate alone (`lumin/mutants.out/outcomes.json`).
- Target: helium, **i5-9400 6C/6T, 16 GB**, headless, no discrete GPU (iGPU used
  by Jellyfin), Debian.

The three questions that actually decide this:

1. **The perf gate.** It compares **callgrind instruction counts (Ir)** against
   *committed* Ceilings, with a human-only Blessing rule and an Anchoring rule.
   Does Ir reproduce across CPUs? (Reason from what valgrind actually counts —
   instructions retired under emulation, not cycles — but *verify*, and check what
   else moves the number: rustc version, target-cpu flags, allocator, libc.) If
   the Ceilings do not port, laptop and CI will disagree about green, and that is
   a spec problem for ticket 09 — say so plainly with evidence.
2. **The smoke gate.** It runs the windowed stack inside `cage` (a Wayland kiosk
   compositor) and screenshots with `grim`. On a **headless server with no seat
   and no display**, does that work? Investigate: does `cage` need a real DRM
   device, can it run on `wlroots`' headless/pixman software backend
   (`WLR_BACKENDS=headless`, `WLR_RENDERER=pixman`), does it need
   `/dev/dri/renderD128` (which exists on helium but is Jellyfin's), and what does
   that imply for running it *inside a container*.
3. **Wall-clock and contention.** Rough total for the deep tier on 6 cores, and
   whether `cargo mutants` (which parallelizes hard) needs a `--jobs` cap or
   `nice`/`ionice` to stay a good citizen next to a Jellyfin transcode. Note the
   owner has already accepted that helium gets loaded — this is for sizing, not
   for re-opening the decision.

Measure what can be measured cheaply and safely. **Do not run a full `just qa`
anywhere as part of this ticket** — reason from the recorded outcomes, targeted
single-gate probes, and the docs. If a probe needs helium, check `ssh-add -l`
first and stop if the key is locked.

Capture findings as `../assets/02-lumin-deep-tier-feasibility.md`.

## Answer

Resolved 2026-08-23. Full findings, with Valgrind/wlroots source citations and
live krypton measurements:
[`../assets/02-lumin-deep-tier-feasibility.md`](../assets/02-lumin-deep-tier-feasibility.md).

**The deep tier is feasible on helium. All three questions clear — and the biggest
risk turned out not to be the hardware at all.**

1. **Perf gate — WORKS WITH CAVEATS.** The mechanism that would have broken this
   is real natively: glibc 2.41's IFUNC resolvers dispatch `memcpy` on AVX-512 vs
   AVX2, and `BLIT_IR` (17.3 M `Ir`, by far the largest bench) is exactly the
   copy-heavy shape that would notice. **But under Valgrind it cannot happen** —
   VEX masks `CPUID` to a hardcoded synthetic *Haswell*, returning compile-time
   constants for every leaf, patching only F16C/RDRAND/RDSEED from the real host
   (none of which any string IFUNC reads). Verified in Valgrind 3.24.0 source and
   confirmed by measurement on krypton, which reports `dl_platform="haswell"`
   despite being an AVX-512 machine. So the Zen 5 → Coffee Lake move does **not**
   move `Ir` through that channel.
2. **Smoke gate — WORKS.** Not "should work": `WLR_BACKENDS=headless` +
   `WLR_RENDERER=pixman` creates no session and touches no DRM device at all — no
   seat, no `/dev/dri`, no libseat. Verified in wlroots 0.18 source, and the
   strongest evidence is lumin's own harness. This also frees the runner from
   needing `/dev/dri` (which is Jellyfin's), which matters for ticket 04's
   confinement question.
3. **Wall clock — WORKS.** **~25–40 min warm, mutants dominating** (~18 min idle,
   20–30 min next to a Jellyfin transcode); a first run on a cold checkout is
   plausibly 60–90 min. Comfortably inside the accepted "asynchronous, the win is
   laptop load not speed" envelope. Notable: the mutants gate is **serial and
   build-bound** (measured, not assumed), and **Valgrind serialises guest threads
   by design** — so the perf gate is single-threaded and helium's core count buys
   it nothing; only clock matters. Recommendation is `--in-place` rather than
   `--jobs`. Also: `cargo llvm-cov` cannot reuse the `cargo test` cache by design
   (separate target dir), but the two coexist without thrashing — and a bare
   `cargo llvm-cov clean` nukes dependencies, so prefer `clean --workspace`.

**The sharpest finding, and it is a spec problem rather than a hardware one —
this is ticket 09's real content:** spec §4.5 **assumes exactly one machine
measures `Ir`.** It commits Ceilings to source, makes Blessing human-only, and
gates a bless behind the Anchoring rule — but there is **no rule for which host
owns the Ceilings** once two hosts run the gate, and no per-host mechanism.
`just bless-perf` has no notion of "which machine's Ceilings". With uniform 10%
headroom, any residual shift is either a false green (helium lower — the silent
one) or a false red, with no defined remedy, and a re-anchor on either host
rewrites the numbers the other is measured against. Three resolutions are laid out
for ticket 09; the recommended one is **designate the CI host as the anchoring
authority**, which looks available — krypton measured the particles frame at
1.07 ms of a 16.67 ms budget (~15× headroom), so at ~1.6× slower single-thread
helium still has ~10×.

Whichever ticket 09 picks, the spec should also gain: *no `RUSTFLAGS`/`target-cpu`
in CI, no `CARGO_INCREMENTAL`, `GLIBC_TUNABLES` unset, and valgrind + glibc
versions recorded in the calibration row alongside rustc.*

**Eight named measurements must run on helium before the CI design is locked** —
each a single cheap command, listed in the asset's §4. The decisive one is **M1**:
a `sha256sum` of Valgrind's synthetic CPU diagnostics. krypton's is
`df7966c3f7caa6ae1dfffce3bf4ebba360e78f9679667f760625983f5ae3fc79` (129 lines);
an identical digest on helium closes the entire glibc-CPU-dispatch channel. **M4**
(the twelve `Ir` values vs `docs/perf-calibration.md`, byte-identical is the pass
condition) is the one that decides ticket 09. None were run — this ticket did not
ssh to helium.
