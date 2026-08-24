# lumin's definition of done, once the deep tier is remote

Type: grilling
Status: resolved
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

### Rider 2 (from asset 04) — the contention lever is now on this ticket's critical path

What was filed above as "a fourth thing to decide" has hardened into a **required**
decision, because ticket 04 established that the runner cannot solve it:

- **`container.options` has no niceness knob**, so a containerised job **cannot be
  niced from the runner side**. There is no configuration escape.
- **If rootless cgroup delegation is absent** (check **M9**: `cgroup.controllers`
  must list `cpu memory`), then `--cpus`/`--memory` are **silently inert** — and
  `nice`/`ionice` becomes **the only mechanism** making "coexists with a Jellyfin
  transcode" true, not a complement to cgroup limits.
- So the lever lives in exactly one of two places, and this ticket must pick:
  **(a)** a workflow step wrapping the justfile entry point — a CI-only divergence
  from spec §2's "the justfile is *the* entry point"; or **(b)** the justfile itself
  — a contract change requiring the spec's §8 rule-6 flagging ritual.
  **Preference from 04: (a)**, since `--in-place` is a CI-only truth (correct on a
  throwaway workspace, wrong on a developer's tree).
- **Caveat that affects whether the lever works at all:** `nice -n19` / `ionice -c3`
  need no privilege, but **`ionice` classes only bite under BFQ/CFQ** — on a `none`
  or `mq-deadline` queue it is a **no-op**. Verify helium's scheduler alongside M11;
  do not assume the I/O half of the lever exists.

### Riders from [ticket 12](12-adopt-runner-shape.md) (2026-08-23)

Two spec edits are now **owned by this ticket**, not 12:

1. **Add `--locked` to the justfile's cargo invocations** — a lumin **spec §2** change
   (the justfile is *the* entry point), so it needs the §8 rule-6 ritual. **It cannot be
   done from the CI side:** `--locked` is CLI-only — proved on cargo 1.94.1 with
   `Cargo.lock` deleted before each run, `--locked` fails while
   `--config net.locked=true` and `CARGO_NET_LOCKED=true` both succeed. (`net.offline`
   *is* a real key, but offline builds were declined.) **Rationale is reproducibility,
   not security:** without it CI can resolve a different dependency set than the laptop,
   and a dependency bump moving `BLIT_IR` would read as a regression in lumin's own code
   against the committed Ceilings. Accepted cost: every dependency update needs a
   deliberate `cargo update` before CI goes green.
2. **Choose the `CPUWeight=`/`CPUQuota=`/`MemoryMax=` values** — the `nice` question 04
   handed here. Two measurements now close off the guesswork:
   - **cgroup delegation IS present** on helium (`user-1000.slice` →
     `cpu memory pids`), so CPU and memory limits are **real, not silently inert**.
   - **`ionice` and cgroup `io` are unavailable to jobs, by construction** — every
     device is `mq-deadline` (nothing on BFQ/CFQ) *and* `io` is never delegated to a
     user slice, where rootless-Podman job containers land. So the I/O half of the lever
     **does not exist**; CPU/memory limits are the whole mechanism for "coexist with a
     Jellyfin transcode".
   - Useful magnitude: one `cargo mutants` run is **52.56 GiB written / 653 s** on
     krypton's 16 threads (`../assets/12-measure-mutants-io.sh`) — ~80 MB/s sustained,
     stretching to 25–40 min on helium's 6.

## Answer (2026-08-23)

**Read the status line on each section before building on it.** The owner replied
to this session's two grilling rounds with one word each ("agree", "agreed").
That is enough to carry the option-1 lean it followed, and nothing more — so
**§0–§2, §4 and §5 are measurement-driven and stand on their own, while §3's
refinement, §6's overturn of ticket 04, and §7's rule-1 text are PROPOSED and
await the owner's explicit confirmation.** The `coverage` call in §2 was never
asked and is flagged there. Downstream tickets should treat the proposed items as
recommendations, not as locked decisions.

> **Shelved 2026-08-24 — the confirmation is not coming for now.** The owner:
> *"we have shelved the 09 for now."* So **§3, §6 and §7 stay PROPOSED
> permanently until someone reopens them**, and that is now a deliberate
> record rather than a pending action. Nothing else in this ticket changes:
> §0–§2, §4 and §5 are measurement-driven and stand. What the shelving costs,
> named so nobody rediscovers it:
>
> - **§3** — the anchoring authority is left at the owner's confirmed
>   "helium is the authority, krypton advisory". The measured refinement (the
>   *pinned job image* is the authority, so any host running it may bless, and
>   krypton is not demoted) is **available but unclaimed**. The measurement
>   behind it stands either way: krypton and helium in the same image at the
>   same commit produce **byte-identical `Ir` on all twelve benches**.
> - **§6** — ticket 04's preference (a) is **not** overturned. Whoever writes
>   lumin's workflow inherits an unresolved conflict between §1's
>   "call `just` recipes, never inline a gate" and 04's preference, and must
>   raise it rather than assume §6.
> - **§7** — `AGENTS.md` rule 1 keeps its current text; the proposed
>   replacement is unadopted.
>
> None of this blocks the forge, the runner or the tracker. It blocks only
> lumin's own spec amendment, which is a lumin-tracker item.

**Runtime caveat carried up from the asset, because this is what downstream
reads:** every measurement below ran under **Docker**, not the rootless Podman
ticket 04 recommends. The substitution is sound for what was measured (glibc and
valgrind belong to the image), and the Podman half of the seccomp claim in §4 is
read from `containers/common`'s `seccomp.json` **source, not from a run**.

All evidence:
[`../assets/09-anchoring-measurements.md`](../assets/09-anchoring-measurements.md),
with both runnable scripts beside it.

### 0. The premise this ticket was built on is void — in the good direction

§4.5's "exactly one machine measures `Ir`" was filed as a latent hazard. It is
not one. **krypton (Zen 5) and helium (Coffee Lake), in the same pinned image at
the same commit, produce byte-identical `Ir` on all twelve benches** — not
within tolerance, identical. The cross-host false-green/false-red scenario that
made resolutions 2 and 3 worth considering does not occur. M1's digest
near-miss (one bit: `RDSEED`, which no glibc string/memory IFUNC resolver reads)
and its two sort-collation artifacts are documented in the asset §1; the digest
recipe itself is buggy and is corrected below.

### 1. The new definition of done

Spec §1's **"One entry point" is restated, not broken**: it becomes **one gate
*definition*, two execution sites.** The justfile remains the single definition
of what the gates *are*; only *where* they run splits. **The CI workflow MUST
call `just` recipes and MUST NOT define any gate inline** — that rule is what
keeps the principle true, and it is the reason for the choice in §6 below.

**Done** =

1. `just check` green locally, **and**
2. the work is pushed, **and**
3. the pushed commit's CI deep-tier verdict is green.

`just qa` **remains runnable locally**, and is for exactly three things:
reproducing a CI red, working offline, and pre-push confidence on a large
change. It is **not the verdict**. A green `just qa` does not make work done,
and a red CI is not downgraded to advisory because the laptop was green.

### 2. Which gates move: all of them

Five of the six deep recipes — `deny`, `proptest-deep`, `smoke`, `perf`,
`mutants`. **`coverage` is UNTESTED, not decided:** `cargo llvm-cov` with
`llvm-tools` under a rootless container is the one gate nobody has run anywhere,
it was never in this ticket's question, and today's seccomp discovery is a
standing warning against assuming a gate containerises just because it looks
like it should. Run it before the workflow is written. For the other five,
nothing stays local for capability reasons: ticket 02 cleared the
smoke gate (genuinely headless, no `/dev/dri`) and argued the perf gate ports;
today's run **proves** the perf gate ports. The fast tier stays local and
unchanged.

### 3. Anchoring: the job image is the authority, not a host — PROPOSED

Resolution **1 of the three** (the owner's call), **refined by the measurement —
and the refinement itself is proposed, not confirmed**: the owner agreed to
"helium is the authority, krypton advisory", and the measurement says the
narrower "the *image* is the authority" is available instead. If they decline the
refinement, fall back to their literal choice. Ceilings mean *"as
measured in the pinned job image"*. Consequences, precisely:

- **Any host running that image may bless.** helium is merely where CI runs it;
  krypton is **not** demoted, it reaches the authoritative environment with
  `docker run <image> just perf`.
- **A host-native run is advisory** — laptop included. `particles` differs by
  **26 `Ir`** (5.5 × 10⁻⁶) between krypton-native and krypton-in-image: same
  host, same commit, so it is the environment rather than the CPU — **cause
  inferred as the workspace path; path and env both varied, and M5's controlled
  experiment was not run**. Negligible in
  magnitude, but it means "byte-identical" is only true with the environment
  held constant, so the authoritative claim is pinned to the image.
- **The Anchoring rule is satisfied on helium** (M8): the v0.1 bar runs at
  **1.70–1.73 ms of a 16.67 ms frame, ~9.6× headroom** (krypton 1.07 ms,
  ~15.6×). So helium is a legal blessing host on evidence.
- **Blessing stays human and never automated.** The human runs `just bless-perf`
  *in the image* and commits the result. No CI job ever blesses.

### 4. The environment contract, folded into the spec amendment

- No `RUSTFLAGS` / `target-cpu` in CI; no `CARGO_INCREMENTAL`; `GLIBC_TUNABLES`
  unset.
- Job image: **Debian 13 / glibc 2.41 / valgrind 3.24.0**. **musl is
  disqualifying.**
- The calibration row records **image digest + glibc + valgrind** alongside
  rustc.
- **New, and load-bearing: the job's seccomp profile must permit
  `personality(ADDR_NO_RANDOMIZE)` (`0x40000`).** gungraun disables ASLR via
  `setarch -R`; Docker's default profile denies it, and so does Podman's
  (`containers/common` allows `personality` only for `0`, `8`, `0x20000`,
  `0x20008`, `0xFFFFFFFF`), so this lands on ticket 04's rootless-Podman shape
  identically. The gate fails before measuring anything. **Use a custom profile
  = the default plus that one argument, not `seccomp=unconfined`** — the
  weakening only disables ASLR for the job's own processes inside a throwaway
  container. Passed via `container.options`, which takes free-form docker
  options.
- The M1 diagnostics recipe must use **`LC_ALL=C sort`**, and a digest mismatch
  is **not by itself a failure** — diff the lines and check whether any bit the
  IFUNC selection actually reads has moved.

### 5. `--locked` (rider from ticket 12)

Added to the justfile's cargo invocations, through spec §8's **rule-6 flagging
ritual**. It cannot be done CI-side — ticket 12 proved `--locked` is CLI-only.
**Rationale is reproducibility, not security:** without it CI can resolve a
different dependency set than the laptop, and a dependency bump moving `BLIT_IR`
would read as a regression in lumin's own code. Accepted cost: every dependency
update needs a deliberate `cargo update` first.

### 6. `--in-place` and the contention lever — PROPOSED

**Ticket 04's preference (a) would be overturned** by §1's rule, and this
reversal of a prior ticket's recommendation is exactly the kind of call that
needs the owner's word rather than a one-word reply. A workflow-side
wrapper that bypasses the justfile would be exactly the inline gate definition
§1 forbids. Instead:

- **The recipe grows an explicit parameter** — `mutants *ARGS:` — and CI calls
  `just mutants --in-place`. The CI-only truth stays visible at the call site,
  and the justfile stays the single definition. Rule-6 flagged.
- **`nice` drops out entirely.** `ionice` is unavailable by construction
  (ticket 12: every device `mq-deadline`, `io` never delegated to a user slice),
  and cgroup CPU/memory limits are real. So the lever is
  **`container.options: --cpus/--memory`** at job level plus `CPUWeight` on the
  runner unit — no niceness anywhere.
- **The systemd values (`CPUWeight=`/`CPUQuota=`/`MemoryMax=`) are deliberately
  NOT set here.** They live on the runner unit, and ticket 12 left the **unit
  type** (system-with-`User=` vs `systemd --user`) open. Picking numbers for an
  unnamed unit would be invention. They belong to whoever closes the unit type,
  in the runner build issue.

### 7. How an agent knows (AGENTS.md rule 1) — PROPOSED TEXT

Deep tier is 25–40 min warm, so blocking an agent session on it is not the
design. Rule 1 becomes:

> Verify through the entry point: `just check` while iterating. Work is **not
> done** until the pushed commit's CI deep-tier verdict is green. Report the run
> and its verdict; never claim done on a local green, and never run `just qa` to
> stand in for the CI verdict.

Reading the verdict goes through a **`bin/` wrapper over Forgejo's commit-status
API**, not raw curl at the call site. Rules 2–6 are unchanged; rule 6 now also
covers the `mutants *ARGS` parameterization and `--locked`.

### 8. Amendment mechanics

lumin's QA spec is locked, so this lands as an **amendment note plus a version
bump** on `.scratch/qa-pipeline/spec.md`, not silent drift — human-approved,
executed as issues in **lumin's own tracker**, not here. This ticket produces
the text, not the edit.

### Execution items surfaced (not decisions — parked on the map)

1. **lumin's committed Ceilings are already stale**, independent of the CI split:
   `particles` measures 4,716,499 against a blessed 5,377,605 — **on krypton
   too**. Code got faster after the 2026-08-20 bless, stayed inside the Ceiling,
   and reported nothing. `PARTICLES_IR` carries ~25% real headroom instead of
   10%, and six more benches show the same signature at 0.003–0.7%. Needs a
   human re-anchor bless in lumin. Worth noting the ticket's feared "silent false
   green" is **already happening from ordinary code drift, with no second host
   involved**.
2. The spec amendment + `AGENTS.md` swap + the two justfile changes (`--locked`,
   `mutants *ARGS`).
3. The custom seccomp profile file and its `container.options` wiring.
4. The `bin/` wrapper over the commit-status API.
