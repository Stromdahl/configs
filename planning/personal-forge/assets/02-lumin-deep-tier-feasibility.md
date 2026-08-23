# Does lumin's deep QA tier actually run on an i5-9400? — findings

Research asset for [`issues/02-lumin-deep-tier-on-helium.md`](../issues/02-lumin-deep-tier-on-helium.md).
Written 2026-08-23. No full gate was run anywhere; every number below is
either recorded in lumin's own artifacts, measured by a cheap targeted
probe, or derived and labelled as such.

**Hosts.** krypton = AMD Ryzen AI 7 350 (Zen 5 + Zen 5c, 8C/16T, AVX-512),
Debian 13.6, glibc 2.41-12+deb13u3, valgrind 3.24.0, rustc 1.94.1 (pinned).
helium = Intel i5-9400 (Coffee Lake, 6C/6T, **AVX2, no AVX-512**), 16 GB,
headless Debian, iGPU used by Jellyfin.

## Verdicts at a glance

| # | Question | Verdict |
|---|---|---|
| 1 | callgrind `Ir` perf gate reproduces on a different CPU | **WORKS WITH CAVEATS** |
| 2 | `cage` + `grim` smoke gate on a headless, seatless server | **WORKS** |
| 3 | deep-tier wall clock on 6 cores / 16 GB, contention | **WORKS** (feasibility); the *number* needs a live measurement |

The single biggest risk is **not** the CPU. It is that spec §4.5 has no rule
for *which host owns the Ceilings* once two hosts run the perf gate — see
[§1.6](#16-the-spec-problem-for-ticket-09).

---

## 1. The perf gate: does callgrind `Ir` port from Zen 5 to Coffee Lake?

**Verdict: WORKS WITH CAVEATS.** The mechanism that would have broken it —
glibc's IFUNC dispatch on host CPU features — is closed by Valgrind, which
presents the guest a *hardcoded synthetic Haswell* CPUID rather than the real
host's. One confirmatory command on helium settles it (measurement **M1**).

### 1.1 What `Ir` is

Cachegrind manual: *"The `I refs` number is short for "Instruction cache
references", which is equivalent to "instructions executed"."* and
*"**Precise.** Cachegrind measures the exact number of instructions executed
by your program, not an approximation."*
— <https://valgrind.org/docs/manual/cg-manual.html>

Core manual: *"Your program is then run on a **synthetic CPU** provided by the
Valgrind core"*; *"Valgrind simulates every single instruction your program
executes."* — <https://valgrind.org/docs/manual/manual-core.html>

So `Ir` is a count of guest instructions under emulation, not cycles and not
a hardware performance counter. Cachegrind explicitly contrasts itself with
`perf` for that reason (same page). Callgrind's own manual confirms
`--cache-sim=<yes|no> [default: no]` — *"By default, only instruction read
accesses will be counted ("Ir")"* —
<https://valgrind.org/docs/manual/cl-manual.html>. lumin passes
`--cache-sim=no` explicitly (`lumin/benches/perf.rs`, `fn gate`), which is
belt-and-braces but load-bearing: with cache simulation on, cachegrind derives
parameters from the **host's real cache configuration**, which differs between
these two CPUs. Off, no host cache parameter enters the metric at all.

### 1.2 Reproducibility: what Valgrind itself claims and warns

Claim (cg-manual §5.1): *"execution time might vary by several percent … In
contrast, **instruction counts are highly reproducible**; for some programs
they are perfectly reproducible."*

Warning (cg-manual §5.8.3, Accuracy): *"results are **very sensitive**.
Changing the size of the executable being profiled, or the sizes of any of the
shared libraries it uses, or **even the length of their file names**, can
perturb the results."* and *"address space layout randomisation (ASLR) … also
perturbs the results."*

Two things resolve that warning for lumin specifically:

1. **Empirically, run-to-run is exact.** Repeated identical callgrind
   invocations on krypton produced bit-identical `Ir` 3/3 with ASLR on. And
   lumin's own calibration log records the stronger result across *days and
   commits*: three consecutive blessings where *"all nine measured
   byte-identical to the row above"* (`docs/perf-calibration.md`).
2. **gungraun scopes collection to the benchmark function**, so loader work,
   env block and argv never enter the number. Its guide: *"By default,
   Gungraun sets this toggle (which we call EntryPoint) to the benchmarking
   function. Setting the toggle implies `--collect-atstart=no`. So, all events
   before (in the setup) and after the benchmark function (in the teardown) are
   not collected."* —
   <https://gungraun.github.io/gungraun/latest/html/print.html#gungraun-under-the-hood>

   Verified with raw callgrind using the same toggles: adding an 8 KB
   environment variable moved whole-process `Ir` by +245 but moved
   **scoped `Ir` by exactly 0**; `taskset -c 0` (1 visible CPU instead of 16)
   likewise moved scoped `Ir` by 0.

### 1.3 What *does* move `Ir` — the real list

| Channel | Moves `Ir`? | Status for krypton → helium |
|---|---|---|
| rustc version / codegen | **Yes, freely** | Closed: `rust-toolchain.toml` pins `1.94.1` exactly, and spec §5 makes the bump a human ritual that re-anchors every Ceiling. |
| `-C target-cpu` / `RUSTFLAGS` | **Yes, and dangerously** | Closed: lumin has **no `.cargo/config.toml` `[build] rustflags`** (only `.cargo/mutants.toml`) and no `RUSTFLAGS` in the recipes. `.scratch/int-coords/issues/01` already records that *"the build is baseline x86-64 without SSE4.1"*. A CI runner must not inject `target-cpu=native`: it makes a *different binary per host*, and on Zen 5 it emits AVX-512 that **SIGILLs under valgrind 3.24** (measured). |
| `codegen-units` / incremental | **Yes** | Open, cheap: default is 16 non-incremental, 256 incremental (<https://doc.rust-lang.org/rustc/codegen-options/index.html>). `cargo bench` is non-incremental by default on both hosts, so this is fine as long as CI does not set `CARGO_INCREMENTAL=1`. |
| valgrind version | Marginal | 3.22 vs 3.24: the CPUID helper `amd64g_dirtyhelper_CPUID_avx2` is **byte-identical between tags `VALGRIND_3_22_0` and `VALGRIND_3_24_0`**, and NEWS for 3.21–3.24 carries no callgrind instrumentation change affecting `Ir`. Keep it pinned anyway (the injected `LD_PRELOAD` path length is version/prefix dependent, and that *is* a path-length channel). Both hosts should be Debian 13's `1:3.24.0-3`. |
| Valgrind's libc function replacement | **No** | Callgrind does **not** replace string/malloc functions. `--soname-synonyms` docs name only *"memcheck, helgrind, drd, massif, dhat"* (<https://valgrind.org/docs/manual/manual-core.html>). Confirmed three ways on the installed 3.24.0: no `vgpreload_callgrind-*.so` exists; `--trace-redir=yes` under callgrind shows only the three vsyscall-page redirections; and a real callgrind profile contains `fn=__strlen_avx2`, `fn=__memset_avx2_unaligned_erms`, `fn=sysmalloc`. **Real glibc code runs and is counted in `Ir`.** |
| **glibc IFUNC CPU dispatch** | **Yes, natively — percent-scale** | **This is the one that mattered, and Valgrind closes it. See §1.4.** |
| Rust's allocator | No (beyond §1.4) | `rustc 1.94.1` with `Vec`/`String` shows `fn=__rustc::__rust_realloc` → glibc `fn=sysmalloc` under callgrind. glibc malloc does no CPUID dispatch; its arena count scales with core count only for multi-threaded programs, and spec §4.5 mandates single-threaded benches. |
| env size, argv length, ASLR | Whole-process yes, **scoped no** | Closed by gungraun's EntryPoint toggle (§1.2). |
| visible CPU count | Whole-process +14 `Ir`, **scoped 0** | Valgrind does *not* virtualise CPU count (`nproc` reports the host's real count under callgrind), so 16T vs 6C is a genuine channel — but it falls outside the gated region. |
| **working-directory path length** | **Plausibly yes** | Open by construction in CI. gungraun's own Sandbox docs: *"it is not implausible that code has different event counts just because the directory it is executed in has a different length … if a member of your project has set up the project in `/home/bob/workspace/our-project` … and the ci runs the benchmarks in `/runner/our-project`, the event counts might differ."* A Forgejo runner workspace path is **not** `/home/ms/projects/lumin`. The EntryPoint toggle should exclude it (paths are consumed at load/startup), but this is the one variable that changes *only* in CI — measurement **M5**. |
| `GLIBC_TUNABLES` | **Yes, hugely** | Must be unset (or identical) on both hosts. Measured on krypton, same binary, whole-process `Ir`: default 27,384,050; `glibc.cpu.hwcaps=-AVX2` → 28,198,109 (**+3.0%**); `glibc.cpu.hwcaps=-ERMS` → 15,511,860 (**−43.4%**). Scoped `Ir` moves by the same percentages, so this channel is *not* closed by the toggle. krypton has it unset. |

### 1.4 The decisive finding: Valgrind masks CPUID to a synthetic Haswell

**Natively, the concern is real.** glibc 2.41's
`sysdeps/x86_64/multiarch/ifunc-memmove.h` selects between
`avx512_unaligned_erms` / `evex_unaligned_erms` / `avx_unaligned_erms` /
`ssse3` / `sse2_unaligned` by reading `AVX512F`, `AVX512VL`, `ERMS`,
`Prefer_ERMS`, `Prefer_FSRM`, `AVX_Fast_Unaligned_Load`, `SSSE3` and friends
(<https://raw.githubusercontent.com/bminor/glibc/glibc-2.41/sysdeps/x86_64/multiarch/ifunc-memmove.h>).
An identical binary with identical glibc *would* execute different `memcpy`
code on Zen 5 than on Coffee Lake — and lumin's `BLIT_IR` (17.3 M `Ir`, by far
the largest bench) is exactly the copy-heavy shape that would notice.

**Under Valgrind it cannot happen.** VEX dispatches the `CPUID` instruction to
one of five hardcoded dirty helpers. From
`VEX/priv/guest_amd64_toIR.c` (~line 22043, tag `VALGRIND_3_24_0`):

```c
/* This isn't entirely correct, CPUID should depend on the VEX
   capabilities, not on the underlying CPU. See bug #324882. */
if ((archinfo->hwcaps & VEX_HWCAPS_AMD64_SSSE3) &&
    (archinfo->hwcaps & VEX_HWCAPS_AMD64_CX16) &&
    (archinfo->hwcaps & VEX_HWCAPS_AMD64_AVX2)) {
   fName = "amd64g_dirtyhelper_CPUID_avx2";
   /* This is a Core-i7-4910-like machine */
}
```

`amd64g_dirtyhelper_CPUID_avx2` in `VEX/priv/guest_amd64_helpers.c` returns
**compile-time constants** for every leaf (leaf 1 `eax = 0x000306c3` = Haswell;
leaf 7.0 `ebx = 0x000027aa`; cache leaves 2/4/0xb/0x80000006 constant too).
Only three bits are patched from the real host: F16C, RDRAND, RDSEED — none of
which any string/memory IFUNC resolver reads.
Sources: <https://sourceware.org/git/?p=valgrind.git;a=blob_plain;hb=VALGRIND_3_24_0;f=VEX/priv/guest_amd64_toIR.c>,
<https://sourceware.org/git/?p=valgrind.git;a=blob_plain;hb=VALGRIND_3_24_0;f=VEX/priv/guest_amd64_helpers.c>

**Measured on krypton (an AVX-512 machine):**

```
NATIVE:          leaf1 eax=00b60f00 (family 0x1a model 0x60)  AVX2=1  AVX512F=1
UNDER CALLGRIND: leaf1 eax=000306c3 (family 0x6  model 0x3c)  AVX2=1  AVX512F=0
```

And glibc's own view of the machine, via `ld.so --list-diagnostics` run under
callgrind (verified independently on krypton for this report):

```
dl_platform="haswell"
x86.cpu_features.basic.family=0x6
x86.cpu_features.basic.model=0x3c
x86.cpu_features.basic.stepping=0x3
x86.cpu_features.level3_cache_size=0x800000        (native: 0x1000000)
x86.cpu_features.rep_movsb_threshold=0x2000        (native: 0xc00000)
x86.cpu_features.non_temporal_threshold=0x100000   (native: 0xc00000)
x86.cpu_features.rep_stosb_threshold=0x800         (native: 0xffff…ffff)
```

So glibc's IFUNC resolvers **and** its cache-derived memcpy/memset thresholds
are computed from a synthetic Haswell, not from the host. The profile confirms
the outcome: `__strlen_avx2`, `__memset_avx2_unaligned_erms`, never an EVEX
variant, on a machine that has AVX-512.

**Answer:** natively the two hosts would differ; **under Valgrind they should
not**, because both land in the same `CPUID_avx2` helper class (the i5-9400 has
SSSE3 + CX16 + AVX2). That is the plain expectation from the source, not a
guess — but it routes through Valgrind's *own* hwcaps detection rather than raw
CPUID, and that detection is demonstrably not a transparent mirror (RDSEED came
back 0 on a Zen 5 that has RDSEED). **Verify, don't infer: measurement M1.**

### 1.5 Headroom: how much shift the Ceilings can absorb

Every Ceiling in `lumin/benches/ceilings.rs` is exactly `measured × 1.10`
against the latest calibration row — checked for all twelve, uniformly
`1.1000`. So:

- **Budget for any cross-host `Ir` shift: +10%, and not a byte more.**
- The worst *observed* glibc-dispatch divergence (forcing `hwcaps=-AVX2`) was
  **+3.0%** — inside the budget, but it would eat a third of it.
- If Valgrind's CPUID mask holds (§1.4), the expected shift is **0%**.

Two asymmetries worth naming:

- **`hard_limits` are the least portable configuration by construction.** A
  soft limit is a percentage re-anchored per baseline; an absolute `Ir` ceiling
  absorbs zero machine-dependent shift. lumin deliberately chose hard limits
  (spec §4.5: *"No soft limits, no committed baseline file"*), which is the
  right call for a *single* machine and the fragile one for two.
- **The gate is one-sided.** It fails only on *exceeding* a Ceiling. If helium
  measures systematically *lower* than krypton, CI stays green while real
  regressions hide under the slack. That is a silent-false-green risk, not a
  build break, and it is invisible without measurement **M4**.

Note also that gungraun's marketing claims are stronger than its own caveats.
README/guide: *"make them comparable between different systems completely
negating the noise of the environment"* and *"Instruction counts are precise
and portable across systems"*
(<https://gungraun.github.io/gungraun/latest/html/best_practices.html#understanding-your-metrics>)
— both are **maintainer assertions with no measurement or scope conditions
attached**, and the same guide's Sandbox section contradicts them for path
length. There is **no statement anywhere in the gungraun guide that baselines
are machine-specific**, and no cross-machine guidance at all. Do not treat the
README as evidence.

### 1.6 The spec problem for ticket 09

Say this plainly, because it is the sharpest finding of the three questions and
it is a *spec* problem rather than a hardware one:

**Spec §4.5 assumes exactly one machine measures `Ir`.** It commits Ceilings to
source, makes Blessing human-only, and gates a bless behind the Anchoring rule
(*"valid only on a machine where the wall-clock bars demonstrably pass"*). The
calibration log has a `machine` column — but the spec contains **no rule for
which host owns the Ceilings** once two hosts run the gate, and **no per-host
mechanism**. With uniform 10% headroom, any residual shift is either a false
green (helium lower) or a false red (helium higher) with no defined remedy: a
re-anchor on helium rewrites the numbers the laptop is then measured against,
and vice versa. `just bless-perf` has no notion of "which machine's Ceilings".

Three resolutions for ticket 09 to choose between, in order of my preference:

1. **Designate the CI host as the anchoring authority.** Ceilings mean "as
   measured on helium under valgrind 3.24 / glibc 2.41 / rustc 1.94.1"; krypton
   becomes advisory. This is *available*: the Anchoring rule requires the
   wall-clock bars to pass on the blessing machine, and helium plausibly
   satisfies it — krypton measured the particles frame at **1.07 ms of a
   16.67 ms budget (~15× headroom)**; at ~1.6× slower single-thread that is
   ~1.7 ms, still ~10× headroom. Confirm with measurement **M8** before
   committing to this.
2. **Require agreement, gate on it.** Keep krypton's Ceilings, and add a
   one-time cross-host check (M4) plus a documented rule that the two hosts'
   measured `Ir` must agree exactly (or within a stated band); a divergence is
   an incident, not a bless.
3. **Per-host Ceilings.** Honest, and the worst option: it doubles the bless
   ritual and quietly admits the number is not portable.

Whichever is chosen, add to the spec: *no `RUSTFLAGS`/`target-cpu` in CI, no
`CARGO_INCREMENTAL`, `GLIBC_TUNABLES` unset, valgrind and glibc versions
recorded in the calibration row alongside rustc.*

---

## 2. The smoke gate: `cage` + `grim` on a headless, seatless server

**Verdict: WORKS.** Not "should work" — the mechanism is verified in upstream
source, reproduced end-to-end in an unprivileged container with no `/dev/dri`
and no logind, **and lumin's own harness already runs this exact headless path
successfully on krypton**.

### 2.1 The strongest evidence is lumin's own

`tools/smoke/src/main.rs` spawns cage with `env_clear()` (re-adding only `PATH`
and `HOME`), a private `XDG_RUNTIME_DIR` at mode 0700, and
`WLR_BACKENDS=headless`, `WLR_RENDERER=pixman`, `WLR_LIBINPUT_NO_DEVICES=1`.
That means krypton's green runs are **not** using krypton's Wayland session,
DRM device or seat — the child cannot see them. The build ticket records the
result: *"All four assertions pass headless; run repeated 4× stable; live
session untouched by construction (private socket, no live-seat device)"* and
*"`just qa` fully green end-to-end on this machine"*
(`.scratch/qa-build/issues/07-smoke-gate-assembly.md`, status done; commit
`165f9b6`).

So Q2 reduces from "will this work headless" to "does a headless *server*
differ from a headless *path on a machine that happens to have a session*".
The answer, from source, is no — because wlroots never creates a session at all
on this path.

### 2.2 wlroots 0.18: `WLR_BACKENDS=headless` creates no session and touches no DRM

Source: `backend/backend.c`, tag 0.18.2 —
<https://gitlab.freedesktop.org/wlroots/wlroots/-/blob/0.18.2/backend/backend.c>

- `wlr_backend_autocreate` reads `WLR_BACKENDS`; when set it `goto success`
  after the `strtok_r` loop, so the `WAYLAND_DISPLAY`/`DISPLAY` probes and the
  DRM+libinput tail (`session_create_and_wait` → `attempt_libinput_backend` →
  `attempt_drm_backend`) are **never reached**.
- `attempt_backend_by_name` calls `session_create_and_wait` **only** in the
  `drm`/`libinput` branch (comment in source: *"DRM and libinput need a
  session"*). For `headless` it calls `attempt_headless_backend` and returns;
  `session` stays `NULL` and cage receives a NULL session. **libseat is never
  entered** — so no seatd, no logind, no `builtin` backend, no root.
- The headless backend's `wlr_backend_impl` is `{ .start, .destroy,
  .get_buffer_caps }` — there is **no `get_drm_fd`**, so
  `wlr_backend_get_drm_fd()` returns `-1`. No `/dev/dri` node is opened.
  `get_buffer_caps` returns `DATA_PTR | DMABUF | SHM`.
- `WLR_LIBINPUT_NO_DEVICES=1` is **inert** on this path (only consulted in the
  auto-DRM tail). Harmless; keep it.

Empirical confirmation: cage + grim ran to success in a container with
`LIBSEAT_BACKEND=bogus-does-not-exist` set — libseat would have errored on an
unknown backend name had it been consulted at all.

### 2.3 pixman renderer → shm allocator, no render node

`render/wlr_renderer.c::renderer_autocreate`: only the gles2 and vulkan
branches call `open_preferred_drm_fd()`. With `WLR_RENDERER=pixman`, `is_auto`
is false, both are skipped, and only `wlr_pixman_renderer_create()` runs — no
GBM, no `drmGetDevices2`, nothing under `/dev/dri`. In
`render/allocator/allocator.c::wlr_allocator_autocreate`, both DRM FDs come
back `-1`, the gbm branch requires `drm_fd >= 0` and is skipped, and the
**shm** branch matches → `wlr_shm_allocator_create()`.

**Directly relevant to the Jellyfin worry: there is zero contention for
`/dev/dri/renderD128`, because no render node is opened at all.** The cost is
CPU-only compositing — which is fine, because the smoke gate's assertions are
deliberately coarse (spec §4.4).

### 2.4 cage 0.2.0 and grim 1.4.0 line up

Source: <https://github.com/cage-kiosk/cage/blob/v0.2.0/cage.c>

- `main()` calls `wlr_backend_autocreate(event_loop, &server.session)` → honors
  `WLR_BACKENDS`. Then `wlr_renderer_autocreate`, `wlr_allocator_autocreate`.
- **Requires `XDG_RUNTIME_DIR`** (hard `return 1`). The harness supplies a
  private 0700 dir. ✔
- **No session/DRM/VT requirement.** The only VT code (`seat.c:265-270`) is
  gated on `-s` *and* `if (server->session)` — NULL here, so a no-op.
- **XWayland not required**: `wlr_xwayland_create` failure logs and continues
  (verified by renaming `/usr/bin/Xwayland` away). Debian pulls `xwayland` in
  as a cage dependency anyway.
- Headless output is **1280×720** (`wlr_headless_add_output(backend, 1280,
  720)`; `WLR_HEADLESS_OUTPUTS` sets the *count*, not the size). cage sets no
  mode — `output.c:handle_new_output` gates the mode block on a non-empty modes
  list, which a headless output does not have. This matches the harness's
  `injector::EXTENT = (1280, 720)` exactly. ✔
- cage creates `wlr_screencopy_manager_v1` (fatal if it fails) and
  `wlr_xdg_output_manager_v1`. grim 1.4.0 requires exactly
  `wlr-screencopy-unstable-v1` + `xdg-output-unstable-v1` + `wl_shm`
  (`protocol/meson.build`, and `main.c:499` hard-fails with *"compositor
  doesn't support wlr-screencopy-unstable-v1"*). grim 1.4.0 contains **no**
  `ext-image-copy-capture-v1` code, and wlroots 0.18.2 exports no
  `ext_image_copy_capture` symbols. **The pairing is consistent and there is no
  migration risk on trixie.** ✔
- cage creates `wlr_virtual_keyboard_manager_v1` and
  `wlr_virtual_pointer_manager_v1`, both fatal on failure — so if cage started,
  both globals exist. Same in 0.1.x. ✔

**The one caveat, and lumin already designed around it.** cage's
`seat.c:handle_new_keyboard` unconditionally does
`xkb_keymap_new_from_names(context, NULL, …)` and overrides whatever keymap a
`zwp_virtual_keyboard_v1` client uploaded — so a client sending keycodes
derived from *its own* keymap types nothing (reproduced: `wlrctl keyboard type`
exits 0 and delivers nothing; `wtype` works). lumin's injector is immune
because it sends **real evdev scancodes** (`escape` = 1, `d` = 32 — and 32 is
`d` under the default `us` layout too), and its own doc comment already
explains why wtype/wlrctl are wrong for it. No change needed.

### 2.5 Container implications

Verified working: `docker run --rm --shm-size=256m debian:trixie` — **no
`/dev/dri`, no `--privileged`, no `--cap-add`, no `--device`, default
seccomp/AppArmor, non-root uid 1000**, private `XDG_RUNTIME_DIR`. cage started,
a real client rendered, grim wrote a 1280×720 PNG with real content, and
virtual-keyboard text injection arrived intact.

- **`/dev/dri`: not needed.** (§2.2, §2.3)
- **No seat, no logind, no `/run/user/<uid>`, no `$USER`, no
  `WAYLAND_DISPLAY`** needed — cage sets `WAYLAND_DISPLAY` for its child.
- **`/dev/shm` size DOES matter — this is the real container gotcha.** Both
  wlroots' allocator (`util/shm.c::allocate_shm_file` → `shm_open`) and grim's
  capture buffer (`buffer.c::anonymous_shm_open` → `shm_open`) use **POSIX shm,
  i.e. `/dev/shm`** — not `memfd_create`. (libwayland's
  `os_create_anonymous_file` does prefer memfd, but that only covers clients
  that use it, not cage's swapchain or grim.) Measured: **1 MiB → cage dies
  SIGBUS (exit 135); 4 MiB → grim dies SIGBUS; 8/12/16/64 MiB fine at 720p.**
  `ftruncate` on tmpfs does not reserve, so exhaustion surfaces as **SIGBUS
  with no error message at all** — a nasty failure mode for the harness's 60 s
  timeout path. Budget ≈ (swapchain buffers + 1 grim buffer) × w × h × 4
  ≈ 3.5 MB/frame at 720p. **Docker's default 64 MiB is adequate; pass
  `--shm-size=256m` for headroom.** On bare-metal helium `/dev/shm` defaults to
  half of RAM (8 GB) — a non-issue there.
- **seccomp: no concern**, and `memfd_create` never enters this path anyway.
- Packages needed: `cage`, `grim`, `valgrind` (and Debian pulls `xwayland` +
  `xkeyboard-config` in as dependencies — cage compiles a default xkb keymap
  per keyboard and bails on that device if it can't).

The practical consequence for the CI design: **if the Forgejo runner executes
jobs in Docker, the smoke gate needs `--shm-size` set on the job container**
and nothing else. That belongs in ticket 04/09's runner configuration.

---

## 3. Wall clock and contention on 6 cores / 16 GB

**Verdict: WORKS** — the tier is feasible and nothing about 6C/16GB blocks it.
The *number* needs a live run (measurement **M7**); everything below is
derived, with its basis stated.

### 3.1 The mutants gate is serial and build-bound — measured, not guessed

Parsed from `lumin/mutants.out/outcomes.json` (cargo-mutants 27.1.0, run
2026-08-22 on krypton):

| | |
|---|---|
| mutants | 1109 (740 caught, 369 unviable, **0 missed**, 0 timeout) |
| wall clock | 680.7 s (12:12:48 → 12:24:08 UTC) |
| sum of all phase durations | 676.6 s |
| **effective parallelism** | **0.99 — the run was serial** |
| Build phases | 573.9 s over 1110 runs; mean 0.52 s, p90 0.82 s, max 17.14 s (the baseline) |
| Test phases | 102.7 s over 741 runs; mean 0.14 s, p50 0.15 s |

Two conclusions fall straight out:

1. **`--jobs` defaults to 1**, so the 677 s was single-job by default, not
   misconfiguration. cargo-mutants 27.1.0 `src/main.rs` declares `jobs:
   Option<usize>` with no default and `src/lab.rs` does
   `max(1, min(options.jobs.unwrap_or(1), mutants.len()))` —
   <https://github.com/sourcefrog/cargo-mutants/blob/v27.1.0/src/lab.rs#L94>
2. **85% of the cost is `cargo build`, not `cargo test`.** The gate is
   compile-and-link bound, and linking is single-threaded. So core count buys
   little and single-thread clock buys a lot.

### 3.2 Estimated helium wall clock

Basis for the scaling factor: i5-9400 is 6C/6T, 2.90 GHz base / **4.10 GHz max
turbo**, 9 MB L3, 65 W, AVX2 and no AVX-512 (Intel ARK SKU 134898, read from a
2026-05-14 Wayback snapshot — intel.com edge-blocks direct fetches; the part is
`Discontinued` so the specs are frozen). Ryzen AI 7 350 is 8C/16T (4× Zen 5 +
4× Zen 5c), **up to 5.0 GHz** boost, 3.5 GHz Zen 5c cap, 28 W default TDP
(<https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-7-350.html>).
PassMark single-thread puts the ratio at ≈**1.59×** favouring krypton —
*secondary source, aggregator estimate, cited only for the order of magnitude*.

| Gate | krypton basis | helium estimate | Confidence |
|---|---|---|---|
| `deny` | network advisory DB fetch | 10–30 s | high |
| `proptest-deep` | whole suite is **0.35 s** at default 256 cases; ×39 for the property portion at 10 000 | 15–60 s | medium-high |
| `smoke` | protocol sleeps dominate (~3.5 s fixed + 300 ms readiness poll + up-to-5 Escape attempts); 60 s hard cap | 10–25 s | high (wall-clock-bound, not CPU-bound) |
| `perf` | 12 benches, 38.5 M `Ir` total measured; callgrind floor ~4× native per the manual; dominated by 12 valgrind process starts + the bench compile | 2–5 min | **low — measure it** |
| `mutants` | **677 s measured, serial, build-bound** | **~18 min idle; 20–30 min next to a Jellyfin transcode** | medium-high |
| `coverage` | first run is a full instrumented rebuild of the winit/softbuffer graph into `target/llvm-cov-target`; later runs recompile workspace crates only | 2–6 min | medium |

**Deep tier total on a warm cache: ~25–40 min, mutants dominating.** The first
ever run on a fresh checkout (cold cargo registry, cold `target/`, cold
`llvm-cov-target`) is substantially worse — plausibly 60–90 min. Given the map
already accepts "asynchronous, the win is laptop load not speed", this is
comfortably inside the accepted envelope.

Supporting facts:

- **Valgrind serialises guest threads**, explicitly: *"Valgrind serialises
  execution so that only one (kernel) thread is running at a time … threaded
  apps never use more than one CPU simultaneously, even if you have a
  multiprocessor or multicore machine"*
  (<https://valgrind.org/docs/manual/manual-core.html> §2.8). The perf gate is a
  single-thread workload; helium's 6 cores buy it nothing, only clock does. The
  same section warns that with CPU frequency scaling active, futex-based
  locking can cost *"up to 50% degradation"* for multithreaded guests and
  recommends `taskset` — not applicable to lumin's single-threaded benches, but
  worth knowing.
- Callgrind's documented overhead floor: *"at most a slowdown of around 4,
  which is the minimum Valgrind overhead"*
  (<https://valgrind.org/docs/manual/cl-manual.html>), ~2× more with
  `--cache-sim=yes` — which lumin has off.
- **`cargo llvm-cov` cannot reuse the plain `cargo test` cache**, by design: it
  changes RUSTFLAGS and therefore uses a *separate* target dir,
  `<target>/llvm-cov-target` (`src/cargo.rs`: *"If we change RUSTFLAGS, all
  dependencies will be recompiled. Therefore, use a subdirectory of the target
  directory as the actual target directory"*). Good news: `target/debug` and
  the coverage tree coexist, so alternating gates don't thrash each other. Its
  default per-run clean removes workspace-crate artifacts only, not
  dependencies. CI trap: bare `cargo llvm-cov clean` nukes deps too — prefer
  `clean --workspace`.

### 3.3 Timeouts are not a risk — the premise doesn't hold here

cargo-mutants' auto test timeout is *"5 times the baseline test time, with a
minimum of 20 seconds"* (<https://mutants.rs/timeouts.html>; implemented as
`max(minimum_test_timeout, ceil(baseline × 5.0))` with the floor defaulting to
20 s in `src/options.rs`). lumin's baseline test phase is **0.35 s**, so
0.35 × 5 = 2 s and the **20 s floor dominates by ~10×**: a mutant would have to
run ~57× the baseline to time out. A 1.6× slower, loaded machine has enormous
margin. Build timeouts are off by default.

(Worth knowing anyway: timeouts get their own exit code — `3` *"Some tests
timed out"*, distinct from `2` *"not covered by tests"*
(<https://mutants.rs/exit-codes.html>) — so a runner can tell a real miss from
a slow machine if it ever matters.)

### 3.4 Recommendation: `--in-place`, not `--jobs`

The book is emphatic that `--jobs` is not a core-count knob
(<https://mutants.rs/parallelism.html>):

> **Caution:** `cargo build` and `cargo test` internally spawn many threads and
> processes and can be very resource hungry. Don't set `--jobs` too high, or
> your machine may thrash, run out of memory, or overheat.
> … You should set the number of jobs very conservatively, starting at `-j2` or
> `-j3`. Higher settings are only likely to be helpful on very large machines,
> perhaps with >100 cores and >256GB RAM. … Unlike with `make`, setting `-j`
> proportionally to the number of cores is unlikely to work out well, because
> the Rust build and test tools already parallelize very aggressively.

and each job costs a full build directory: *"Rust `target` directories can
commonly be 2GB or more, and there will be one per parallel job."*

**The bigger lever, and the bigger unknown, is `TMPDIR`.** cargo-mutants copies
the tree to a `tempfile::TempDir` — i.e. `TMPDIR`, `/tmp` by default
(`src/build_dir.rs`; <https://mutants.rs/build-dirs.html>). The book's own
performance page recommends a ramdisk *and* warns against it: *"Be careful that
the ramdisk does not use so much memory that it causes the system to swap."*
On krypton `/tmp` **is** tmpfs (16 GB, and already 73% full at the time of
writing). helium's is **unverified** and both branches are bad in different
ways:

- **disk-backed `/tmp`** → 2 GB+ of build-directory writes per job land on
  helium's storage, contending with snapraid and Jellyfin, on a box with a
  recurring SAS-cable IO fault on disk2 (`project_helium_disk2_io_fault`);
- **tmpfs `/tmp`** → 2 GB+ per job out of 16 GB shared with Immich ML and
  Paperless OCR.

Hence the recommendation, in order:

1. **`--in-place`** — eliminates the tree copy entirely, and per
   <https://mutants.rs/in-place.html> it is the one mode where *"the Rust
   toolchain … will reuse [build products]"*. On a throwaway CI checkout there
   is no reason not to. `ci.md`'s only performance advice is exactly this.
   Note it **conflicts with `--jobs`** (`main.rs:187`
   `conflicts_with = "jobs"`) — but since the recorded run was serial anyway,
   that fork resolves itself.
2. **`nice`/`ionice` the whole invocation.** cargo-mutants has no notion of
   either (grepped v27.1.0: zero hits for `ionice` or `CARGO_BUILD_JOBS`) —
   wrap it in the runner. This is the cheap, correct answer to "coexist with a
   Jellyfin transcode": Jellyfin's own transcode should win the CPU, and CI is
   explicitly asynchronous.

   **Where these live is a ticket-09 decision, not a given.** `mutants: cargo
   mutants` sits in lumin's justfile, which spec §2 makes *the* entry point —
   so either the runner wraps the whole `just qa` invocation in
   `nice`/`ionice` and passes flags via `CARGO_MUTANTS_JOBS`-style env (keeping
   lumin untouched, at the cost of the gate behaving differently in CI than
   locally), or the justfile changes and that goes through the usual §8 rule-6
   flagging ritual. The env route is cleaner: `--in-place` is a *CI-only* truth
   (it mutates the checkout, which is fine for a throwaway workspace and wrong
   on a developer's tree).
3. **If you do want parallelism later**, the documented mechanism for a shared
   machine is the **jobserver**, not `--jobs` alone
   (<https://mutants.rs/jobserver.html>): *"By default, cargo-mutants starts a
   jobserver configured to allow one job per CPU. This limit applies across all
   the subprocesses spawned by cargo-mutants."* So `-j2` with
   `--jobserver-tasks=3` caps *total* compiler concurrency at 3 of 6 cores.
   (It does not constrain the test framework, which doesn't speak the
   protocol.)
4. **Cheaper than any of the above:** `[profile.mutants]` with
   `debug = "none"`, `--all-targets` to skip doctests, and a faster linker. The
   book claims *"Using the Mold linker on Unix can give a 20% performance
   improvement"* and for Wild *"On one tree, using Wild cut the time to run
   cargo-mutants by more than half"* (<https://mutants.rs/performance.html>).
   On a run that is 85% build, **the linker is the highest-leverage single
   change available** — and it does not touch `Ir`, because the perf gate runs
   under `cargo bench`, not under mutants. Worth its own ticket-09 note.

---

## 4. Measurements that must happen on helium before the CI design is locked

None of these were run (no ssh to helium in this ticket). Each is a single
command, cheap, and safe.

**Run them where CI will actually run — inside the runner's job image, not in a
host shell on helium.** §2.5 establishes that a containerised Forgejo runner is
workable, but it has a consequence for §1 that is easy to miss: if jobs run in a
container, then the glibc, the valgrind build and the `LD_PRELOAD` install
prefix that the perf gate sees all belong to the **job image**, not to helium.
M1/M2/M4/M5/M6 executed in a host shell would verify the wrong environment,
come back green, and lock the CI design on a false pass. Therefore:

- pin the job image to a **Debian 13 base with glibc 2.41** (matching krypton's
  `2.41-12+deb13u3`) and Debian's `valgrind 1:3.24.0-3`;
- a **musl image (alpine) is disqualifying outright** — a different libc means
  different code inside the measured region, so different `Ir`, not a few
  percent of drift;
- treat the image digest as part of the perf gate's provenance, alongside rustc
  and valgrind, in `docs/perf-calibration.md`'s row.

**M1 — the cheap early proxy: is Valgrind's synthetic CPU identical on both
hosts?** (M4 is the actual settler; M1 predicts it for the price of one
command, so run M1 first.)

```bash
valgrind -q --tool=callgrind --cache-sim=no --callgrind-out-file=/dev/null \
  /lib64/ld-linux-x86-64.so.2 --list-diagnostics 2>/dev/null \
  | grep -E '^(x86\.cpu_features|dl_platform)' | sort | sha256sum
```

krypton, verified for this report: **129 lines,
`df7966c3f7caa6ae1dfffce3bf4ebba360e78f9679667f760625983f5ae3fc79`**, with
`dl_platform="haswell"`, family `0x6` / model `0x3c` / stepping `0x3`,
`rep_movsb_threshold=0x2000`. An identical digest on helium closes the entire
glibc-CPU-dispatch channel. Caveat: the digest is a *joint* check on Valgrind's
CPUID helper class × glibc version × the diagnostics format, so a mismatch
won't say which moved — pair it with M2. A helium result landing in
`CPUID_avx_and_cx16` instead (no AVX2) would mean roughly the +3.0% shift
measured in §1.3, straight through hard Ceilings that only have 10%.

**M2 — version parity.** `ldd --version; valgrind --version; dpkg -l cage grim
libwlroots-0.18 valgrind libc6`. krypton: glibc **2.41-12+deb13u3**, valgrind
**3.24.0** (Debian `1:3.24.0-3`), cage **0.2.0-2**, grim **1.4.0+ds-2+b1**,
libseat1 0.9.1, Debian 13.6, kernel 6.12.101. Also confirm
`echo "${GLIBC_TUNABLES:-unset}"` reports `unset`.

Then run **`just preflight`** — it is the authoritative list, and it hard-fails
on anything missing. Beyond the apt packages, a fresh host (or job image) must
`cargo install` five tools: `cargo-machete`, `cargo-mutants`, `cargo-deny`,
`cargo-llvm-cov`, and **`gungraun-runner` at exactly `0.19.4`** — preflight
string-matches `"gungraun-runner 0.19.4"` because it must match the pinned
`gungraun = "=0.19.4"` dev-dependency, so a bare `cargo install
gungraun-runner` that resolves newer will fail preflight. That is five
compile-from-source installs plus the rustup toolchain on first provision; bake
them into the job image rather than paying for them per run.

**M3 — `TMPDIR` reality.** `findmnt -no FSTYPE,SIZE /tmp; df -h /tmp` on
helium, plus the filesystem type of the CI checkout path (reflink copying works
on Btrfs/XFS, per cargo-mutants ≥26.0.0). Decides §3.4.

**M4 — the perf gate's actual numbers on helium.** After a checkout:
`just perf` (and, if it fails, `LUMIN_PERF_BLESS=1 cargo bench -p lumin --bench
perf` to read the measurements past the Ceilings). Compare all twelve against
`docs/perf-calibration.md`'s latest row: `clear 36,132; blit 17,293,274;
blend_source_over 3,628,921; blend_additive 3,340,921; line 34,936; rect
66,489; fill_rect 3,640,558; circle 48,722; fill_circle 1,580,515; text
211,379; set_pixel_grid 3,226,781; particles 5,377,605`. **Byte-identical is
the pass condition**; anything else is input to §1.6's decision, including a
*lower* number (silent false green).

**M5 — path-length sensitivity.** Run the perf gate twice on the *same* host
from two checkouts with different path lengths (e.g. `/tmp/a/lumin` vs
`/tmp/aaaaaaaaaaaaaaaaaaaa/lumin`) and diff the twelve `Ir` values. This is the
one variable that changes *only* in CI (a Forgejo runner workspace path is not
`/home/ms/projects/lumin`), and gungraun's own docs say it can move counts.
Expected to be zero because of the EntryPoint toggle — confirm rather than
assume.

**M6 — the smoke gate on the actual runner.** `just smoke` where CI will run
it. If that is a container, run it with and without `--shm-size=256m` so the
SIGBUS failure mode is *seen once, deliberately*, rather than discovered as a
mysterious `cage exited signal: 7` during a real push.

**M7 — the mutants wall clock.** `time nice -n19 ionice -c3 cargo mutants
--in-place` on helium, once idle and once during a Jellyfin transcode. Gives
the real number behind §3.2's ~18 min estimate and the real contention cost.

**M8 — the Anchoring rule on helium**, needed only if helium is to become the
anchoring authority (§1.6 option 1): run
`.scratch/v01-design/assets/fillrate-bench` and the particles wall-clock check
(`cargo test -p particles --release -- --ignored --nocapture`) and confirm the
v0.1 bar (10 000 translucent particles @ 60 fps) demonstrably passes. krypton
recorded 1.07 ms of a 16.67 ms frame; helium should land near ~1.7 ms.

---

## 5. Prior art in lumin worth updating

`.scratch/qa-pipeline/assets/deterministic-perf-gating-research.md:127` already
flagged this exact hazard and left it open:

> **CPU-dependent dispatch in the same binary.** … a Zen 5 dev box and an older
> CI runner can execute different code paths from an identical binary, giving
> small `Ir` deltas in copy-heavy kernels. (Direction and magnitude for specific
> pairs: **unverified**; treat as a few-percent effect and absorb it in
> headroom.)

§1.4 closes it: natively the concern is real (measured: up to 43% for `-ERMS`,
3.0% for `-AVX2`), but **Valgrind's hardcoded synthetic-Haswell CPUID means the
guest's glibc never sees the host's features**, so the delta between these two
hosts should be exactly zero. That note is worth amending when M1 confirms.
