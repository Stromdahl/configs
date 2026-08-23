# Does lumin's deep QA tier actually run on an i5-9400?

Type: research
Status: claimed

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
