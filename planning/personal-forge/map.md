# Map: Private self-hosted forge for personal projects (Forgejo on helium)

`wayfinder:map` — child tickets live in `planning/personal-forge/issues/`.

## Destination

A **locked spec** for a private, self-hosted **Forgejo instance on helium** that
becomes three things at once:

1. the **canonical home** for the 20 curated personal repos (GitHub is left
   untouched — see the resolution note below; four repos are carve-outs),
2. the **ticket tracker with a web UI the owner actually opens** — replacing the
   never-adopted `taskmaster` CLI as the cross-project view,
3. the **CI host** that runs lumin's **deep QA tier** asynchronously, so a
   1109-mutant run stops pinning the laptop.

Plus the decisions needed to migrate off GitHub. ~~and to restore every repo onto a
fresh machine (`forge sync`)~~ — **the restore command was shelved 2026-08-23 by
[ticket 10](issues/10-forge-sync-contract.md)** (*"we can shelf this until we need
it"*), so it is **out of scope**: this effort delivers hosting, curation, the tracker
and CI, but no reconcile/restore tool. Note the one-shot **migration** script that
first creates and pushes the 20 repos is unaffected — that belongs to
[ticket 07](issues/07-tracker-cutover.md), not to `forge sync`.

> ✅ **Resolved 2026-08-23 by [ticket 08](issues/08-github-exit.md) — and resolved
> *weaker* than this map was written.** The owner's decision: **GitHub is not
> touched. Left as is.** So "GitHub goes dark" is **false as written**. What this map
> actually delivers is:
>
> > **personal source hosting, ticket tracking, and lumin's deep CI tier move to
> > Forgejo. GitHub retains four running services and an untouched archive.**
>
> The migration boundary is **"does GitHub *execute* something for me"**, not "is it
> public". Four carve-outs stay GitHub-native: **`configs` (= `~/.dotfiles`)** —
> `bootstrap.sh` + `github.com/stromdahl.keys`, which must work before the mesh
> exists; **`settleup`** — Actions → GHCR, pulled by off-mesh radon; **`lunchlund`**
> — scheduled Actions cron → Pages; **`Stromdahl.github.io`** — the Pages site.
> Everything else live moves to Forgejo and its GitHub copy is abandoned in place,
> which is also the rollback. Public visibility is **not** lost — `issue-tracker` and
> `specs` stay as readable as today. Accepted cost against the motive: a permanent
> load-bearing GitHub dependency at first boot, plus a public registry in radon's
> serving path.

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
    **All three are closed by [ticket 08](issues/08-github-exit.md)** (GitHub
    untouched): the account in fact holds **78** non-fork repos with only **6**
    locally checked out, and all 71 local-less repos are now out of scope. The 06
    amendment is written; the public-serving gap needed no ticket — `lunchlund` and
    `Stromdahl.github.io` are carve-outs that simply keep running.
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
- **Migration ordering — read before graduating any execution issue.**
  [Ticket 07](issues/07-tracker-cutover.md) decided the tracker moves to Forgejo and
  the 56 markdown files are **deleted**, which removes this map's own graduation
  target and would strand the migration's execution issues with nowhere to live.
  This map is also still live (09/10/11 open), so it has to move mid-flight. The
  order is therefore fixed: **(1)** Forgejo stands up on helium; **(2)** this map's
  remaining tickets resolve *in markdown, where they are*; **(3)** the migration
  script runs; **(4)** the markdown deletion and this map's own move happen **last**,
  from the forge. Do not delete `issues/` before step 4.

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
- **"Organize" = hosting/backup + curation (alive/parked/dead)** ~~+ a `forge sync`
  restore command~~. Filesystem restructuring is out of scope.
  _Narrowed 2026-08-23 by [ticket 10](issues/10-forge-sync-contract.md): the restore
  command is shelved until wanted, so "organize" is hosting + curation only._
- ~~**Full migration off GitHub** (GitHub goes dark).~~ **Superseded 2026-08-23 by
  [ticket 08](issues/08-github-exit.md):** GitHub is **not touched, left as is**, and
  four repos are GitHub-native carve-outs. Read this premise as *"Forgejo becomes
  canonical for the 20 curated repos, tickets, and lumin's deep CI"* — see the ✅
  block under Destination.
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
  _Amended 2026-08-23 by [ticket 07](issues/07-tracker-cutover.md): the board is now
  **decoration** and nothing may depend on it, so the board-scoping argument for the
  org is **dead** — do not cite it. The org still stands, on ticket 03's reason: the
  dashboard's **label picker is only populated in an org context**, and a flat user
  namespace would ship a cross-project view with no working filter._

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
  **Built, lost, and rebuilt** — now at <http://localhost:3210/> from
  `/var/tmp/forgejo-prototype/build.sh` (Forgejo 15.0.7, the ticket-01 pin). The
  original instance died within hours: its bind mounts sat in a session scratchpad
  that tmp cleanup emptied. **Do not trust a bare "it is running" claim — `curl`
  it, and re-run `build.sh` if it is down.** Issue numbers shifted in the rebuild
  (map is now `#15`, board is project `1`); see the notes' §6. 4 real repos in an org
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

- [The GitHub exit: settleup's image, and public visibility](issues/08-github-exit.md) —
  **GitHub is not touched. Left as is** (owner's decision, unqualified). Not deleted,
  not emptied, not swept read-only. The premise check found **78 non-fork repos, only
  6 with a local checkout** — so 71 were invisible to the `~/projects` survey, ~55 of
  them 2023-or-older coursework and graphics toys; all now out of scope. **Public
  visibility loss evaporates** (`issue-tracker`/`specs` stay readable), and
  **rollback is free** (every GitHub copy remains). The one real decision: the
  migration boundary is **"does GitHub *execute* something for me"**, giving four
  GitHub-native carve-outs — **`configs` (= `~/.dotfiles`, a PUBLIC GitHub repo the
  survey never scoped)**, `settleup`, `lunchlund`, `Stromdahl.github.io`. settleup's
  four options collapse to "deliberate carve-out", for free. **The destination is
  narrower than written** — see the ✅ block above. Riders: **06** amended (outcome
  survives), **07** gains a real argument (the 56-file tracker currently sits in a
  PUBLIC repo, so migrating is a visibility *reduction*), **10** inherits a
  two-source restore (`configs` from GitHub, the 20 from Forgejo).

- [Adopt the runner shape, confinement, and supply-chain posture](issues/12-adopt-runner-shape.md) —
  **Shape adopted as recommended**; Q5 (notifications) **deferred whole to `issues/013`**
  as not needed now. Premise checks moved four things: **`--locked` is CLI-only**
  (proved — no config key, no env var), so it is a lumin **spec §2 justfile edit owned
  by ticket 09**, taken for **reproducibility** (the perf gate must not compare `Ir`
  across differing dependency sets), *not* security. **The supply-chain worry shrank
  under measurement** — 27 third-party build scripts + 9 proc macros on this platform,
  squattable tail of five; the "1109 builds" figure is analytically empty (same
  lockfile, 1109 times); helium changes **blast radius, not likelihood**, already
  confined by rootless Podman. So **no gate reorder, no offline builds, no vendoring** —
  risk knowingly accepted. **`cargo mutants` writes 52.56 GiB/run** (measured,
  [`assets/12-measure-mutants-io.sh`](assets/12-measure-mutants-io.sh)) ⇒ **endurance is
  a non-issue and is withdrawn** (~2,500 runs of budget); the real problem is **~80 MB/s
  sustained for 25–40 min**, so the cache moves to the **NVMe root disk**, *not* the SSD
  mirror — guarded by a **fail-early free-space check + mandatory cleanup**, no quota.
  **M9 partially run** — its cgroup half resolved (**`cpu memory pids` ARE delegated**,
  so limits are real) but **`io` never is, and every device is `mq-deadline`**, so
  `ionice` and cgroup `io` are **unavailable to jobs by construction**, not declined; the
  podman-version/socket/glibc probes stayed **unmeasured because podman is not installed**. **Rootless Podman's prerequisites are absent on
  helium** (no podman/uidmap/slirp4netns/fuse-overlayfs; only `ms` has a subuid range) =
  real unscoped ansible work. **No badges** — mesh-only forge, one viewer, and
  shields.io cuts against the motive. Full spec in the ticket — **with the runner's
  unit type (system-with-`User=` vs `systemd --user`) deliberately left OPEN**, since 04
  does not disambiguate it and the `io` argument for a system unit was withdrawn.

- [Tracker cutover: what moves into Forgejo Issues, and what stays markdown?](issues/07-tracker-cutover.md) —
  **Everything moves, maps included.** The hybrid was recommended and declined. The
  prototype passes, but **the list is the tracker and the board is decoration** — no
  workflow, skill or adapter may ever depend on it, because it is hand-fed and
  permanently unautomatable, which is taskmaster's exact failure mode. **All 56
  `.dotfiles` issues migrate**, closed ones included, and the markdown is deleted;
  **assets go to a private `projects/planning` git repo, not attachments** (the one
  regression with no workaround). Vocabulary becomes **open / claimed / done /
  dropped** — `closed` was a misspelling of `done`; `claimed` is an **assignee**, one
  atomic call, which fixes the concurrent-sandbox collision the old
  "flip `status` and commit" rule had. Labels take the **slash form** with
  exclusivity, **org-level only**; epics stay labels (milestones are repo-scoped and
  the dashboard has no milestone filter). The `issue-tracker` spec **survives but
  loses default status** — `rust-template` flips forge-first; seven other repos
  (~59 issues) migrate lazily. Toolchain: **`bin/forge` + a CLI cookbook**, `bin/wf`
  gains a Forgejo dialect. Two corrections worth carrying: maps are **append-only**
  (387 added / 34 deleted), so the "git diffs it beautifully" argument was weaker
  than written; and **the privacy win is future-only** — 87 public commits already
  hold every map. Riders onto [11](issues/11-persistence-backup-and-pins.md) (now
  the *only* copy of the tracker) and [10](issues/10-forge-sync-contract.md).

- [lumin's definition of done, once the deep tier is remote](issues/09-lumin-definition-of-done.md) —
  **The cross-host anchoring hazard does not exist.** krypton (Zen 5) and helium
  (Coffee Lake), in the same pinned image at the same commit, measure
  **byte-identical `Ir` on all twelve benches** — so resolution 1 wins, but refined:
  **the anchoring authority is the pinned job image, not a host.** Any host running it
  may bless (krypton is *not* demoted — `docker run <image> just perf`); only a
  *host-native* run is advisory, on a measured 26 `Ir` residual from workspace path.
  helium clears the Anchoring rule at **1.70 ms / 16.67 ms (~9.6×)**. Spec §1 is
  **restated, not broken**: *one gate definition, two execution sites* — the CI workflow
  must call `just` recipes and may never define a gate inline, which **overturns ticket
  04's preference** and puts `--in-place` in the justfile as `mutants *ARGS`. Done =
  fast tier green + pushed + CI verdict green; `just qa` survives as debug/offline/
  pre-push only. **`nice` is dropped entirely** (cgroups are real, `ionice` isn't);
  systemd values stay deferred behind ticket 12's open unit type. **Blocking discovery:
  default seccomp forbids the perf gate** — `personality(ADDR_NO_RANDOMIZE)` is denied
  by Docker's *and* Podman's default profiles, so the job needs a custom profile
  (default + that one arg, not `unconfined`). Also found: **lumin's committed Ceilings
  are already stale on krypton** (`particles` 4,716,499 vs a blessed 5,377,605), so the
  feared silent false green is happening from plain code drift. Evidence:
  [`assets/09-anchoring-measurements.md`](assets/09-anchoring-measurements.md).

## Not yet specified

In-scope fog — real, but not yet sharp enough to ticket:

- **Generalizing CI beyond lumin.** `rust-template` is the natural home for a
  reusable workflow, but its shape is unknowable until lumin's actual workflow
  exists. ~~Graduates after tickets 04 + 09.~~ **Both are now closed and it did not
  graduate** (corrected 2026-08-23): ticket 09 fixed the *contract* a workflow must
  honour — call `just` recipes only, never inline a gate — but the reusable shape still
  waits on lumin's real workflow existing. The trigger is that workflow, not a ticket.
- **New-project convention.** _Direction settled 2026-08-23 by ticket 07:
  **forge-first**, and `rust-template` stops shipping an `issues/` dir._ What remains
  fog is the rest of the payload — `AGENTS.md`, the CI workflow, how the repo gets
  registered, and whether creation is scripted at all.
- **Repo topics as the grouping.** [Ticket 06](issues/06-repo-curation.md) chose
  one flat org and deferred categorization to Forgejo **topics** (many-to-many,
  non-breaking) rather than org partitions. Which topics, and whether any are worth
  having at all, waits until the 20 repos are actually sitting in a listing.

- **taskmaster's fate** — retired, repurposed as a forge-reading client, or
  deleted. Its two unbuilt pieces (`show` output, install story) are blocked on
  design decisions that may simply evaporate. Note its hard-won insight is worth
  keeping either way: *a project is a registered entity, never a directory.*
- ~~**CI failure notification.**~~ **Closed 2026-08-23 — twice over.** Ticket 04 found
  the mechanisms (per-job commit statuses on push, but **none** for scheduled /
  `workflow_dispatch` runs; a first-party opt-in failure email; a badge endpoint; an
  `if: failure()` step). Ticket [12](issues/12-adopt-runner-shape.md) then **deferred the
  choice whole to `issues/013`** (*"we don't need this now"*) and corrected 04's rider:
  there is **no ntfy and no mail on the fleet** — only **HA-MQTT** (Mosquitto on argon,
  `192.168.1.99:1883`, issue 046). Nothing in the runner spec depends on it. The
  **success-heartbeat** question rides along to `013`, unasked.
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
- ~~**How far the agent toolchain moves.**~~ **Closed 2026-08-23 by
  [ticket 07](issues/07-tracker-cutover.md).** The hybrid was declined: everything
  moves. `bin/forge` gets written and `issue-tracker-forgejo.md` is a **CLI**
  cookbook against it (not HTTP); `triage` and `code-review` move; wayfinder's
  tracker doc gains a mandatory Forgejo "Wayfinding operations" section; `bin/wf`
  gains a third dialect. Knowingly a local fork of the verbatim-upstream
  `setup-matt-pocock-skills/`. Execution, not decision, from here.

- **Two execution items surfaced by [ticket 08](issues/08-github-exit.md)**, parked
  here so they are not lost — neither is a decision:
  - `Stromdahl.github.io` has **no local clone anywhere under `~/`**, so GitHub is its
    only copy. Fix is one command: `gh repo clone Stromdahl/Stromdahl.github.io
    ~/projects/`. Graduates with the migration execution issues.
  - **Audit the public map bodies.** _Trigger changed 2026-08-23 by ticket 07._ Maps
    are moving to Forgejo, but that does **not** retire this: `~/.dotfiles` is a
    PUBLIC GitHub repo and a permanent carve-out, so all 87 commits touching
    `planning/` and `issues/` stay readable **whether or not the files are deleted**.
    Deletion cannot unpublish. So the audit is no longer conditional on 07 — it is
    now a **security chore over the existing public history**, and the only action it
    can produce is *rotate anything that turns out to be a live secret*. Not a
    decision; never becomes a wayfinder ticket.

- **Rootless-Podman prerequisites are not provisioned on helium** — surfaced by
  [ticket 12](issues/12-adopt-runner-shape.md), parked here because it is execution, not
  a decision. `podman`, `newuidmap`/`newgidmap`, `slirp4netns` and `fuse-overlayfs` are
  **all absent**, and only `ms` has a subuid/subgid range. So the runner needs an ansible
  task nobody has written: install those four, provision a non-colliding subuid range for
  the `forgejo-runner` user, and `loginctl enable-linger` it for `podman.socket`.
  Graduates with the build issues.

- **The five personal maps under `~/vault/projects/`** — `diy-speakers`,
  `finance-rebuild`, `not-so-smart-smartwatch`, `strength-and-weight`,
  `vardepapperskredit`: **50 tickets** that [ticket 07](issues/07-tracker-cutover.md)
  did not consider. 07 decided "everything moves" on the evidence of
  `~/.dotfiles/planning/` and the eight repo `issues/` dirs; `bin/wf` surfaced these
  only afterwards. They are **personal, so not covered by the work carve-out**, and
  `diy-speakers` is one of ticket 06's twenty repos — so the same argument applies
  to them. Two things make it a real question rather than a formality: they live in
  the **Syncthing-replicated vault**, not in a git repo, and one of them
  (`finance-rebuild`) is financial. Sharpen into a ticket once the migration's shape
  is concrete.

- **Four execution items from [ticket 09](issues/09-lumin-definition-of-done.md)**,
  parked here — none is a decision:
  - **lumin's committed perf Ceilings are stale** and need a human re-anchor bless
    (`particles` measures 4,716,499 against a blessed 5,377,605 — **on krypton**, so
    this is code drift since 2026-08-20, not the CI split). Belongs to lumin's own
    tracker, not this map.
  - The **spec amendment + `AGENTS.md` rule-1 swap + two justfile changes**
    (`--locked`, `mutants *ARGS`), both rule-6 flagged.
  - The **custom seccomp profile** (default + `personality(0x40000)`) and its
    `container.options` wiring — graduates with the runner build issues, alongside the
    rootless-Podman prerequisites above.
  - A **`bin/` wrapper over Forgejo's commit-status API**, so an agent reads the CI
    verdict through a verb rather than raw curl.

## Out of scope

- **Restructuring `~/projects`' filesystem layout** — grouping, cleaning out the
  non-git dirs, reshuffling directories. Fixes nothing the forge doesn't fix, and
  cuts against taskmaster's own insight that a project is not a directory.
  `~/projects/<name>` is a fine layout.
- **Offsite backup** — belongs to helium's deliberately deferred restic offsite
  slice (`issues/016`, `issues/026`), not here. Decided: two copies (forge +
  working clones) is enough for code.
- **GitHub push-mirroring** (the "Forgejo canonical, GitHub as a read-only shop
  window" option) — offered, deferred as a *possible follow-up effort*. Its stated
  trigger is **gone**: ticket 08 leaves GitHub untouched, so `issue-tracker` and
  `specs` never lose public visibility and there is nothing to sting. Mirroring would
  now only be about keeping the abandoned GitHub copies *fresh* — a different, weaker
  motive. Still out of scope.
- **Acquiring dedicated build hardware / paid CI minutes** — ruled out when the
  goal was settled as laptop load rather than wall-clock.
- **Work / Sensative projects** (`~/yggio`, the 29 worktrees, the yggio GitHub
  tracker). This effort is personal projects only; see the separate
  `~/projects/specs/.scratch/work-tracking/` map.
- **Pulling any of ticket 08's four carve-outs off GitHub** — putting radon on the
  mesh, standing up public hosting or a public registry, or rebuilding the
  `bootstrap.sh` + `stromdahl.keys` path without GitHub. The owner: *"might revisit
  this in the future, but it's out of scope here."* Returns as a **fresh effort**, not
  a resumption. See [ticket 08](issues/08-github-exit.md).
- **The 71 GitHub repos with no local checkout** — ruled out by ticket 08's "GitHub
  untouched". They are not fog: no decision is pending on them, they simply stay.
- **A `forge sync` reconcile/restore command** — shelved by
  [ticket 10](issues/10-forge-sync-contract.md) on the owner's *"we can shelf this
  until we need it"*, before its direction set was settled. It would have reported
  drift in both directions and cloned the 20 repos onto a fresh machine. **Knowingly
  accepted cost:** *"helium has my code"* stays a belief rather than a checked fact,
  and nothing will notice a repo created later and never pushed — the state 29 repos in
  `~/projects` are in today. Cheap to resume: the five premises it turned on were
  **measured before it was shelved** and are banked in the ticket plus
  [`assets/10-forge-api-probes.sh`](assets/10-forge-api-probes.sh) — clone-URL form,
  server-side read-only token scoping, token-as-HTTP-git-credential, archived repos
  being push-only, and the trap that git **persists an embedded HTTP credential
  verbatim into `.git/config`** (which makes HTTPS-vs-SSH a real trade). Two things it
  leaves behind: **`bin/forge` is still built** (ticket 07 needs it for the tracker leg
  — this shelves a *subcommand*, not the wrapper), and the **read-only-vs-write token
  choice** now belongs to whoever builds it, following the house pattern of a plain
  JSON token file in `$HOME` (`bin/ha`, `bin/unifi`; **`pass` is not installed**, so
  the ticket's `pass` option never existed).
