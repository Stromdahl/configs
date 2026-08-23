# Prototype notes: a throwaway Forgejo loaded with real repos and real issues

Resolves the build half of `planning/personal-forge/issues/05-forgejo-ui-prototype.md`.
Built 2026-08-23 on **krypton, in Docker, localhost only** — no helium, no radon,
no ssh. Nothing was committed and nothing under `~/projects/` or `~/.dotfiles/issues/`
was modified (repos were pushed with an explicit URL, so no remote was left behind;
verified with `git remote -v` after each push — all four still have zero remotes).

**Shape note.** The `/prototype` skill has two branches (a terminal state-machine
harness, or several switchable UI variants). Neither applies: the artifact the
ticket asks for is *a real tool loaded with real data*, so the skill's rules 1–5
(one command, no persistence, no polish) and rule 6 (commit to a throwaway branch)
are set aside deliberately. The lead's instruction — do not commit — wins over
rule 6.

---

## 1. The instance

- **URL:** <http://localhost:3210/> — org listing: <http://localhost:3210/projects>
- **Login:** `ms` / `protoforge123`
- **Version:** Forgejo **15.0.7+gitea-1.22.0**, image `codeberg.org/forgejo/forgejo:15-rootless`
  (the pin ticket 01 chose)
- **Everything lives in** `/tmp/claude-1000/-home-ms--dotfiles/3e0b65cb-7735-45ce-9e64-ab6ca8e06fc5/scratchpad/forgejo-prototype/`
  — `docker-compose.yml`, `data/` (8.3 MB), `config/`, the two importer scripts,
  `index-map.json` / `wayfinder-map.json`, and `.token` (the API token, mode 600).

```bash
cd /tmp/claude-1000/-home-ms--dotfiles/3e0b65cb-7735-45ce-9e64-ab6ca8e06fc5/scratchpad/forgejo-prototype

docker compose start      # resume — KEEPS all data
docker compose stop       # pause  — KEEPS all data
docker compose up -d      # first start / after an edit to the compose file
docker compose down       # remove the container — data survives in ./data
docker compose down -v && rm -rf data config   # DESTROYS everything
docker compose logs -f forgejo
```

It is a scratchpad path, so it does not survive a reboot / tmp cleanup — treat the
instance as good for this week, not forever.

**Setup facts worth carrying into the ansible role.** All config is env vars, as
ticket 01 found; the four that actually mattered:

- `FORGEJO__server__ROOT_URL` — without it every link and clone URL in the UI is
  wrong. The single most load-bearing var.
- `FORGEJO__security__INSTALL_LOCK=true` — skips the web installer entirely; the
  admin is then created with
  `docker exec forgejo-prototype forgejo admin user create --admin --username … --must-change-password=false`.
- `FORGEJO__database__DB_TYPE=sqlite3` — fine for one user; no postgres needed.
- Host dirs bound to `/var/lib/gitea` and `/etc/gitea` must be **`chown 1000:1000`
  before first start** (the rootless image runs as `git`, uid 1000). Confirmed.

`internal_tracker.enable_issue_dependencies` came back **`true` by default** on
every repo, so no pre-flight `PATCH` was needed.

---

## 2. What was imported

### Repos (org `projects`, per ticket 06)

| forge repo | source | state | why it's here |
|---|---|---|---|
| `projects/lumin` | `~/projects/lumin` | active | the serious one |
| `projects/taskmaster` | `~/projects/taskmaster` | active | the tracker that lost |
| `projects/diy-speakers` | `~/projects/**diy-speekers**` | active | **ticket 06's rename decision, rendered** |
| `projects/oppen` | `~/projects/oppen` | **archived** | ticket 06's `active\|archived` vocabulary, rendered |
| `projects/dotfiles` | *no code pushed* — `auto_init` only | active | home for the imported issues + the wayfinder specimen |

`oppen` was added beyond the ticket's "3–4 repos" on purpose: nothing else in the
set exercises the two-state decision, and the archive flag has a visible
mechanical consequence (read-only banner, pushed down the listing) that is worth
reacting to. `dotfiles` carries no git content — an issue tracker works fine
without matching code, and this avoided copying sops-encrypted files into a
scratch dir.

All pushed with `git push <explicit-url> --all` then `--tags`; `main` set as
default branch afterwards (a repo created with `auto_init:false` has no default
branch until you set one).

### Issues — 14 real ones from `~/.dotfiles/issues/`

`#2`–`#15` in `projects/dotfiles`, imported by `import.py`. Frontmatter mapping:

| dotfiles frontmatter | Forgejo |
|---|---|
| `status: open` | open |
| `status: in-progress` | open **+ assigned to `ms`** |
| `status: done` / `closed` | closed |
| `status: dropped` | closed **+ label `status:dropped`** |
| `priority: high\|medium\|low` | label `priority:*` |
| `labels: [epic:x, needs-human]` | labels verbatim |
| body | body, prefixed with a provenance line naming the source file |

The `in-progress` → assignee mapping is deliberate: the wayfinder frontier
convention reads a non-empty `assignees` as the claim signal, so this makes the
frontier query actually testable (`#5`, `#6`, `#7` are the claimed ones).

### Wayfinder specimen — `planning/vault-serve/`, `#16`–`#21`

Built exactly to the amendment's shape:

- `#16` map issue, label `wayfinder:map`
- `#17`–`#21` children, each labelled `wayfinder:effort:vault-serve` +
  `wayfinder:research|grilling|execution`, each with **`Part of #16` as the first
  body line**
- a markdown task list in the map body for order, explicitly captioned as inert.
  Its four `[x]` boxes were **hand-set by me to match child state at build time**
  — Forgejo did not tick them and will never update them (see §3.4)
- **two real blocking edges** via `POST …/issues/{child}/dependencies`, of which
  only the first is transcribed from the source map:
  - `#21` blocked by `#20` — **faithful**: `005-perlite-service.md` says
    `Blocked by: 004`. Renders as *satisfied*, since `#20` is closed.
  - `#16` blocked by `#21` — **prototype-added**, not a fact about
    `vault-serve/map.md`. Justified by wayfinder semantics (a map cannot resolve
    before its children) and added so the owner sees the *live-blocker* rendering
    too. Do not read it back as a statement about the real map.

  A synthetic edge was needed because there is **no open→open dependency anywhere
  in the real `~/.dotfiles/issues/` set** — every open issue's stated `Depends on`
  target is already `done`. Mildly interesting in itself: the real frontier is wide.

### Board — org-scoped, built by hand

<http://localhost:3210/projects/-/projects/3> — "All projects — cross-repo board",
from the built-in *Basic kanban* template, all 20 issues placed:
Backlog 6 · To Do 3 · In Progress 3 · Done 8.

**This board can never be automated.** There is no `/projects` path anywhere in
this instance's own swagger (verified: `curl …/swagger.v1.json | grep project` →
nothing). I built it by driving the **web forms** with a session cookie and the
`_csrf` cookie replayed as a form field — HTML scraping, not an API. That worked,
but it is exactly the thing no skill or adapter should ever depend on: the field
names, the CSRF mechanism and the htmx endpoints are internal and will move
between releases. Treat the board as **human-only, forever**, and treat the fact
that I populated it programmatically as an artefact of this prototype, not a
capability.

---

## 3. Where the API research was wrong or incomplete

The research (`assets/03-forgejo-issue-model-research.md`) held up well. Its six
footguns all behaved as documented — `type=issues`, `PATCH {"state":"closed"}`,
create-takes-IDs vs sub-resource-takes-names, no `labels` on `PATCH`, assignees
replace, no `@me`. Four things it got wrong or did not know:

### 3.1 `exclusive: true` is a **silent no-op on `:`-separated labels** — and the amendment's convention forgoes it

This is the sharpest finding, and it contradicts §7's claim that exclusive labels
are "a genuine *improvement* over both existing adapters". Measured directly:

| labels | `exclusive` accepted? | second one applied → |
|---|---|---|
| `wayfinder:type:research` + `wayfinder:type:grilling` | **yes, stored `true`** | **both coexist** — no exclusion |
| `probe/scoped` + `probe/other` | yes | **second replaces the first** |
| `triage/needs-triage` → `triage/ready-for-agent` on `#4` | yes | **replaced** (still visible on `#4`) |

So **`/` is the scope separator, `:` is not** — and the API happily accepts and
stores `exclusive: true` on a label it will never enforce, with no warning. Two
consequences:

- The amendment's `wayfinder:map` / `wayfinder:effort:<slug>` / `wayfinder:<type>`
  convention is built as specified and works fine, but it **cannot** use
  exclusivity. To get it, the convention has to become `wayfinder/type/research`
  etc. — a naming change ticket 07 should make knowingly, not discover later.
- Three demo labels `triage/needs-triage` · `triage/ready-for-agent` ·
  `triage/wontfix` are on the instance (on `#2`, `#4`, `#10`) purely so the two
  renderings sit side by side in the UI. Colon labels render as one flat pill;
  slash labels render as a split scope/value pill.

### 3.2 Same-named org and repo labels **both attach**, silently

`POST /issues/{n}/labels {"labels":["epic:services"]}` resolved to **two** labels
— the org-level one (`/orgs/projects/labels/1`) *and* the repo-level one
(`/repos/projects/dotfiles/labels/6`) — and attached both. The issue then shows a
duplicated pill and every `labels=` query double-counts. Not mentioned anywhere in
the research. I deleted the org-level duplicate to leave the instance clean. Rule
for the adapter: **pick one level and never define a name at both**, or resolve
name→ID yourself instead of passing names.

### 3.3 Boards **are** org-scoped — ticket 06's hedge pays off

Nobody had looked. Measured:

- `/{org}/-/projects` → **exists** (`/projects/-/projects`), and it is a
  **first-class tab in the org nav**, alongside Repositories / Members / Teams
  (re-checked against the live org page after the board existed).
- `/{owner}/{repo}/projects` → exists (repo-scoped boards).
- `/{user}/-/projects` → exists.
- A **user-level** board is **not offered** in the sidebar of an issue in an
  org-owned repo (the dropdown read "No items"). An **org-level** board *is*, and
  so is a repo-level one.

So ticket 06's "one org hedges ticket 03" reasoning was **correct, and load-bearing**:
an org board is the only namespace that can span all 20 repos. Flat-under-user
would have made the cross-project board impossible for anything living in an org.

### 3.4 Small mechanical corrections

- **The column-move endpoint drops issues that share a `sorting` value.** Posting
  `{"issues":[{"issueID":a,"sorting":0},{"issueID":b,"sorting":0}]}` to
  `…/projects/{id}/{col}/move` returned `200` and moved **one** of them. Distinct
  `sorting` values (or one call per issue) works. Only matters to a human clicking,
  but it is a nice illustration of how unsupported that surface is.
- **Task-list checkboxes in an issue body render `disabled`** in the served HTML.
  So the inertness is stronger than the amendment assumed: not only does closing
  `#21` fail to tick its box — the box cannot be clicked at all; changing it means
  editing the body markdown. Good: nothing can drift into looking like live state.
- **`DELETE …/issues/{n}/labels/{name}` works with a colon in the name**
  un-escaped. Fine.

### 3.5 Confirmed exactly as documented

- **The `dependencies` direction.** `POST …/{index}/dependencies` with
  `{"owner","repo","index"}` = *path is blocked, body is the blocker*. Verified
  with a read-back `GET` after each write; both edges landed the right way round.
- **HTTP 412 on closing a blocked issue.** Deliberately tried to close the map
  while `#21` was open:
  `412 {"message":"cannot close this issue because it still has open dependencies"}`.
  Real, and a genuine behavioural difference from GitHub/GitLab — a resolve step
  must close children before the map. The sidebar renders it as a **"Depends on"**
  list with the tooltip *"Closing this issue is blocked by the following issues"*.
- **One-call cross-repo map listing.** `GET /repos/issues/search?labels=wayfinder:map&state=open&type=issues`
  returned exactly the one map. As advertised.

---

## 4. What mapped awkwardly

- **`~/.dotfiles/issues/` has five statuses, not the three its README documents.**
  `open` / `in-progress` / `done` per the README, plus `closed` and `dropped` in
  the wild. Forgejo has exactly two states, so `dropped` had to become
  *closed + a `status:dropped` label* — the information survives, but only by
  convention, and nothing enforces it. Worth deciding in ticket 07 rather than
  inventing at migration time.
- **`in-progress` has no home.** Forgejo's only in-flight signal is an assignee
  (or a board column, which no agent can read). "Assigned to `ms`" carrying the
  meaning "in progress" works for a single-user forge but is a coincidence, not a
  model.
- **Nothing represents an epic except a label.** That is the same as today, so no
  regression — but with 24 `epic:services` issues, the flat label starts to look
  thin. Milestones exist and were not used.
- **`Part of #16`** renders as an ordinary issue link, no different from any other
  cross-reference. The map's children are legible *only because* of the
  `wayfinder:effort:vault-serve` label query — the body line buys nothing
  machine-readable, exactly as ticket 03 predicted.

---

## 5. What the owner should look at first

The point of this instance is a gut reaction, so look in this order:

1. **<http://localhost:3210/projects/-/projects/3>** — the kanban board, 20 real
   issues in four columns. **This is the candidate answer to "a UI I actually
   open."** Look at it knowing that no agent will ever be able to read or write
   it: every card here got placed by a human (or, this once, by scraping the web
   forms). If this is the thing that makes the forge worth having, that is a
   decision to make with the automation cost on the table.
2. **<http://localhost:3210/projects/dotfiles/issues/16>** — the vault-serve map
   as a Forgejo issue. Compare it against `planning/vault-serve/map.md`. Judge
   three things: the inert task list, the `Depends on` sidebar showing `#21`
   blocking the map, and whether a map reads better as an issue or as markdown
   (this is ticket 07's hybrid question, made concrete).
3. **<http://localhost:3210/projects/dotfiles/issues>** — the tracker at realistic
   density: 14 real helium issues plus the specimen. Filter by `epic:services`,
   by `needs-human`, by `priority:high`. Then look at `#2`, `#4` and `#10` and
   compare the split `triage/…` pills against the flat `wayfinder:…` ones — that
   is §3.1's finding, visible.
4. **<http://localhost:3210/projects>** — the org listing with `oppen` archived
   and `diy-speakers` renamed. This is what 20 repos will look like, and it is the
   view that will decide whether topics (the map's open fog) are needed at all.

---

## 6. Rebuilt 2026-08-23 (evening) — the instance died, and where it lives now

The original instance **was lost the same day it was built.** Its bind mounts
pointed at a session scratchpad (`/tmp/claude-1000/…/3e0b65cb-…/scratchpad/`),
tmp cleanup emptied `data/` and `config/`, and the container has been
`Exited (1)` ever since (`/var/lib/gitea/git is not writable`). Verified it was
genuinely unrecoverable rather than merely stopped, before rebuilding:

```bash
docker inspect --format '{{json .Mounts}}' forgejo-prototype   # Type: bind, both
docker volume ls                                               # no forgejo volume
```

Both mounts were **binds**, so nothing survived in `/var/lib/docker/volumes`.

**Rebuilt from this document** — it turned out to be a complete recovery spec;
nothing had to be re-derived. Three things changed:

- **Durable path:** `/var/tmp/forgejo-prototype/` (not a session scratchpad).
- **Container:** `forgejo-proto2`, same `:15-rootless` pin, same port 3210,
  same login `ms` / `protoforge123`.
- **`build.sh` rebuilds the whole thing end to end** — compose, admin, token, org,
  four real repo pushes, `oppen` archived, 14 issues, the wayfinder specimen with
  both blocking edges, and the board. `import.py`, `wayfinder.py`, `board.py`
  alongside it. Re-runnable; it destroys and recreates.

**Issue numbers shifted** (`dotfiles` was created with `auto_init`, so numbering
starts at `#1` rather than `#2`):

| | original | rebuild |
|---|---|---|
| imported `.dotfiles` issues | `#2`–`#15` | **`#1`–`#14`** |
| wayfinder map | `#16` | **`#15`** |
| map children | `#17`–`#21` | **`#16`–`#20`** |
| org board | project `3` | **project `1`** |

Two deliberate differences from the original build:

1. **Both label renderings now sit on the specimen itself**, not on separate demo
   issues: every child carries `wayfinder:effort:vault-serve` + `wayfinder:<type>`
   (colon, flat pill) **and** `wayfinder/type/<type>` (slash, split pill,
   `exclusive: true`). §3.1's finding is therefore visible on a single issue.
2. **The board was built by DB surgery, not form scraping** (`board.py` writes
   `project_board` / `project_issue` directly). The htmx column form carries no
   stable action or `_csrf` field, so the original session's scraping approach did
   not replay. This changes nothing about §3.3's conclusion and if anything
   sharpens it: **boards are human-only, forever** — this instance needed raw SQL
   to place a card. `board_type=2` on the create form also does **not** apply the
   kanban template; the board comes up with zero columns.

Card distribution now mirrors the real data rather than the original counts:
Backlog 6 (the open `.dotfiles` issues) · To Do 2 (the map + its one open child) ·
In Progress 3 (the assigned ones) · Done 9.

**Review URLs (rebuilt):**

1. Board — <http://localhost:3210/projects/-/projects/1>
2. Map as an issue — <http://localhost:3210/projects/dotfiles/issues/15>
3. Tracker at density — <http://localhost:3210/projects/dotfiles/issues>
4. Org listing — <http://localhost:3210/projects>
