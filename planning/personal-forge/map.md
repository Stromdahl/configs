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

> ⚠️ **"GitHub goes dark" needs qualifying, and this is a destination-level tension,
> not a ticket detail** (surfaced 2026-08-23 by ticket 08's premise check).
> **`github.com/stromdahl.keys` is fetched by `modules/ssh/install.sh` and
> `modules/deploy-user/install.sh`** — so the account cannot be deleted without
> breaking SSH key distribution **fleet-wide** (cf. `user_ssh_keys`: the policy is
> that every host fetches those keys). Combined with a Pages site that has no local
> copy and `lunchlund` running as a scheduled Actions service, the honest destination
> is **"GitHub stops being depended on for source hosting, CI, and tickets"** — not
> "the account is deleted". Whoever resolves 08 should say which it is; until then,
> read the migration decision as the former.

## Notes

- **Domain:** `~/.dotfiles` homelab. **helium** = bare-metal Debian NAS+services
  box, ansible-provisioned, everything in Docker behind an internal-only Traefik,
  reachable only over the NetBird mesh + LAN via split-horizon DNS
  `*.home.stromdahl.tech`. See `hosts/helium/PRD.md`.
- **Why this effort exists (the motive, in the owner's words):** *"I want it to be
  private. I want to be less dependent on bigtech — that's the whole purpose of
  this repo."* Weigh every option against that first.
- **The surveyed ground truth** (`~/projects`, 28 dirs, 2026-08-23) — **partly
  corrected by [ticket 06](issues/06-repo-curation.md); read its *Survey
  corrections* before relying on these counts:**
  - **17 of the owner's own repos have no remote at all** — `lumin`, `ghtop`,
    `taskmaster`, `msbrain`, `diy-speekers`, `not-so-smart-smartwatch`,
    `freecad-prints`, `custom-keyboard`, `pinecad`, `rust-template`, `oppen`,
    `dockerstats`, `pass-tui`, `timelog`, `keyerr` (no commits at all), + stragglers.
    **This is the actual gap** — not organization, homelessness.
  - ~~**6 on GitHub:**~~ **wrong, and wrong in the direction that matters
    (corrected 2026-08-23 from ticket 08's premise check via `gh`).** Those 6 are
    merely the ones with a *local checkout*; the account holds **49 non-fork repos**.
    This survey was built by walking `~/projects`, so it was **structurally blind to
    everything on GitHub that isn't checked out locally** — and ticket 06's curation
    inherited that blindness. Three further corrections:
    - `issue-tracker`, `specs` and `finance-track` are **PRIVATE**, not "deliberately
      public" as this map previously asserted. Only `settleup`, `lunchlund` and
      `telltaled` are public. Any reasoning built on the public-visibility loss is
      void as written.
    - **`Stromdahl.github.io`** is a live Pages site (`status: built`, pushed
      2026-08-21) with **no local clone anywhere under `~/`** — a genuinely
      single-copy artifact that exists only on GitHub, and outside 06's 20.
    - **`lunchlund` is a service, not just a repo** — a scheduled Actions cron
      publishing to Pages, with `stromdahl.github.io` hardcoded in 5 source files
      including its own last-known-good fallback in `scrape.ts`.
    Ticket 08 owns the 06 amendment and a new ticket for the public-serving gap; do
    not duplicate them here.
  - **2 upstream vendor clones** (`marlin-ender3`, `marlin-configs`) — MarlinFirmware's
    repos, **not the owner's to host**; exclude them.
  - **4 not git at all:** `playground`, `rssfeed`, `vendor`, `hermes` — **wrong.**
    `playground` is a *container of 12 more remote-less repos* (incl. `pine3d`,
    48 commits), so the homeless set was **29, not 17**; `vendor` holds 5
    upstream clones; `~/projects/hermes` is an **empty husk** (4.0K, 0 entries).
    All resolved as excluded in ticket 06.
  - **1 pointing at a dead host:** `homelab-stack.archived` → `jellyfin.stromdahl.tech`.
  - **12 stale** (untouched since June or earlier).
  - **Storage is a non-issue — do not re-open it.** Every `.git` in `~/projects`
    together is **~85 MB** (largest survivor: `lumin`, 6.7 MB). The ~40 GB of
    working trees is `target/` + `node_modules/` and never pushes.
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

- [Which repos come to the forge, and in what state?](issues/06-repo-curation.md) —
  **20 repos, one org named `projects`, two states.** `taskmaster`'s three-state
  vocabulary **collapses to `active` | `archived`**: `paused` encodes only intent,
  decays into a lie, and re-encodes by hand what git already computes. Only
  **`oppen`** and **`telltaled`** are archived, both for *supersession* (msbrain's
  ADR 0006 omits oppen; helium's MQTT metrics shipped without telltaled) — stale
  alone is not a reason. Excluded on **facts, not value judgments**: all of
  `playground/*` (disposable by design), 5 zero-commit `git init`s, 7 upstream
  clones, `rssfeed` (never `git init`'d), and `homelab-stack.archived`
  (**dropped**, not archived). Forge names **may differ from directory names** —
  `dockerstats`→`docker-tools`, `diy-speekers`→`diy-speakers` — on the map's own
  *a project is a registered entity, never a directory*; local dirs untouched.
  One org rather than flat **hedges [03](issues/03-forgejo-issue-model.md)**: if
  boards are org-scoped, it is the only namespace spanning all 20 repos.

- [Forgejo's issue model — tracker *and* wayfinder maps?](issues/03-forgejo-issue-model.md) —
  **GO-WITH-WORKAROUND** (on the v15 LTS line). **Blocking dependencies are native,
  cross-repo and API-driven** — better than GitLab-free and better than the GitHub
  adapter's own instruction. **Sub-issues do not exist and are not coming** (tracking
  issue open, all three implementations closed unmerged, absent from the dev build),
  so maps use `wayfinder:map` + `Part of #<map>` + labels — GitLab's primary shape.
  **Kanban boards are unautomatable, permanently** (no `/projects` API) — a fine
  human view, but no agent can ever read or write one. Forgejo sits **strictly
  between GitHub and GitLab-free**. Full research:
  [`assets/03-forgejo-issue-model-research.md`](assets/03-forgejo-issue-model-research.md).
  Reframes [07](issues/07-tracker-cutover.md) from a capability question to a
  convention question, and surfaces a **hybrid** option (maps stay markdown,
  execution tickets go to Forgejo) that 07 must decide rather than assume away.
  Also **resolves [06](issues/06-repo-curation.md)'s org-vs-flat hedge in favour of
  the org** — boards turn out to exist at *both* user and org level, so that was
  never the argument; the real one is that the dashboard's **label picker is only
  populated in an org context** (and it has no milestone filter at all), so a flat
  user namespace would have shipped a cross-project view with no working filter.

- [Does lumin's deep tier actually run on an i5-9400?](issues/02-lumin-deep-tier-on-helium.md) —
  **Yes, all three questions clear.** The perf gate's `Ir` **does** port: Valgrind
  masks `CPUID` to a synthetic **Haswell**, so the glibc AVX-512-vs-AVX2 `memcpy`
  dispatch that would have moved `BLIT_IR` cannot fire under callgrind (verified in
  Valgrind 3.24.0 source; krypton reports `dl_platform="haswell"` despite being an
  AVX-512 machine). The smoke gate runs **genuinely headless** —
  `WLR_BACKENDS=headless` + `WLR_RENDERER=pixman` creates no session and touches no
  DRM device, so the runner does **not** need `/dev/dri` (which is Jellyfin's).
  Deep tier **~25–40 min warm** (mutants dominating, serial and build-bound),
  60–90 min cold. **The real risk is a spec gap, not hardware:** §4.5 assumes
  exactly one machine measures `Ir` and has no rule for which host owns the
  Ceilings — now ticket [09](issues/09-lumin-definition-of-done.md)'s actual
  content. **Eight cheap measurements** are named in the asset's §4; M1 and M4 must
  run before 09 — and they must run **inside the runner's job image, not a host
  shell on helium**, or they verify the wrong glibc/valgrind and can return a false
  pass. Job image must be Debian 13 / glibc 2.41; **alpine/musl is disqualifying**.
  Full research:
  [`assets/02-lumin-deep-tier-feasibility.md`](assets/02-lumin-deep-tier-feasibility.md).

- [Throwaway Forgejo loaded with real repos and real issues](issues/05-forgejo-ui-prototype.md) —
  **Built and running at <http://localhost:3210/>** (Forgejo 15.0.7, the ticket-01
  pin; scratchpad path, good for this week not forever). 4 real repos in an org
  `projects`, 14 real `.dotfiles` issues, the vault-serve map as issue `#16` with a
  **real blocking edge**, and a hand-built **org-level** board. Corrected the API
  research in four places — most sharply: **`exclusive: true` is a silent no-op on
  `:`-separated labels** (`/` is the scope separator; the API stores the flag and
  never enforces it), so exclusivity would require renaming to
  `wayfinder/type/research`. Also: **boards are org-scoped and a user-level board
  is not offered for org-owned repos**, which makes ticket 06's "one org" hedge
  load-bearing rather than merely tidy. Notes:
  [`assets/05-prototype-notes.md`](assets/05-prototype-notes.md).

- [Runner topology for lumin's deep tier](issues/04-runner-topology.md) —
  **Recommended: `forgejo-runner` as an unprivileged systemd unit → rootless Podman
  → `docker://` labels → a purpose-built trixie image**, registered at **repository
  scope**. The key unblocking finding: **privileged docker-in-docker is Forgejo's
  *default*, not a requirement** — rootless Podman is first-party documented on
  trixie and needs "no particular permissions". Ticket 02 had already emptied the
  capability bucket, so all four backends work and this was purely a
  confinement-and-provenance choice; **containers win on reproducibility**, since a
  `host` runner would invalidate ticket 02 §4's provenance model wholesale. **Every
  default job image is bookworm/glibc 2.36 — disqualifying**, not merely suboptimal.
  Cache `target/` via a persistent bind mount on a new `ci` btrfs subvolume, **not**
  `actions/cache`. Honest bottom line: the "only my own code" argument is real for
  the workflow threat class but **does not cover `cargo build` executing third-party
  `build.rs` on 1109 mutant builds**. Full research:
  [`assets/04-runner-topology-research.md`](assets/04-runner-topology-research.md).
  Adopting it (plus the supply-chain and badge calls) is ticket
  [12](issues/12-adopt-runner-shape.md).

## Not yet specified

In-scope fog — real, but not yet sharp enough to ticket:

- **Generalizing CI beyond lumin.** `rust-template` is the natural home for a
  reusable workflow, but its shape is unknowable until lumin's actual workflow
  exists. Graduates after tickets 04 + 09.
- **New-project convention.** Where a fresh repo gets created (forge-first? local-first?),
  what it ships with (`AGENTS.md`, tracker, CI workflow), and how it gets registered.
  Blocked on knowing what the forge's creation flow looks like.
- **Repo topics as the grouping.** [Ticket 06](issues/06-repo-curation.md) chose
  one flat org and deferred categorization to Forgejo **topics** (many-to-many,
  non-breaking) rather than org partitions. Which topics, and whether any are worth
  having at all, waits until the 20 repos are actually sitting in a listing.

- **taskmaster's fate** — retired, repurposed as a forge-reading client, or
  deleted. Its two unbuilt pieces (`show` output, install story) are blocked on
  design decisions that may simply evaporate. Note its hard-won insight is worth
  keeping either way: *a project is a registered entity, never a directory.*
- ~~**CI failure notification.**~~ **Closed 2026-08-23 by ticket 04** — the
  mechanisms exist and are better than this item assumed: per-job commit statuses on
  push (but **none** for scheduled / `workflow_dispatch` runs), a first-party opt-in
  failure email, a badge endpoint, and an `if: failure()` step to ntfy or HA-MQTT.
  Picking one is now a decision in ticket [12](issues/12-adopt-runner-shape.md).
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
  only some, remains open. _Sharpened 2026-08-23 by ticket 03: the live option is a
  **hybrid** — `local` adapter for maps, Forgejo for execution tickets — now named
  explicitly in ticket [07](issues/07-tracker-cutover.md) for decision. Also note an
  adapter here is an **HTTP** cookbook, not a CLI one like the existing three,
  unless a `bin/` wrapper is written first._

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
