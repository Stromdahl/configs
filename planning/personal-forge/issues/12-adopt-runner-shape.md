# Adopt the runner shape, confinement, and supply-chain posture

Type: grilling
Status: open

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
