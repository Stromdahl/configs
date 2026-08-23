# Map: Private self-hosted forge for personal projects (Forgejo on helium)

`wayfinder:map` — child tickets live in `planning/personal-forge/issues/`.

## Destination

A **locked spec** for a private, self-hosted **Forgejo instance on helium** that
becomes three things at once:

1. the **canonical home** for every personal repo in `~/projects` (GitHub goes
   dark — full migration, not a mirror),
2. the **ticket tracker with a web UI the owner actually opens** — replacing the
   never-adopted `taskmaster` CLI as the cross-project view,
3. the **CI host** that runs lumin's **deep QA tier** asynchronously, so a
   1109-mutant run stops pinning the laptop.

Plus the decisions needed to migrate off GitHub and to restore every repo onto a
fresh machine (`forge sync`).

## Notes

- **Domain:** `~/.dotfiles` homelab. **helium** = bare-metal Debian NAS+services
  box, ansible-provisioned, everything in Docker behind an internal-only Traefik,
  reachable only over the NetBird mesh + LAN via split-horizon DNS
  `*.home.stromdahl.tech`. See `hosts/helium/PRD.md`.
- **Why this effort exists (the motive, in the owner's words):** *"I want it to be
  private. I want to be less dependent on bigtech — that's the whole purpose of
  this repo."* Weigh every option against that first.
- **The surveyed ground truth** (`~/projects`, 28 dirs, 2026-08-23):
  - **17 of the owner's own repos have no remote at all** — `lumin`, `ghtop`,
    `taskmaster`, `msbrain`, `diy-speekers`, `not-so-smart-smartwatch`,
    `freecad-prints`, `custom-keyboard`, `pinecad`, `rust-template`, `oppen`,
    `dockerstats`, `pass-tui`, `timelog`, `keyerr` (no commits at all), + stragglers.
    **This is the actual gap** — not organization, homelessness.
  - **6 on GitHub:** `settleup`, `telltaled`, `lunchlund`, `specs`,
    `issue-tracker`, `finance-track`.
  - **2 upstream vendor clones** (`marlin-ender3`, `marlin-configs`) — MarlinFirmware's
    repos, **not the owner's to host**; exclude them.
  - **4 not git at all:** `playground`, `rssfeed`, `vendor`, `hermes`.
  - **1 pointing at a dead host:** `homelab-stack.archived` → `jellyfin.stromdahl.tech`.
  - **12 stale** (untouched since June or earlier).
- **Hardware reality — there is no faster CI available:**

  | Box | CPU | RAM | Notes |
  |---|---|---|---|
  | krypton (laptop) | Ryzen AI 7 350, **16 threads** | 30 GB | where QA runs today |
  | helium (NAS) | i5-9400, **6C/6T** | 16 GB | also Jellyfin transcodes, Immich ML, Paperless OCR, *arr, nightly snapraid |
  | radon (VPS) | Hostinger, small | — | public-facing, **standalone — not on the mesh** |

  helium is **strictly weaker than the laptop**. Accepted: the goal is laptop
  responsiveness, not wall-clock. Do not re-open this as a performance problem.
- **lumin's QA cost, measured not guessed** (`lumin/mutants.out/outcomes.json`):
  **1109 mutants / 677 s of phase time** — and that is *one* of nine gates. Others:
  `PROPTEST_CASES=10000`, a valgrind/callgrind perf gate, a `cage`+`grim` headless
  Wayland smoke gate, `cargo llvm-cov`. Contract in
  `~/projects/lumin/.scratch/qa-pipeline/spec.md`; entry point `~/projects/lumin/justfile`.
- **helium hazards that this effort lands on — read before building:**
  - `project_ufw_breaks_iptables_persistent` — helium's full nas play is
    non-idempotent; **use scoped tags** (`--tags compose`), never a full play.
  - `project_helium_disk2_io_fault` — recurring SAS-cable IO fault on disk2.
  - ~~`project_helium_traefik_acme_restart` — first-cert DNS-01 needs a
    `docker restart traefik`; single-file bind mounts pin the inode.~~
    **Struck 2026-08-23 for this service (ticket 01):** the inode trap needs a
    config bind mount and Forgejo has none (label-based docker router), and the
    DNS-01 stall was already fixed in the compose template by issue 044's
    public-resolver flags. Still live for *other* services.
  - `project_helium_container_dns_netbird` — container DNS is fixed via a
    daemon-DNS pin; do not cite the old breakage.
- **Skills:** `/grilling` + `/domain-modeling` for grilling tickets; `/research`
  subagents for research tickets; `/prototype` where code is involved.
- **Plan, don't do:** this map produces **decisions**. Execution graduates into
  real `issues/NNN` once the way is clear.

## Decisions so far

<!-- one line per closed ticket: gist + link -->

_Charted 2026-08-23. Eight scoping decisions were settled in the charting grilling
itself and are recorded here as the map's premises — they are **not** open tickets
and must not be re-litigated:_

- **One effort, not three.** "Organize projects", "CI offload", and "ticket
  tracker" collapse into one, because CI is unbuildable until the repos have a
  home, and once a forge exists its issue tracker overlaps the tracking ask.
- **Self-hosted and private, not GitHub.** Rejected the otherwise-attractive
  "GitHub remote + self-hosted runner" hybrid (which would have been free and
  needed no new stateful service) on the stated motive above.
- **CI is asynchronous; the win is laptop load, not speed.** helium being loaded
  sometimes is explicitly acceptable — including contending with Jellyfin.
- **Forgejo Issues become the tracker; taskmaster loses.** The decisive evidence
  is the owner's own: taskmaster is "complete and in use" per its README but was
  *never actually adopted*. A build-from-source CLI loses to nothing at all; a UI
  already open in a tab is the only shape that survives contact with use.
- **"Organize" = hosting/backup + curation (alive/parked/dead) + a `forge sync`
  restore command.** Filesystem restructuring is out of scope.
- **Full migration off GitHub** (GitHub goes dark). Push-mirroring the public few
  back to GitHub was offered and deferred to a *possible follow-up*, not this route.
- **Two copies is enough** — the forge plus git's inherently distributed working
  clones on krypton. No offsite; see Out of scope.
- **CI runs the deep tier only, on push; lumin only.** The existing
  fast/deep tier boundary ("seconds and offline" vs "minutes and heavy") *is* the
  local/remote boundary. Generalizing to every project is fog.

- [Forgejo's deployment shape on helium](issues/01-forgejo-deployment-shape.md) —
  **Forgejo confirmed over Gitea**; pin **`:15-rootless`** (LTS, ~11 months support
  vs ~9 weeks for `:16`). Config is **entirely env-var driven** (`FORGEJO__SECTION__KEY`
  + a `__FILE` variant), so **no config bind mount at all** — it drops into
  `stack.env.j2` like any other service. helium **keeps sshd on 22**. The registry
  does anonymous OCI pull **but is same-origin with the web UI and cannot be scoped
  to `/v2/`** — which turns ticket 08 into a forced choice between four exits.
  Forgejo **publishes no resource requirements at all**. Full research:
  [`assets/01-forgejo-deployment-research.md`](assets/01-forgejo-deployment-research.md).
  Spawned ticket [11](issues/11-persistence-backup-and-pins.md) (persistence/backup
  decisions) and amendments to [04](issues/04-runner-topology.md),
  [08](issues/08-github-exit.md), [10](issues/10-forge-sync-contract.md).

## Not yet specified

In-scope fog — real, but not yet sharp enough to ticket:

- **Generalizing CI beyond lumin.** `rust-template` is the natural home for a
  reusable workflow, but its shape is unknowable until lumin's actual workflow
  exists. Graduates after tickets 04 + 09.
- **New-project convention.** Where a fresh repo gets created (forge-first? local-first?),
  what it ships with (`AGENTS.md`, tracker, CI workflow), and how it gets registered.
  Blocked on knowing what the forge's creation flow looks like.
- **taskmaster's fate** — retired, repurposed as a forge-reading client, or
  deleted. Its two unbuilt pieces (`show` output, install story) are blocked on
  design decisions that may simply evaporate. Note its hard-won insight is worth
  keeping either way: *a project is a registered entity, never a directory.*
- **CI failure notification.** A verdict nobody sees is not a verdict. Options
  already in the fleet: HA (MQTT), homepage, ntfy, plain email.
- _(Graduated 2026-08-23 into ticket [04](issues/04-runner-topology.md): **where the
  CI runner lives and how it is confined.** Ticket 01 found Forgejo's documented
  default runner shape is a **privileged docker-in-docker daemon**, with Forgejo's own
  docs warning it "performs remote code execution… significant security threats for
  the host" — on the box holding the Immich photo archive and every Paperless
  document.)_
- **Secrets in CI.** How Forgejo Actions secrets interact with the existing
  sops+age story, and whether any lumin gate needs one (probably not today).
- **Forgejo maintenance** — DB migrations and what breaks while it's down (the
  owner can still *work*, since git is distributed, but CI and tickets stop).
  _Partly graduated 2026-08-23: the upgrade-cadence half is now a decision in
  ticket [11](issues/11-persistence-backup-and-pins.md) (LTS pin vs tracking stable)._
- **How far the agent toolchain moves.** A `issue-tracker-forgejo.md` adapter is
  implied by the tracker decision, but whether *every* matt-pocock skill
  (`/to-tickets`, `/triage`, `/implement`, `/pickup`, `/wayfinder`) moves over, or
  only some, depends on ticket 03's findings.

## Out of scope

- **Restructuring `~/projects`' filesystem layout** — grouping, cleaning out the
  non-git dirs, reshuffling directories. Fixes nothing the forge doesn't fix, and
  cuts against taskmaster's own insight that a project is not a directory.
  `~/projects/<name>` is a fine layout.
- **Offsite backup** — belongs to helium's deliberately deferred restic offsite
  slice (`issues/016`, `issues/026`), not here. Decided: two copies (forge +
  working clones) is enough for code.
- **GitHub push-mirroring** (the "Forgejo canonical, GitHub as a read-only shop
  window" option) — offered, deferred as a *possible follow-up effort*. If the
  loss of public visibility for `issue-tracker`/`specs` turns out to sting, it
  returns as a fresh effort, not a resumption.
- **Acquiring dedicated build hardware / paid CI minutes** — ruled out when the
  goal was settled as laptop load rather than wall-clock.
- **Work / Sensative projects** (`~/yggio`, the 29 worktrees, the yggio GitHub
  tracker). This effort is personal projects only; see the separate
  `~/projects/specs/.scratch/work-tracking/` map.
