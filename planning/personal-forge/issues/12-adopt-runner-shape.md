# Adopt the runner shape, confinement, and supply-chain posture

Type: grilling
Status: resolved

## Question

Ticket 04 was research and produced a **recommendation**. Adopting it is a decision,
and it carries a risk the owner should accept knowingly rather than inherit.
Evidence: [`../assets/04-runner-topology-research.md`](../assets/04-runner-topology-research.md).

**1. Confirm the runner shape.** `forgejo-runner` as an **unprivileged systemd unit
→ rootless Podman → `docker://` labels → purpose-built Debian 13 (trixie) image**,
registered at **repository scope on `projects/lumin`**. The alternative the docs
default to — privileged docker-in-docker — was rejected on `issues/010` grounds. The
tiebreaker for containers over a `host` runner is **reproducibility**: a host runner
would invalidate ticket 02 §4's provenance model wholesale. Two hard acceptance
criteria if adopted: `docker_host: "-"` **plus** `Environment=DOCKER_HOST=unix://…`
(both lines, or the socket gets mounted into every job), and a **trixie/glibc 2.41
image** — every default job image is bookworm/glibc 2.36, which is disqualifying
against the perf gate's 10% headroom.

**2. The supply-chain risk — the real decision here.** `cargo build` executes
third-party code by design: every `build.rs` and proc macro in the winit/softbuffer
graph runs at full privilege on each of **1109 mutant builds**. The "it's only my own
code" argument is real for the *workflow* threat class and **does not touch this
one**. Decide:
- Add **`--locked`** to the CI cargo invocations? (Cheap; changes what a dependency
  update looks like.)
- Promote **`cargo deny` to its own gating first job**, so a flagged advisory stops
  the run before 1109 builds execute untrusted `build.rs`? This is a **gate-order
  change to lumin's spec §3** ("cheap-and-likely-to-fail first" already argues for
  it) and so overlaps ticket 09 — settle which ticket owns the spec edit.
- Anything further (vendoring, an offline registry, `cargo-vet`), or is this the
  accepted floor?

**3. Resource limits.** Nothing in any backend limits **disk or network I/O**, and
the cache subvolume sits on a 480 GB precious mirror on a box with a **recurring
disk2 IO fault** (`project_helium_disk2_io_fault`). Decide whether the `ci` subvolume
gets a quota, a size cap, or nothing but a monitoring line.

**4. The badge question — small, but it cuts against the motive.**
`[badges] GENERATOR_URL_TEMPLATE` defaults to **img.shields.io**, so a status badge
round-trips through a third-party CDN. Self-host the generator, skip badges, or
accept it?

**5. Notification wiring.** Ticket 04 closed the "how does a verdict reach me" fog:
per-job commit statuses on push (but **not** for scheduled or `workflow_dispatch`
runs — `default: return nil`), a first-party opt-in failure email, and the
`if: failure()` step to ntfy or HA-MQTT the fleet already supports. Pick one, and
decide whether a `if: success()` heartbeat is wanted (a silent pipeline that has
been broken for a week looks identical to a green one).

Output: the runner spec, precise enough that building it is one ansible role, plus a
recorded risk acceptance for the supply-chain exposure.

### Riders (from asset 04's extension)

**On question 1** — two premises to confirm as part of adopting the shape:
- The **trixie image is a hard requirement**, not a preference: every default job
  image candidate is bookworm/glibc 2.36, so there is no correct off-the-shelf base.
- **Where the image is built is itself a decision, and 04 recommends helium:** a
  `Containerfile` in this repo, built on helium by an ansible task, date/content-hash
  tagged and **digest-pinned in the label**. Building locally rather than pulling
  from Forgejo's own registry avoids CI depending on the registry which depends on
  the forge being up — and **sidesteps ticket 08's registry-exposure collision
  entirely**, which is worth noting in 08 as well. Adds `zstd`, `nodejs`, and
  `git` ≥ 2.24.3 to the image's contents.

**On question 3 (resource limits) — sharper than written above.** Run **M9** first:
`cgroup.controllers` must list `cpu memory`. If rootless cgroup delegation is
**absent**, then `--cpus`/`--memory` are **silently inert** — the quota question
answers itself in the negative and `nice`/`ionice` becomes the only lever (owned by
ticket 09). Also verify helium's **I/O scheduler**: `ionice` classes only bite under
BFQ/CFQ, so on `none`/`mq-deadline` the I/O half of that lever does not exist. That
matters more than usual here, given the recurring disk2 IO fault.

---

## Resolution (in progress — 2026-08-23, Q1/Q2 settled, Q3 blocked on measurement)

### Premise corrections found before the grilling opened

1. **`--locked` is CLI-only.** Probed on cargo 1.94.1 in a throwaway crate,
   deleting `Cargo.lock` **before each run** (the first attempt was invalid — a
   prior step had regenerated the lock):
   ```
   cd /tmp/lockprobe && cargo new -q . && printf 'itoa = "1"\n' >> Cargo.toml
   for t in "--locked" "--config net.locked=true"; do rm -f Cargo.lock; cargo metadata $t --format-version 1; done
   CARGO_NET_LOCKED=true cargo metadata --format-version 1   # after rm -f Cargo.lock
   ```
   `--locked` → **fails**; `--config net.locked=true` → succeeds; `CARGO_NET_LOCKED=true`
   → succeeds. **No config key, no env var.** So `--locked` cannot be applied from the
   CI side; it is an edit to lumin's justfile recipes = a spec §2 change.
   By contrast `net.offline` **is** a real config key + env var.
2. **`cargo deny` already runs before the expensive gates** —
   `qa: preflight check deny proptest-deep smoke perf mutants coverage` — but **`check`
   runs first** and does `cargo clippy --all-targets` + `cargo test`, which already
   builds the full graph and executes every third-party `build.rs`. Promoting `deny`
   ahead of `check` would prevent 1109 *further* executions, **not the first one**.
3. **Q3's framing conflated two devices.** `disk2` is an **ext4 SAS HDD** in the
   mergerfs `/srv/media` union (`ansible/host_vars/helium/vars.yml:36`,
   `issues/003`); a `ci` cache subvolume would live on the **btrfs raid1 SSD mirror**
   at `/data/ssd` — a different filesystem on different hardware. The recurring disk2
   IO fault is **irrelevant to the cache**. What *is* relevant: two consumer
   **Kingston SUV400** TLC SSDs in raid1 receive **identical writes**, so the mirror
   buys **nothing** against correlated wear-out. `ci` belongs in
   `ssd_subvolumes_scratch` (nodatacow, no snapshots, no restic) beside
   `downloads`/`transcode`.
4. **cargo-mutants defaults its scratch build dirs to `TMPDIR`, and lumin's `target/`
   is 9.8 GB** (`du -sh ~/projects/lumin/target`). helium has **16 GB RAM** and also
   runs Immich ML + Jellyfin transcodes, so a tmpfs scratch dir is **not viable** —
   the scratch dir must be forced onto the `ci` subvolume. The RAM-vs-SSD fork
   collapses before it can be chosen, which makes SSD endurance the whole of Q3.
   Space is a non-issue (~10 GB of 480). `.cargo/mutants.toml` sets no `jobs`, so the
   run is serial with one copied tree (matches ticket 02's "serial and build-bound").
5. **Q5's premise is half wrong.** Ticket 04's rider said "ntfy or HA-MQTT the fleet
   already supports". `issues/013` states there is **no notification mechanism on the
   fleet** — no mail, no ntfy. **HA-MQTT does exist** (Mosquitto on argon,
   192.168.1.99:1883, issue 046 shipped). So the live options are HA-MQTT today,
   Forgejo's opt-in failure email (needs an SMTP path helium does not have), or
   standing up ntfy — which would also close `issues/013`, coupling two efforts.

### Q1 — runner shape: **ADOPTED as recommended.**

`forgejo-runner` as an unprivileged systemd unit → rootless Podman → `docker://`
labels → purpose-built Debian 13 (trixie) image, registered at **repository scope on
`projects/lumin`**. Both hard acceptance criteria from ticket 04 stand: `docker_host: "-"`
**plus** `Environment=DOCKER_HOST=unix://…`, and a trixie/glibc 2.41 image.

**The job image is fatter than ticket 04 recorded.** lumin's `preflight` recipe fails
the whole run without: pinned **`rustc 1.94.1`** via rustup, `cargo-machete`,
`cargo-mutants`, `cargo-deny`, `cargo-llvm-cov`, **`gungraun-runner` exactly 0.19.4**,
plus `cage`, `grim`, `valgrind ≥ 3.20` — on top of 04's `zstd`, `nodejs`,
`git ≥ 2.24.3`. Several are `cargo install`, i.e. compiled from source at image-build
time on a 6-core i5. The owner accepted the shape; **the image-build cost was raised but never
explicitly answered** — treat "a slow, rarely-rebuilt image is fine" as this
ticket's assumption, not the owner's word.

**Open premise (needs helium):** rootless Podman requires `/etc/subuid`,
`/etc/subgid` ranges and `newuidmap`. **Unverified — nobody in 04 or 12 checked.** If
absent, the shape acquires an unscoped ansible task.

### Q2 — supply-chain posture: **`--locked` yes, everything else declined.**

The question "is a malicious `build.rs` really a big worry?" was tested against
numbers, not posture. lumin resolves **246 packages**; filtered to
`x86_64-unknown-linux-gnu` (`cargo metadata --filter-platform`), what actually executes
at build time is **27 third-party build scripts + 9 proc macros** — the `windows_*`,
`objc2`, `jni*`, `wasm-bindgen`, `orbclient`, `android-activity` entries never build
here. Of those 27, nearly all are top-of-ecosystem, heavily-audited crates (`serde`,
`libc`, `quote`, `proc-macro2`, `rustix`, `thiserror`, `getrandom`, `num-traits`,
`zerocopy`, `crc32fast`, `ahash`, `winit`, `wayland-*`). The obscure tail a typosquat
would target is **five crates**: `zmij`, `bincode-next`, `drm-fourcc`, `tiny-xlib`,
and lumin's own harness `gungraun`.

**The "1109 mutant builds" figure — repeated from ticket 04 — is rhetorically loud and
analytically empty.** It is 1109 executions of the *same already-resolved* lockfile.
Running code 1109 times instead of once does not multiply the probability of
compromise; it changes wall-clock, not risk.

What moving CI to helium genuinely changes is **blast radius, not likelihood** — and
**Q1 already bought that mitigation**: under rootless Podman the worst case is an
unprivileged user with two cache dirs, not root beside the Immich archive.

Decided:
- **`--locked`: YES — adopted on reproducibility grounds, explicitly not security.**
  The real argument is the perf gate: without it CI can silently resolve a different
  dependency set than the laptop, and a dependency bump moving `BLIT_IR` would read
  as a regression in lumin's own code against the committed Ceilings. Accepted cost:
  every dependency update now needs a deliberate `cargo update` before CI goes green.
  **Ownership settled: ticket [09](09-lumin-definition-of-done.md) owns the justfile /
  spec §2 edit; this ticket only records the requirement.**
- **Gate reorder (`deny` before `check`): NO.** Not worth a spec §3 gate-order change
  — it cannot prevent the first execution (finding 2), and `cargo deny` only catches
  *published* advisories, so it would have missed a fresh typosquat anyway.
- **Offline builds (`net.offline` + prefetched registry): NO.** The strongest lever on
  paper and the only one touching the actual mechanism, but it needs unverified
  `unshare -n` work (the build steps share the job network with `actions/checkout`
  and the cache restore) and the likelihood does not justify it.
- **Vendoring / offline registry / `cargo-vet`: NO.** Ongoing effort, single
  maintainer.
- **Residual exposure: knowingly accepted**, on the reasoning above — thin obscure
  tail, blast radius already confined by Q1.

### Q3, Q4, Q5 — still open in this session.

### Q3 premise measurements on helium (2026-08-23, over LAN `192.168.1.191`)

Commands were run as `ms` over ssh; helium was reached at **`192.168.1.191`**
(`helium.home.stromdahl.tech` also resolves) — the **NetBird daemon on krypton was
`NeedsLogin`, so the mesh IP `100.65.22.72` timed out**. Re-run with
`ssh 192.168.1.191 '<cmd>'`.

**M9 — PARTIALLY run.** Asset 04's M9 has four parts; only the `cgroup.controllers`
one could run, because **podman is not installed** — `podman --version`,
`systemctl --user status podman.socket` and the `debian:trixie` glibc probe remain
**unmeasured**, including whether podman on trixie is **≥ 5.3** (04's IPv6 caveat).
**Cgroup delegation: PRESENT, but partial.** cgroup v2 (`cgroup2fs`), systemd 257.
```
cat /sys/fs/cgroup/user.slice/user-1000.slice/cgroup.controllers   -> cpu memory pids
cat /sys/fs/cgroup/cgroup.controllers                              -> cpuset cpu io memory hugetlb pids rdma misc
```
So `--cpus`/`--memory` are **real, not silently inert** — M9's pessimistic branch does
**not** fire, and `CPUQuota=`/`MemoryMax=`/`CPUWeight=` are usable levers. **But `io`
is delegated to root only, never to a user slice** — so a rootless runner in a *user*
slice has **no I/O controller at all**. `ms` already has
`/var/lib/systemd/linger` enabled.

**I/O scheduler — the pessimistic branch DOES fire for `ionice`.**
```
nvme0n1 (rot=0): [none] mq-deadline      sda..sdd (rot=1): none [mq-deadline]
sde,sdf (rot=0): none [mq-deadline]
```
Nothing is on BFQ/CFQ, so **`ionice` classes are a no-op on every device.** Combined
with `io` not being delegated, a user-slice rootless runner has **zero I/O levers**.
The only way to get one is to run the runner as a **system** unit (system.slice has
the `io` controller), where systemd's `IOWriteBandwidthMax=` works — `io.max`
throttling is scheduler-independent, unlike `IOWeight=`/`io.weight` which needs BFQ.
**This is a live interaction with Q1's "unprivileged systemd unit": read it as a
*system* unit with `User=`, not `systemd --user` + linger, or the I/O lever is
unavailable by construction.**

**Rootless Podman prerequisites — Q1's open premise: NOT satisfied.**
```
/etc/subuid:ms:100000:65536      /etc/subgid:ms:100000:65536
podman / newuidmap / newgidmap / slirp4netns / fuse-overlayfs / crun -> ALL MISSING
runc -> /usr/bin/runc     docker -> /usr/bin/docker   (dpkg: none of the four installed)
```
So the shape needs an ansible task that does **not** exist yet: install
`podman uidmap slirp4netns fuse-overlayfs`, and provision a **subuid/subgid range for
the dedicated runner user** (only `ms` has one today). Not a blocker — but it is real
scope that ticket 04 assumed away with "needs no particular permissions".

**Storage geometry — Q3's framing was wrong in a second way.** There is a **third
tier** neither ticket 04 nor 12 mentions:

| Device | What | Size | Free | Health |
|---|---|---|---|---|
| `nvme0n1` Samsung 970 EVO Plus 250GB | **boot/root** `/` ext4 (+`/boot/efi`, 12G swap) | 233 G | **146 G** | **0% used**, 2.26 TB written, 1632 h |
| `sde`+`sdf` 2× Kingston SUV400 480G | btrfs **raid1** precious+scratch pool | 448 G usable | **332 G** | 93% / 96% life left; 12.4 / 15.2 TB written |
| `sda`..`sdd` 4× 10.9T SAS | ext4, mergerfs `/srv/media` + 2 parity | — | — | `sdb` = the **disk2** IO-fault drive |

`/data/ssd` itself is **not a mountpoint** — only the six per-subvol mounts
(`@appdata @immich @paperless @downloads @transcode @vault`) are mounted, all
`noatime ssd discard=async space_cache=v2`. **btrfs quotas are NOT enabled**
(`btrfs qgroup show` → "quotas not enabled"), so a qgroup cap is an *enable* action
with btrfs's known qgroup overhead, not a free flag.

**Endurance arithmetic.** Kingston UV400 480G is rated ~200 TBW. `sde` reports 93%
life left after 12.4 TB, `sdf` 96% after 15.2 TB (the normalized attribute is coarse —
those imply 177 TB and 380 TB total, so treat ~200 TBW as the number). Roughly
**~180 TB of write budget left per Kingston** — and in raid1 **both members receive
identical writes**, so the mirror buys nothing against correlated wear-out. The NVMe
is rated ~150 TBW and sits at **0% used**.

**Write volume — measured, not estimated.** One full `cargo mutants` run on krypton:
**52.56 GiB written**, 653 s, 1109 mutants (740 caught / 369 unviable), rc=0.
Method (`assets/`-worthy but small enough to inline) — `/proc/diskstats` field 10
sector-delta around the run, with **`TMPDIR` forced onto a real disk** because
krypton's `/tmp` is tmpfs and the default would have measured ~0 and been
non-transferable to helium:
```
r() { awk -v d=nvme0n1 '$3==d {print $10}' /proc/diskstats; }   # sectors written
before=$(r); TMPDIR=/home/ms/.cache/mutants-measure cargo mutants; after=$(r)
echo "GiB: $(( (after-before) * 512 / 1073741824 ))"
```
Script kept at `assets/12-measure-mutants-io.sh`.

### Q3 — resource limits: **cache moves to the NVMe; endurance concern withdrawn.**

**The endurance worry was wrong and is withdrawn.** **Measured: 52.56 GiB for the
mutants gate; the other eight gates are unmeasured** (`cargo llvm-cov` does a full
instrumented rebuild, so it is not negligible). Even taking mutants alone against ~180
TB remaining per Kingston that is ~3,400 runs, and the conclusion has roughly 40×
headroom — a decade at any plausible push rate, whatever the other gates add. The NVMe's ~150 TBW is the same order. Correlated
raid1 wear-out is **not** a real constraint and should not be re-raised.

**What the measurement actually exposes is I/O contention.** 52.56 GiB in 11 min is
~82 MB/s sustained; on helium's 6 threads the run stretches to 25–40 min, so it is
~80 MB/s of sustained write for over half an hour. On the Kingston **raid1** that is
~160 MB/s of SATA traffic across two slow consumer TLC drives that also carry Immich,
Paperless, Docker appdata and Jellyfin's transcode scratch — and SUV400s degrade
badly under sustained write once the SLC cache fills. Crucially there is **no lever
to soften it**: `io` is not delegated to user slices and `ionice` is a no-op on
`mq-deadline`.

**Decided (owner, 2026-08-23): the `ci` cache lives on the NVMe root disk, NOT a new
subvolume on the SSD mirror.** Chosen on **I/O contention**, explicitly not on
endurance. 146 GB free against a ~10 GB `target/` plus a ~10–20 GB scratch peak; 80
MB/s is trivial for a 970 EVO Plus at 0% wear sharing only with the OS. This also
means **no `ci` entry is added to `ssd_subvolumes_scratch`** and btrfs qgroups stay
disabled.

Consequence to carry into the runner spec: the cache path is on `/`, so **cargo-mutants'
`TMPDIR` must be pointed at it explicitly** — the default would otherwise land the
scratch tree wherever `TMPDIR` points, and on a 16 GB box a tmpfs default is fatal
(finding 4).

**Still open in Q3:** the space guard. Filling `/` takes the whole box down, so this
needs a mechanism rather than trust.

**Space guard — decided: fail-early check + mandatory cleanup, with the HA disk-free
sensor as the safety net. No quota.**

The failure mode being defended against is severe: a full `/` on helium does not
degrade gracefully — Docker, Traefik, Immich, Paperless and the journal all stop. That
is a **worse blast radius than the mirror would have suffered**, and is the honest
price of the NVMe trade.

- **Adopted:** a first workflow step that refuses to run when free space on `/` is
  below a floor (~40 GB), plus a cleanup step removing the scratch tree **on exit,
  including on failure**, plus a **pre-job sweep of stale scratch dirs** — cleanup-on-exit
  does not run for a SIGKILLed job, and orphaned scratch trees are the actual
  slow-accumulation path. Fails the job rather than the box; no privileged config.
- **Adopted as safety net:** a disk-free sensor on `/` published over the existing
  MQTT → Home Assistant path (issue 046). Advisory only.
- **Rejected: ext4 project quota.** It is the only option making overrun *impossible*
  rather than *noticed*, but it needs `prjquota` on `/` via `tune2fs` **plus a reboot
  of helium**, and an unwritten ansible task. The realistic failure is slow
  accumulation across runs — which cleanup addresses — not a single runaway write.
  **Revisit if CI ever serves several projects on this box.**

**CPU/memory levers (available, per M9):** `CPUWeight=`/`CPUQuota=`/`MemoryMax=` are
real. Picking values is the `nice`-equivalent question that ticket 04 assigned to
ticket [09](09-lumin-definition-of-done.md); this ticket only records that the
mechanism exists and that **`ionice` and cgroup `io` do not**.

### Q4 — badges: **skip entirely.**

`[badges] GENERATOR_URL_TEMPLATE` defaults to **img.shields.io**, so a badge
round-trips a third-party CDN on every render, leaking the repo name and the owner's
reading pattern — a small but permanent contradiction of the map's stated motive
(*"less dependent on bigtech"*). Against that it buys nothing: the forge is
**mesh-only**, so the only viewer is the owner, who has the run list one click away in
the same UI. Badges earn their place where strangers need an at-a-glance signal; there
are no strangers on this instance. Self-hosting a generator is a whole extra service
to deploy, patch and back up for a coloured rectangle.

**Decided: do not set `GENERATOR_URL_TEMPLATE`, do not self-host a generator, no badge
in any README.** If an at-a-glance signal is wanted later, it belongs on the Home
Assistant dashboard the owner already opens (Q5's territory) as a real status tile.

### Q5 — notification wiring: **deferred, not decided here.** (owner: *"we don't need this now"*)

Handed in full to **`issues/013`**, which already owns "there is no notification
mechanism on the fleet". Nothing in the runner spec depends on it: per-job **commit
statuses on push** come for free in the Forgejo UI, and the notification is purely
additive — one `if: failure()` step publishing to whatever channel `013` eventually
picks.

Two facts recorded so `013` (or a future revisit) does not have to re-derive them:
- **Ticket 04's rider was half wrong.** There is **no ntfy and no mail** on the fleet.
  What exists is **HA-MQTT** — Mosquitto on argon at `192.168.1.99:1883`, shipped in
  issue 046, already carrying helium's container and SMART metrics into Home Assistant.
  That is the zero-new-service option if/when this is wanted.
- **Commit statuses only fire on push.** For scheduled and `workflow_dispatch` runs the
  code path is `default: return nil`. So *if a nightly run is ever added*, the in-UI
  signal is silently absent and an explicit `if: failure()` step becomes necessary
  rather than optional. Today's push-only trigger does not have this gap.
- The **success-heartbeat** question (a pipeline broken for a week looks identical to a
  green one) is **unasked and unanswered** — it goes with the channel.

---

## Resolution — the runner spec

**Status: resolved 2026-08-23. Q1–Q4 decided; Q5 deferred to `issues/013`.**

### One correction to my own reasoning above, recorded because it changes a premise

Earlier in this resolution I argued a **system** unit would give access to the `io`
controller (system.slice has it; user slices do not). That is true of the *runner
process* but **irrelevant to the jobs**: with rootless Podman the job containers are
launched by the user's podman and land in **`user-<uid>.slice`**, which has only
`cpu memory pids` delegated. So **no I/O lever was ever available for the jobs** — the
"no I/O quota" outcome in Q3 was not a choice but a constraint. The system-unit
recommendation below therefore rests on operational simplicity, not on `io`.

### The spec

1. **Runner process** — `forgejo-runner` running **unprivileged as a dedicated
   `forgejo-runner` user**, per ticket 04. **OPEN implementation detail: system unit
   with `User=` vs. `systemd --user` unit.** Ticket 04 does not disambiguate it (it says
   only "unprivileged systemd unit"), the owner was not asked, and the argument I
   originally used for a system unit — access to the `io` controller — **I withdrew as
   inapplicable to jobs**. So this is deliberately left open rather than invented here.
   Whoever closes it must handle one hazard: a **system** unit has no ordering dependency
   on `user@<uid>.service`, so `/run/user/<uid>/podman/podman.sock` may not exist when it
   starts — it needs `After=`/retry. A `systemd --user` unit sidesteps that and matches
   the linger pattern the docs already require for the socket.
2. **Container backend** — **rootless Podman**, `docker://` labels. The podman socket
   comes from the documented pattern: `podman.socket` as a **`systemd --user` unit for
   `forgejo-runner` with `loginctl enable-linger`**, and the runner unit points at it:
   `Environment=DOCKER_HOST=unix:///run/user/<uid>/podman/podman.sock`.
   **Both ticket-04 acceptance lines are mandatory:** `docker_host: "-"` in the runner
   config **and** the `Environment=DOCKER_HOST=…` line — either alone leaves the socket
   mounted into every job.
3. **Prerequisites ansible must provision (none present today — verified):**
   `apt: podman uidmap slirp4netns fuse-overlayfs`; a **subuid/subgid range for
   `forgejo-runner`** that does not collide with `ms:100000:65536` (e.g. `200000:65536`);
   `loginctl enable-linger forgejo-runner`. `runc` and `docker` are already installed;
   docker is **not** used by the runner.
4. **Registration** — **repository scope on `projects/lumin`**, not instance-wide.
5. **Job image** — purpose-built **Debian 13 (trixie), glibc 2.41**, from a
   `Containerfile` in this repo, **built on helium** by an ansible task, tagged by
   date/content-hash and **digest-pinned in the label**. Building locally (not pulling
   from Forgejo's own registry) avoids CI depending on the registry that depends on the
   forge, and sidesteps ticket 08's registry-exposure question entirely. Every default
   job image is bookworm/glibc 2.36 — **disqualifying** against the perf gate's 10%
   headroom; alpine/musl likewise.
   **Contents** (union of ticket 02, ticket 04, and lumin's `preflight` recipe):
   `rustup` + pinned **rustc 1.94.1**; `cargo-machete`, `cargo-mutants`, `cargo-deny`,
   `cargo-llvm-cov`, **`gungraun-runner` exactly 0.19.4**; `cage`, `grim`,
   `valgrind ≥ 3.20`; `zstd` (or cache restores silently no-op), `nodejs` (or
   `actions/checkout` breaks), `git ≥ 2.24.3`. Several are `cargo install`, i.e.
   compiled from source at image-build time on a 6-core i5 — **a slow, rarely-rebuilt
   image is accepted**.
6. **Cache** — a persistent bind mount on the **NVMe root disk** (not `actions/cache`,
   not a new SSD-mirror subvolume). **`TMPDIR` must be pointed explicitly at it**, or
   cargo-mutants' default scratch location applies — fatal on a 16 GB box if that is
   tmpfs, given a 9.8 GB `target/`.
7. **Space guard** — a first workflow step failing the run when free space on `/` is
   below ~40 GB, a cleanup step removing the scratch tree **on exit, including on
   failure**, and a **pre-job sweep of stale scratch dirs** (cleanup-on-exit misses a
   SIGKILLed job). Plus an advisory disk-free sensor on `/` over the existing MQTT → HA path.
   **No ext4 project quota** (would need `prjquota` + `tune2fs` + a reboot).
8. **Resource limits** — `CPUWeight=`/`CPUQuota=`/`MemoryMax=` are **real** (M9: `cpu
   memory pids` delegated). **`ionice` and cgroup `io` are unavailable** — every device
   is `mq-deadline`, and `io` is never delegated to a user slice. Choosing the actual
   values is ticket [09](09-lumin-definition-of-done.md)'s `nice` question.
9. **`--locked`** on the cargo invocations, for **reproducibility** (the perf gate must
   not compare `Ir` across differing dependency sets), explicitly **not** security.
   CLI-only, so it is a justfile edit = lumin spec §2 change → **owned by ticket 09**.
10. **No badges.** No gate reorder. No offline builds. No vendoring/`cargo-vet`.

### Recorded risk acceptance

**Third-party build-script execution is knowingly accepted.** 27 third-party build
scripts + 9 proc macros execute on this platform, nearly all top-of-ecosystem audited
crates; the squattable tail is five (`zmij`, `bincode-next`, `drm-fourcc`, `tiny-xlib`,
`gungraun`). The "1109 builds" framing is analytically empty — same lockfile, 1109
times. Moving CI to helium changes **blast radius, not likelihood**, and rootless
Podman already confines that to an unprivileged user with two cache dirs rather than
root beside the Immich archive.

### Riders out of this ticket

- **Ticket [09](09-lumin-definition-of-done.md)** inherits two spec edits: adding
  `--locked` to the justfile recipes (spec §2), and choosing `CPUWeight`/`MemoryMax`
  values (the `nice` question, now with cgroup delegation confirmed present and
  `ionice`/`io` confirmed unavailable).
- **`issues/013`** inherits Q5 whole, plus the two facts above.
- **New execution scope, not a decision:** the ansible task for
  podman/uidmap/slirp4netns/fuse-overlayfs + a runner-user subuid range + linger.
  Graduates with the build issues.

---

## Rider (2026-08-24): the OPEN unit type is now [ticket 14](14-runner-unit-type.md)

§The spec item 1's *"OPEN implementation detail: system unit with `User=` vs.
`systemd --user` unit"* was a **decision that fell between tickets 04 and 12**, not one
that was shelved — and [ticket 09](09-lumin-definition-of-done.md) parked its systemd
resource values behind it. It is now [ticket 14](14-runner-unit-type.md), which carries
the established facts (the dead `io` argument, the `user@<uid>.service` ordering hazard,
the already-fixed `systemd --user` socket) so nothing is re-researched. Item 1 stops
saying OPEN when 14 resolves.
