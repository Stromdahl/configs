# Which repos come to the forge, and in what state?

Type: grilling
Status: resolved

## Question

"Organize" was scoped to hosting + **curation**. Curation is the half that needs
the owner: deciding what is alive, what is parked, and what is dead — because
importing 24 repos with no sense of which 12 are stale just moves the mess behind
a nicer front-end.

Work through, with the owner (`/grilling`):

1. **The 17 remote-less repos** — one at a time or in batches, `active` / `paused`
   / `archived`. (Forgejo has a per-repo archive flag; `taskmaster`'s
   `state = active|paused|archived` was reaching for exactly this vocabulary and
   is worth reusing.)
2. **The edge cases the survey turned up:**
   - `keyerr` — a git repo with **no commits at all** and a dirty tree. Is this a
     project or a false start?
   - `homelab-stack.archived` — remote points at the decommissioned
     `jellyfin.stromdahl.tech`. Archive as history, or drop? Its content is
     superseded by `~/.dotfiles/servers/` (`project_monorepo_merge`).
   - `playground`, `rssfeed`, `vendor`, `hermes` — **not git at all**. Do any
     become repos, or do they stay loose directories? (`hermes` is live —
     see `project_hermes_agent_architecture`.)
   - `marlin-ender3`, `marlin-configs` — **upstream clones of MarlinFirmware's
     repos**, not the owner's work. Recommendation: exclude from the forge
     entirely; they are re-cloneable from upstream and do not need backing up.
     Confirm.
3. **Naming.** Does the forge repo name always match the directory name? The
   survey found `diy-speekers` (sic) — a chance to fix a typo, at the cost of the
   directory and the repo disagreeing.
4. **Organisation structure.** One user account with flat repos, or Forgejo
   *organisations* to group them (e.g. `tools` / `hardware` / `homelab`)? Note
   this is grouping *on the forge*, which is cheap and reversible — filesystem
   restructuring is explicitly out of scope.

Output: a concrete, per-repo import list with states — the input the migration
work will execute against.

## Answer

**20 repos go to the forge, in a single organisation, in two states.** The
candidate set turned out to be larger and the survivor set smaller than the map's
survey suggested — see *Survey corrections* below.

### Vocabulary (decided)

`taskmaster`'s three-state `active | paused | archived` **collapses to two**:

- **`archived`** — Forgejo's per-repo archive flag. Read-only, pushed down the
  listing. A deliberate act with a mechanical consequence.
- **`active`** — simply *not archived*. The default; no curation required.

`paused` was rejected. It encodes only intent, and intent decays: nothing would
ever flip a `paused` repo to `archived`, so the label would silently become a lie
— which is exactly how `taskmaster` itself died (state that needed hand-maintaining
and never got maintained). Worse, "untouched for a while" is **already computed by
git** and displayed by Forgejo, so `paused` would re-encode by hand what the forge
knows for free. Recency answers "is this alive?"; the only judgment left is the one
that does something: *do I want this read-only and out of my listing?*

### What comes, and in what state

**`archived` (2)** — both archived for *supersession*, not staleness, which is the
one archive justification that does not rot:

| repo | why |
|---|---|
| `oppen` | Superseded by `msbrain`. Both are "an assistant over my personal life data". The tell is `msbrain`'s **ADR 0006**, which lays out a deliberate three-repo split (`.dotfiles` / `~/notes` / `msbrain`) — and `oppen` is not one of the three. `msbrain` 49c/Aug 02 vs `oppen` 22c/Jun 14. |
| `telltaled` | Its one job got done another way. A fleet telemetry daemon selling MQTT transport — but helium's metrics now reach HA over MQTT via two purpose-built publishers + the Mosquitto add-on (`project_helium_metrics_mqtt_ha`), built in July without it. |

**`active` (18)** — everything else. Stale-but-unsuperseded stays active on
purpose: "I haven't touched it since June" is not a decision.

- Previously homeless (13): `lumin`, `msbrain`, `ghtop`, `taskmaster`,
  `diy-speakers`\*, `freecad-prints`, `not-so-smart-smartwatch`, `custom-keyboard`,
  `pinecad`, `rust-template`, `docker-tools`\*, `pass-tui`, `timelog`
- Already on GitHub (5): `settleup`, `lunchlund`, `specs`, `issue-tracker`,
  `finance-track`

\* renamed — see below. `rust-template` is deliberately active: the map's fog has
it as the future home of the reusable CI workflow.

### Excluded, and why

The exclusions were each justified by a **fact**, not a judgment about value —
which is why they needed no per-repo debate:

| excluded | count | reason |
|---|---|---|
| `playground/*` | 12 repos | *(4 of these are also zero-commit — the rows overlap; the union is 24 repos + 2 dirs, not the column sum.)* **Disposable by design** — the directory name was doing its job. Includes `pine3d` (48c, 3.1G): experiment history, not a project to mourn. |
| Zero-commit `git init`s | 5 | `keyerr`, and `playground/{bluetoothfun,iac-explore,ms-keyboard,opsmith-explore}`. No history to preserve; hosting them backs up nothing. |
| Upstream clones | 7 | `marlin-ender3`, `marlin-configs`, and `vendor/{btleplug,yazi,wlgreet,ransible,quicksync_calc}` — not the owner's work, re-cloneable from upstream. |
| `rssfeed` | 1 | Real code (`src/`, `package.json`) but **never `git init`'d**. Untracked after this long = not versioned. Trivially reversible if wanted. |
| `homelab-stack.archived` | 1 | **Dropped, not archived.** Remote points at the decommissioned `jellyfin.stromdahl.tech`; content superseded by `~/.dotfiles/servers/` (`project_monorepo_merge`). The history dies with the host it named. |
| `hermes` | — | Nothing to exclude: `~/projects/hermes` holds **zero entries** (verified with `find -mindepth 1`; no `.stfolder`, mtime Jul 12), so it is not a Syncthing share either — cf. `project_hermes_vault_sync`, which is about `~/vault`. The live agent is on `titan-hermes-agent`. |

### Naming: forge name may differ from directory name

Renamed **on the forge only**; local directories untouched:

- `dockerstats` → **`docker-tools`**. Its own README: *"The directory is still named
  `dockerstats` for historical reasons — that's now just the name of the first tool,
  not the whole repo."* Known-wrong by its author.
- `diy-speekers` → **`diy-speakers`**. Straight typo; 1 commit, nothing pins to it.
- `msbrain` **keeps its name** despite its README saying *"(name is a placeholder)"*
  — a placeholder means the real name isn't decided, and inventing one now is worse
  than keeping it.

Justified by the map's own credited insight — *a project is a registered entity,
never a directory* — so the forge name **is** the project's name and
`~/projects/<dir>` is just where a clone sits. Renaming the local directories was
rejected: it breaks `cd ~/projects/dockerstats` and every absolute path in notes,
scripts, and `AGENTS.md`. Better to absorb the mismatch in one tool.

**Consequence for ticket 10:** `forge sync` **cannot assume `dir name == repo
name`**. It needs a two-entry alias map (`dockerstats→docker-tools`,
`diy-speekers→diy-speakers`) alongside the ignore list it already needed.

### Organisation: one org, named `projects`

**A single organisation holding all 20 repos** — rejecting both flat-under-user and
the offered `tools`/`hardware`/`homelab` split.

- *Against multiple orgs:* an org is a **path segment in every clone URL** — a hard,
  single-parent partition baked into every remote; regrouping later rewrites URLs.
  And the categories don't survive scrutiny (`pinecad` is a CAD tool *for* hardware;
  `docker-tools` is a tool *for* the homelab). That grouping wants to be
  many-to-many, which is what **topics** are for — free, non-breaking, several per
  repo. Topics deferred until actually wanted.
- *Against flat-under-user:* **this hedges ticket 03.** The tracker leg exists to get
  a *cross-project view*. If Forgejo's kanban/projects are **org-scoped**, a single
  org is the only namespace where one board spans all 20 repos; if they're also
  per-user, a single org costs nothing. Correct under either finding, and the cheap
  direction to be wrong in — starting in an org costs one path segment, moving into
  one later rewrites 20 remotes.

Org name `projects` is a recommendation, settled at creation time (an org rename
rewrites clone URLs, so it is not free later).

### Survey corrections (the map's Notes were wrong here)

Established by direct measurement of `~/projects`, 2026-08-23, via
`git -C <d> rev-list --all --count` / `log -1 --format=%cd` / `remote get-url` and
`du -sh` per directory:

1. **`playground` is not a non-git directory** — it is a *container of 12 more
   remote-less repos*, including `pine3d` (48 commits). The homeless candidate set
   was therefore **29, not 17**.
2. **`~/projects/hermes` is empty** — 4.0K, zero entries. The map's "hermes is live"
   refers to `titan-hermes-agent` (`project_hermes_agent_architecture`), not this
   directory.
3. **Storage is a non-issue and must not be re-opened as one.** Every `.git` in
   `~/projects` together is **~85 MB** (largest: `marlin-configs` 20 MB, excluded).
   Working trees total ~40 GB, but that is `target/` and `node_modules/` — none of it
   pushes. Largest survivor history: `lumin` 6.7 MB.

Re-run the survey with:
```bash
cd ~/projects && for d in */; do d=${d%/}; [ -d "$d/.git" ] && \
  printf '%-24s %s %s %s\n' "$d" "$(git -C $d rev-list --all --count)" \
  "$(git -C $d log -1 --format=%cd --date=short)" \
  "$(git -C $d remote get-url origin 2>/dev/null || echo none)"; done
```

### Not decided here

`taskmaster`'s fate stays in the fog — the conversation did not naturally reach it.
It is `active` on the forge, which prejudges nothing.
