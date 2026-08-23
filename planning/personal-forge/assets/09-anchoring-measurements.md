# Ticket 09 premise check — M1, M2, M4, M8 (and M5 as a by-product)

Run 2026-08-23 from krypton. Everything below is reproducible; the literal
commands are in §5.

**Environment under test:** a `debian:trixie` container as a stand-in for the
eventual job image — `debian@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958`,
glibc `2.41-12+deb13u3`, valgrind `1:3.24.0-3` (3.24.0), rustc `1.94.1
(e408947bf 2026-03-25)`, `gungraun-runner 0.19.4`. Byte-identical package
versions to krypton's host, and Debian 13 / glibc 2.41 as ticket 02's rider
demands.

**Runtime caveat, stated up front:** the container runtime here was **Docker**
(helium 29.6.2, krypton 29.7.2), not the rootless Podman ticket 04 recommends.
That substitution is sound for what these measurements test — glibc, valgrind
and libc dispatch belong to the *image*, not the runtime — and §2 shows the one
place where the runtime does matter is identical between the two anyway. Diff
the real runner against this record once it exists.

Source under test: `git archive` of lumin at **`0df154c`**, extracted to a
CI-like path (`/workspace/lumin` inside the container). Not an rsync of
krypton's dev tree.

---

## 1. M1 — Valgrind's synthetic CPU: a near-miss, and the digest test is wrong

Ticket 02's asset gives the pass condition as an identical sha256 of the
`x86.cpu_features` / `dl_platform` diagnostics. **The digests differ**:

| host | lines | sha256 |
|---|---|---|
| krypton (native) | 129 | `df7966c3f7caa6ae1dfffce3bf4ebba360e78f9679667f760625983f5ae3fc79` |
| helium (in image) | 129 | `4619ee87fb416f7a3fb6b0f5ad38c1719792d72076186fb91242c5419c47dc08` |

Diffing the lines rather than trusting the digest, there are four differences
and **two of them are not differences at all**:

- `AVX_Fast_Unaligned_Load` and `Avoid_Short_Distance_REP_MOVSB` swap places —
  a **sort-collation artifact** (the container runs `C`, krypton does not).
  Same content, different order. **The recipe must say `LC_ALL=C sort`**; as
  written it can fail for no reason whatsoever.
- The two real differences are **one bit**, appearing twice:

  | field | krypton | helium |
  |---|---|---|
  | `features[0x1].cpuid[0x1]` (CPUID leaf 7, EBX) | `0x27aa` | `0x427aa` |
  | `features[0x1].active[0x1]` | `0x328` | `0x40328` |

  Bit 18 of leaf 7 EBX is **`RDSEED`**, present in helium's synthetic CPU and
  absent from krypton's. (`features[0x0]` is leaf 1 — `cpuid[0x0]=0x306c3`,
  family 6 / model 0x3c / stepping 3, the synthetic Haswell — and it is
  identical on both.)

**Everything glibc's string/memory IFUNC resolvers actually dispatch on is
bit-identical**: `dl_platform="haswell"`, AVX2, BMI1, BMI2, ERMS (`active`
`0x328` on both, modulo the RDSEED bit), `Prefer_No_AVX512=1`,
`AVX_Fast_Unaligned_Load=1`, `Fast_Rep_String=1`, `rep_movsb_threshold=0x2000`,
and every other `preferred.*` flag. `RDSEED` is not consulted by any memcpy or
string resolver.

**Verdict: the CPU-dispatch channel is closed in substance; the stated pass
condition was too strict.** M4 (§3) settles it outright regardless.

## 2. M2 — version parity: clean

glibc `2.41-12+deb13u3`, valgrind `3.24.0` (Debian `1:3.24.0-3`),
`GLIBC_TUNABLES=unset` — identical to krypton's host on all three.

## 3. The blocking discovery: default seccomp forbids the perf gate

The first perf-gate attempt failed before measuring anything:

```
setarch: failed to set personality to x86_64: Operation not permitted
gungraun_runner: Error: Error in task: Error running 'callgrind': Exit code was: '1'
```

gungraun disables ASLR via `setarch -R`, i.e. `personality(ADDR_NO_RANDOMIZE)`
= `0x40000`. **Docker's default seccomp profile denies it** — confirmed
directly: `setarch -R true` fails under the default profile and succeeds under
`--security-opt seccomp=unconfined`.

**This is not a Docker artifact of the runtime substitution.** Podman uses
`containers/common`'s `seccomp.json`, which allows `personality` only for args
`0`, `8`, `0x20000`, `0x20008`, `0xFFFFFFFF` — `0x40000` is **not** in the
allowlist. So ticket 04's recommended rootless-Podman shape hits this
identically.

**Consequence for the runner spec:** the perf gate cannot run in a
default-seccomp container. The job needs either
`--security-opt seccomp=unconfined` or — much better — a **custom profile that
is the default plus `personality(0x40000)`**. The weakening is small and
well-bounded: `ADDR_NO_RANDOMIZE` disables ASLR *for the job's own processes*,
which is a mitigation inside a throwaway container, not a host boundary. It is
expressible through `container.options`, which takes free-form docker options.

Nobody would have found this without running the gate. A host-shell measurement
on helium would have passed silently and shipped a runner that cannot run the
perf gate at all.

## 4. M4 — the twelve `Ir` values: the host is irrelevant

Three runs, all at `0df154c`. "in image" = the container above with
`--security-opt seccomp=unconfined`.

| bench | calibration (2026-08-20) | krypton native | krypton in image | helium in image |
|---|---|---|---|---|
| clear | 36,132 | 36,132 | 36,132 | 36,132 |
| blit | 17,293,274 | 17,293,274 | 17,293,274 | 17,293,274 |
| blend_source_over | 3,628,921 | 3,628,921 | 3,628,921 | 3,628,921 |
| blend_additive | 3,340,921 | 3,340,921 | 3,340,921 | 3,340,921 |
| line | 34,936 | 34,836 | 34,836 | 34,836 |
| rect | 66,489 | 66,042 | 66,042 | 66,042 |
| fill_rect | 3,640,558 | 3,640,460 | 3,640,460 | 3,640,460 |
| circle | 48,722 | 48,637 | 48,637 | 48,637 |
| fill_circle | 1,580,515 | 1,580,245 | 1,580,245 | 1,580,245 |
| text | 211,379 | 211,262 | 211,262 | 211,262 |
| set_pixel_grid | 3,226,781 | 3,226,781 | 3,226,781 | 3,226,781 |
| particles | 5,377,605 | 4,716,**473** | 4,716,**499** | 4,716,**499** |

Three findings, in order of importance:

1. **krypton and helium in the same image are byte-identical on all twelve.**
   A Zen 5 laptop and a Coffee Lake NAS produce the same instruction counts.
   **`Ir` is portable across these two hosts — the anchoring worry is empirically
   dead**, not merely argued away. This is the measurement the ticket said it
   turned on.
2. **The apparent drift is against the committed calibration row, not against
   helium.** `particles` reads 12.3% *lower* than the blessed 5,377,605 — but it
   reads that on **krypton too**, natively. So the calibration log is **stale
   relative to `0df154c`**: code changed since the 2026-08-20 bless and nobody
   re-anchored, because faster code stays inside a Ceiling and never fails. Six
   more benches show the same signature at 0.003–0.7%. This is lumin's business,
   not this map's — but it is worth noting that **the "silent false green"
   mechanism the ticket feared is already happening, from ordinary code drift,
   with no second host involved.** `PARTICLES_IR` currently carries ~25% real
   headroom instead of the intended 10%.
3. **M5 answered as a by-product, and it is not zero.** `particles` differs by
   **26 Ir** (5.5 × 10⁻⁶) between krypton-native and krypton-in-image — same
   host, same commit, so it is the workspace path/env, not the CPU. Both
   *container* runs agree exactly because they share `/workspace/lumin`. So a
   `bless` and the gate that checks it should run in the same environment; at
   this magnitude it is far inside any Ceiling, but "byte-identical" is only
   true when the path is held constant.

## 5. M8 — the Anchoring rule holds on helium

`cargo test -p particles --release -- --ignored --nocapture`, in the image on
helium:

```
fade + readout, no particles: 945.626µs
Smoke: 13961 live, update 38.635µs + draw 1.690396ms = 1.729031ms
Glow:  14031 live, update 38.701µs + draw 1.662166ms = 1.700867ms
test sim::tests::update_and_draw_fit_in_a_sixty_hertz_frame ... ok
```

**1.70–1.73 ms of a 16.67 ms frame — ~9.6× headroom** (krypton: 1.07 ms,
~15.6×). Ticket 02 predicted ~1.7 ms; it landed at 1.70. So spec §4.5's
Anchoring rule — *a perf bless is valid only on a machine where the wall-clock
bars demonstrably pass* — **is satisfied on helium**, and option 1 of the
ticket's three resolutions is available on evidence rather than on estimate.

## 6. Sizing, incidentally measured

- Perf-gate **build** from cold on helium's 6 cores: **50.6 s**; the twelve
  callgrind benches then run in **3.7 s**. The perf gate is nowhere near the
  cost centre — `cargo mutants` is, as ticket 02 said.
- `cargo install gungraun-runner 0.19.4` from source: ~41 s on helium. Bake it
  into the image.

## 7. Reproducing this

Scripts as run: `assets/09-m4-job-image.sh` (perf gate in the image; takes the
host as its only variable) and `assets/09-m8-wallclock.sh`. The M1 recipe,
corrected for the collation bug:

```bash
valgrind -q --tool=callgrind --cache-sim=no --callgrind-out-file=/dev/null \
  /lib64/ld-linux-x86-64.so.2 --list-diagnostics 2>/dev/null \
  | grep -E '^(x86\.cpu_features|dl_platform)' | LC_ALL=C sort | sha256sum
```

A digest mismatch is **not** by itself a failure — diff the lines and check
whether any bit glibc's string/memory IFUNC selection reads has actually moved.
