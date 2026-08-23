# Runner topology for lumin's deep tier

Type: research
Status: resolved
Blocked by: 01, 02

## Question

Given a Forgejo instance on helium (ticket 01) and a verdict on what lumin's deep
tier needs from its host (ticket 02): what shape does the CI runner take?

1. **Forgejo Actions runner basics** — `forgejo-runner`, how it registers, labels,
   and how workflows are addressed (`.forgejo/workflows/`). Note Forgejo Actions
   is GitHub-Actions-*shaped* but makes **no compatibility guarantee**, and its
   default runner image is a bare Debian bookworm + node — so the whole toolchain
   in ticket 02's list is the effort's own problem.
2. **Docker runner vs host runner.** Which one can satisfy the smoke gate's
   `cage`/`grim` needs (ticket 02 question 2) and the perf gate's valgrind? A
   container needing `/dev/dri` or extra capabilities pushes toward one answer;
   nothing needing them pushes toward the other. Weigh against helium's own
   `issues/010-non-root-containers` posture (CapDrop=[ALL] is the house style —
   see `project_helium_container_dns_netbird` for where that has bitten before).
3. **Getting the pinned toolchain in.** rustc 1.94.1 + 5 cargo subcommands +
   `gungraun-runner` 0.19.4 + `cage`/`grim`/`valgrind`. Options: a purpose-built
   runner image (built where? by what?), a persistent host runner provisioned by
   ansible, or install-on-every-run (slow, and `cargo install` of 5 tools is
   minutes). Also: **cargo/target caching** — a cold `cargo mutants` build on 6
   cores is the difference between tolerable and absurd.
4. **How the verdict comes back.** What a Forgejo Actions run reports, and where a
   human sees red/green without opening a terminal.

Reconcile with ticket 02's findings — if the smoke gate cannot run headless at
all, say what the runner should do with that gate rather than pretending it can.

Capture findings as `../assets/04-runner-topology-research.md`.

## Amendment (2026-08-23, from ticket 01)

**Add a fifth question, and treat it as the most important one:** where does the
runner live, and how is it confined?

Ticket 01's research found that **Forgejo's documented default runner shape is a
privileged docker-in-docker daemon**, and that Forgejo's own docs warn the runner
"performs remote code execution. That poses significant security threats for the
host and network that it operates upon." `capacity: 1` is the only documented bound
they offer.

That lands on **helium** — the box holding the Immich family photo archive and every
scanned Paperless document — and it cuts directly against this map's stated motive
(privacy and independence) and against helium's own `issues/010-non-root-containers`
posture. So this is not a deployment detail; it is a design question with real
options to weigh: privileged DinD as documented, a rootless/host runner, a dedicated
VM or LXC, a separate physical box, or accepting the risk on the grounds that the
only code it runs is the owner's own.

Note this may interact with question 2: if lumin's `cage`+`grim` smoke gate needs
`/dev/dri` or extra capabilities (ticket 02), the confinement options narrow. Report
both together rather than as separate findings.

## Answer

Resolved 2026-08-23. Full findings, with source traces and six new measurements:
[`../assets/04-runner-topology-research.md`](../assets/04-runner-topology-research.md).

**Recommended shape:** `forgejo-runner` **host binary as an unprivileged systemd
unit → rootless Podman → `docker://` labels → a purpose-built trixie image.** The
only option that keeps jobs containerised (preserving ticket 02 §4's image-digest
provenance model unchanged) while giving the runner **no root, no `docker` group,
and no privileged container**.

1. **Runner basics.** Registration is now `server.connections` — the `register`
   subcommand is **deprecated** in v13. Four scope levels exist, so **register at
   repository scope on `projects/lumin`**: free, documented, and the cheapest
   confinement available. Compatibility is *weaker* than "no guarantee" — the docs'
   own heading is **"Familiarity instead of compatibility"** ("not designed to be
   compatible"), though that is irrelevant for lumin's workflow shape. Two traps for
   the 6 GitHub migrants: `.github/workflows/` is a **fallback, not a union**, and
   bare `uses: actions/checkout` resolves to **data.forgejo.org, not GitHub**.
2. **Docker vs host vs LXC vs VM.** Ticket 02 emptied the capability bucket
   (headless smoke gate, no `/dev/dri`, no seat), so **all four backends are
   capable** and this became purely a confinement-and-provenance choice. The only
   container-specific need is `--shm-size=256m`. LXC is worse on every axis here
   (steps run as root, needs passwordless `sudo lxc-*`, no resource limits, and
   neither its docs nor its code default base is trixie).
3. **Toolchain and caching.** Bake a **purpose-built Debian 13 image**. **New
   disqualifying finding: every default job image is `bookworm`/glibc 2.36** — not
   merely suboptimal, since ticket 02 §1.3 makes glibc a live `Ir` channel against
   only 10% headroom. For caching, a real cache server *does* ship with the runner
   (`cache.enabled: true` by default), **but do not use it for `target/`** —
   tarball round-trips of a 2 GB+ tree lose to never moving the bytes. Use a
   persistent `CARGO_HOME` + `CARGO_TARGET_DIR` on a **new `ci` scratch btrfs
   subvolume** (`nodatacow`), which lands automatically **outside**
   `restic_backup_source` (it covers `appdata` only).
4. **Verdict surfacing — better than the map's fog assumed.** Actions tab; **per-job
   commit statuses** on push (verified in source — but `default: return nil` means
   **scheduled / `workflow_dispatch` runs get none**); a badge endpoint and a
   `…/runs/latest` permalink; and a **first-party opt-in failure email**
   (`enable-email-notifications: true`, present on the v15 line). Recommendation: an
   `if: failure()` step to ntfy or HA-MQTT, plus `if: success()` as a heartbeat.
   **This closes the map's "CI failure notification" fog item.** One catch worth
   deciding: `[badges] GENERATOR_URL_TEMPLATE` defaults to **img.shields.io**, so a
   status badge round-trips through a third-party CDN — straight against this map's
   motive.
5. **Confinement — privileged DinD is the *default*, not the requirement.** That is
   the finding that unblocks the map. The label grammar carries `host` and `lxc`
   schemes alongside `docker`, and **rootless Podman is first-party documented on
   Debian 13 trixie specifically**, needing *"no particular permissions"* — versus
   the Docker path's `usermod -aG docker runner`, which is root-equivalent. Six
   options costed; DinD and socket-mount rejected on `issues/010` grounds, VM and
   separate-box rejected on cost and on this map's own prior decisions.

**A one-character trap, traced rather than guessed.** Forgejo's Podman page says you
"must" put the socket path in `docker_host`, but its `docker-access/` page says a
`unix://` value means the runner *"will share the socket with the containers"*.
Reading `daemon.go::getDockerSocketPath`, the escape is **`docker_host: "-"` in the
config *plus* `Environment=DOCKER_HOST=unix://…/podman.sock` in the unit** — which
connects without mounting. **Both lines are required**; this is a hard acceptance
criterion, with a one-line job-step check as M9b.

**The strongest tiebreaker is reproducibility, not security:** choosing containers is
what keeps ticket 02 §4 true. A `host` runner would invalidate its whole preamble —
provenance would become helium's mutable apt state, and M1–M6 would run in a host
shell, which is exactly what §4 warns "verifies the wrong environment and locks the
design on a false pass."

**Security bottom line, honestly stated.** The "only my own code" mitigation is
**real** — single user, no fork PRs, no untrusted contributors, repo-scoped runner,
and Forgejo's whole "Mallory mutates a workflow" threat class presumes an attacker
who can already push. But it does **not** cover the thing that actually matters:
**`cargo build` executes third-party code by design.** Every `build.rs` and proc
macro in the winit/softbuffer graph runs at full privilege on each of 1109 mutant
builds; one typosquat or compromised release is arbitrary code execution inside
whatever confinement was chosen. Partial mitigations available in lumin today: add
**`--locked`**, and promote **`cargo deny` to its own gating first job**. Also
unmitigated: the runner is a **privilege amplifier for any Forgejo compromise** —
under DinD or socket-mount that chain ends at **root on the box holding Immich and
Paperless**; under rootless Podman it ends at an unprivileged user with two cache
dirs, and *that delta is the entire value of the recommendation*. And nothing in any
backend limits disk or network I/O on a 480 GB precious mirror with a recurring
disk2 IO fault.

So: not "accept the risk because it's my own code", and not "build a VM" — **don't
give the runner root, and keep the jobs in containers**, for the price of one ansible
role. Adopting that (plus the badge and supply-chain calls) is a decision, now
ticket **12**.
