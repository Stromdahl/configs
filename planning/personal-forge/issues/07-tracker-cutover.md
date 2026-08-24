# Tracker cutover: what moves into Forgejo Issues, and what stays markdown?

Type: grilling
Status: resolved
Blocked by: 03, 05
Assignee: claude (session 2026-08-23b)

## Question

The decision is made — Forgejo Issues become the tracker. This ticket decides the
*cutover*, with the prototype in front of the owner and ticket 03's findings in
hand.

What exists today, and would be affected:
- **56 files in `~/.dotfiles/issues/`** — the live homelab tracker, with YAML
  frontmatter (`status`/`priority`/`labels`, `epic:<slug>` for epics) and a
  "files never move, `status` is the source of truth" rule.
- **Three live wayfinder maps** — `planning/hermes-helium/`,
  `planning/vault-serve/`, and this one — plus `~/projects/specs/.scratch/work-tracking/`
  and `~/yggio/master/.scratch/translator-tags/` (both **work**, and out of scope).
- **Per-project trackers** — `lumin/.scratch/`, `taskmaster/tickets/`.
- **The `issue-tracker` spec itself** (`~/projects/issue-tracker`, v0.0.2), which
  other repos pin to.

Decide:

1. **Migrate or line-in-the-sand?** Do the 56 existing issues move into Forgejo,
   or does only *new* work land there while the markdown history stays put? A
   partial answer is legitimate (e.g. open issues migrate, closed ones stay).
2. **Do wayfinder maps move?** They are the hardest case: they need parent/child
   and blocking edges (ticket 03 says whether Forgejo has them), and their bodies
   are long, cross-linked, and amended in place — which git diffs beautifully and
   an issue tracker does not. It is entirely defensible for **maps to stay in
   `planning/` while ordinary issues move**. Reach a deliberate answer, not a
   default.
3. **What happens to the `issue-tracker` spec?** Deprecated, or does it live on as
   the convention for repos that stay markdown-tracked?
4. **The agent adapter.** Ticket 03 reports what `issue-tracker-forgejo.md` would
   need to say. Confirm it gets written, and which skills are expected to use it.
5. **React to the prototype** (ticket 05). This is the moment to find out whether
   the UI is genuinely one the owner opens — *before* the migration. If it is not,
   that is a real finding and the tracker decision should be revisited here rather
   than defended.

Also decide taskmaster's fate if the conversation naturally reaches it; otherwise
leave it in the fog.

## Amendment (2026-08-23, from ticket 03)

Ticket 03 returned **GO-WITH-WORKAROUND**, which reframes this ticket: the question
is no longer *"can Forgejo do it?"* but **"is the convention acceptable?"** Facts to
put on the table:

- **Blocking dependencies are native, cross-repo, and API-driven** — better than
  GitLab-free (no paid tier) and better than the GitHub adapter's own instruction.
  Not a concern.
- **There are no sub-issues, and there is no prospect of them** (tracking issue
  open, all three implementations closed unmerged, absent from the dev build). Maps
  would use `wayfinder:map` + `Part of #<map>` + labels — GitLab's primary shape and
  GitHub's documented fallback.
- **Kanban boards are unautomatable, permanently.** No `/projects` API. If any part
  of the intended workflow is board-driven, that part is human-only forever. This
  deserves explicit airtime, because the board is plausibly the whole reason the
  tracker decision went the way it did.
- **Forgejo refuses to close an issue with open blockers** (412 `DependenciesLeft`).

**A live option this ticket should weigh rather than assume away — the hybrid:**
keep the `local` markdown adapter for **wayfinder maps** (they stay in `planning/`,
git-diffable, cross-linked, amended in place, assets greppable in-repo) and use a
Forgejo adapter for **ordinary execution tickets**. That combination is already how
this repo works today, dodges the hierarchy gap entirely, and matches this map's own
"Plan, don't do" premise — maps produce decisions, and decisions belong in git.
Ticket 03 deliberately did not decide it. Decide it here, deliberately, rather than
letting "everything moves to the forge" win by default.

One practical note for the adapter question: a Forgejo adapter would be an **HTTP
cookbook**, not a CLI cookbook like the existing `github`/`gitlab`/`local` three —
unless a `bin/` wrapper is written first (`feedback_extend_wrapper_first`).

## Amendment (2026-08-23, from the ticket 05 prototype)

The prototype is live — **<http://localhost:3210/>** — so this grilling happens
with the real UI in front of the owner, not a description of it. Start at the
board (<http://localhost:3210/projects/-/projects/3>) and the vault-serve map as an
issue (<http://localhost:3210/projects/dotfiles/issues/16>). Four new facts:

1. **A label-naming decision, to be made knowingly rather than discovered.**
   `exclusive: true` is a **silent no-op on `:`-separated labels** — `/` is the
   scope separator, `:` is not, and the API stores the flag on colon labels without
   ever enforcing it. The `wayfinder:map` / `wayfinder:effort:<slug>` convention
   works but cannot be exclusive; exclusivity requires renaming to
   `wayfinder/type/research`. Both renderings are on the instance (`#2`, `#4`,
   `#10`) — colon labels render as one flat pill, slash labels as a split
   scope/value pill. Pick one here.
2. **`~/.dotfiles/issues/` has five statuses in the wild, not the three its README
   documents** — `open`/`in-progress`/`done`, plus `closed` and `dropped`. Forgejo
   has two. In the prototype `dropped` became *closed + a `status:dropped` label*:
   the information survives, but only by convention with nothing enforcing it.
   Decide the mapping here rather than inventing it at migration time.
3. **`in-progress` has no home.** Forgejo's only in-flight signal is an assignee
   (or a board column, which no agent can read). "Assigned to `ms`" meaning "in
   progress" works on a single-user forge by coincidence, not by model. Worth
   naming, because the current tracker's whole coordination mechanism is *"grab
   work by flipping `status`"*.
4. **`Part of #16` renders as an ordinary issue link** — no "parent of" semantic
   anywhere in the UI. The map's children are legible **only** because of the
   `wayfinder:effort:<slug>` label query. That makes ticket 03's hybrid option
   concrete: judge issue `#16` against `planning/vault-serve/map.md` side by side
   and decide whether a map genuinely reads better as an issue.

Also confirmed useful: dependencies were **enabled by default on every repo** (no
pre-flight needed), and same-named org+repo labels **both attach silently**, which
duplicates pills and double-counts label queries — an adapter rule, but also a
reason to keep label definitions at exactly one level.

## Rider (2026-08-23, from ticket 08) — the visibility argument for migrating

Ticket 08 established a fact this ticket did not have: **`~/.dotfiles` is
`Stromdahl/configs`, a PUBLIC GitHub repo.** So the 56 files in
`~/.dotfiles/issues/` — the live homelab tracker — and the three wayfinder maps in
`planning/` are **publicly readable today**.

That cuts both ways on question 1, and both directions are new:

- **For migrating:** moving issues into a mesh-only Forgejo is a **visibility
  reduction**, which is a direct win under the map's stated motive (*"I want it to be
  private"*). This is the first *affirmative* reason to migrate rather than merely
  draw a line in the sand — the previous arguments were all about convenience.
- **Against staying markdown:** `configs` is one of ticket 08's four **carve-outs**,
  so it stays GitHub-native permanently. Anything left as markdown in this repo stays
  public **indefinitely** — this is not a transitional state that later cleanup
  fixes.

This bears hardest on question 2 (**do wayfinder maps move?**). The "maps stay
markdown because git diffs them beautifully" argument is still sound on its merits,
but it now carries a price: the maps stay public. Worth checking whether any map body
contains something that shouldn't be — `planning/hermes-helium/issues/10` already
reasons explicitly from "`Stromdahl/configs` is **PUBLIC**", so at least one author
has been consciously working around it.

---

## Resolution (2026-08-23)

**Everything moves to Forgejo — maps included.** The hybrid was recommended and
declined. Seven decisions, in the order they were taken.

### Premise corrections found before the grilling opened

1. **The prototype was dead.** Its bind mounts sat in a session scratchpad that tmp
   cleanup emptied; the container had been `Exited (1)` for seven hours. Confirmed
   unrecoverable rather than merely stopped —
   `docker inspect --format '{{json .Mounts}}' forgejo-prototype` showed **both
   mounts were binds**, and `docker volume ls` had no forgejo volume, so nothing
   survived in `/var/lib/docker/volumes`. Rebuilt from
   [`../assets/05-prototype-notes.md`](../assets/05-prototype-notes.md), which
   proved to be a complete recovery spec. Now at `/var/tmp/forgejo-prototype/`
   with a re-runnable `build.sh`; **map is `#15`**, board is **project `1`**.
   See the notes' new §6.
2. **The board could not be rebuilt by scraping.** Ticket 05 built it by driving
   the web forms; that did not replay — the column form is htmx-only with no
   stable action or `_csrf` field, and `board_type=2` on the create form does
   **not** apply the kanban template (it comes up with zero columns). The cards
   were placed by **raw SQL** against `project_board` / `project_issue`. This does
   not weaken ticket 03's finding, it sharpens it: **placing a card required DB
   surgery.**
3. **Only 16 of the 56 issues are live** — 13 `open` + 3 `in-progress`; the other
   40 are `done`/`closed`/`dropped`.
   `grep -h '^status:' issues/*.md | sort | uniq -c`
4. **`~/.dotfiles/issues/` is not the only markdown tracker.** Eight more repos
   carry one — `pinecad` 18, `oppen` 15, `dockerstats` 7, `custom-keyboard` 6,
   `finance-track` 6, `pass-tui` 4, `timelog` 2, `rust-template` 1 — **~59 further
   issues**, plus `taskmaster/tickets/` (9). The ticket's "56 files" framing was
   incomplete. `for d in ~/projects/*/; do [ -d "$d/issues" ] && echo ...; done`
5. **`bin/wf` is a casualty nobody had counted** — 654 lines of Python that parses
   wayfinder maps off the filesystem and reports the frontier.
6. **There is no packaged Forgejo CLI, and the name is a trap.** Debian trixie's
   `tea` is a *graphical text editor* (v63.3.0, `tea.ourproject.org`).
   `apt-cache show tea`. Gitea's `tea` is an unpackaged Go binary.

### 1. The prototype passes — but the board is decoration

Owner's reaction: *"I think it's something I have to get used to."* Split rather
than taken at face value, because that is the same shape as the sentence that
preceded taskmaster's non-adoption. The split that resolved it:

- The owner **has** a demonstrated habit of opening self-hosted web UIs (HA
  dashboard, *arr, Jellyfin, homepage). What they have **no** track record of is
  *hand-maintaining* a tracking artifact — which is exactly what killed taskmaster.
- **The issue list is agent-fed**; the habit it asks for is *look*. That matches
  the demonstrated behaviour. **The board is hand-fed and permanently
  unautomatable**; the habit it asks for is *maintain*. That is taskmaster's
  failure mode in a nicer skin.

**Decision: the list is the tracker; the board is decoration.** No workflow,
skill, or adapter may ever depend on it. Labels, assignee and state are the source
of truth for "what am I working on", because those are what an agent can read and
write. If the board goes unused for months that is a non-event, not a failure.

### 2. Maps move too — and the assets go to a git repo, not attachments

Recommended the hybrid (maps stay markdown, execution tickets move) and it was
**declined**: *"everything goes on forgejo."*

The evidence that weakened the hybrid, found during the grilling and recorded
because it cuts against the ticket's own framing: the ticket argued maps are
*"amended in place, which git diffs beautifully"*. Measured over `map.md`'s 29
commits — **387 lines added, 34 deleted**. Maps are overwhelmingly **append-only**
amendment blocks, which is precisely the shape of an issue body plus comments, and
Forgejo timestamps and attributes each one instead of it being hand-written.
`git log --numstat --format='' -- planning/personal-forge/map.md`

Two riders that survive the decision:

- **Assets go to a private Forgejo git repo** (`projects/planning`), **not** issue
  attachments. This was not offered before the decision and it removes the one
  regression that had no workaround: assets stay greppable, diffable, and
  committed atomically with the resolution that cites them. Attachments are
  opaque blobs with no diff and no grep.
- **The privacy win is future-only.** The 56 issues and all three maps are in
  `Stromdahl/configs`' public git history across 87 commits. Deleting them from
  the tip does not unpublish them, short of a history rewrite that breaks every
  clone. *One place to look* is the real and sufficient justification; the
  visibility argument must not be carried forward as if it closed the barn door.

### 3. All 56 migrate, closed ones included

Not a line in the sand. A tracker whose history lives in a different system than
its present is two places, not one — and the closed issues are exactly what gets
dug up six months later. Cost is near zero: `import.py` already parses this
frontmatter correctly and was proved on 14 of them. The markdown files are
**deleted** in the same commit that records the migration, so there is one live
copy and no drift.

### 4. Status vocabulary: open / claimed / done / dropped

`closed` is **not a state** — there is exactly one (`043-migrate-profilarr-v2.md`)
and its body opens with "Done." Folded into `done`. `dropped` **is** real and both
instances mean *superseded*.

| today | Forgejo |
|---|---|
| `open` | open, unassigned |
| `in-progress` | open **+ assigned to `ms`** |
| `done` | closed |
| `closed` | closed *(folded)* |
| `dropped` | closed **+ label `status/dropped`** |

**`in-progress` is renamed `claimed`, and is expressed as an assignee, never a
label.** Ticket 05 called the assignee mapping "a coincidence, not a model" — true,
but it is a coincidence that fixes something real. The README's coordination rule
is *"grab work by flipping `status`"*: a file edit plus a commit. The owner runs
many Claude sandboxes concurrently (`feedback_concurrent_claude_sessions`), so two
sessions can both grab an issue and collide in git. **Assignee is one atomic
server-side call.** The tracker's weakest mechanism becomes its strongest, and it
is the same signal wayfinder already reads as a claim. The rename matters because
the state is a statement about *who holds it*, not a description of the work.

### 5. Labels: slash form, exclusive, org-level only *(owner delegated: "its your pick")*

`exclusive: true` is a **silent no-op on `:`-separated labels** — `/` is the scope
separator. Adopted the slash form to take the enforcement:

| today | Forgejo | exclusive |
|---|---|---|
| `epic:services` | `epic/services` | yes |
| `priority:high` | `priority/high` | yes |
| — | `status/dropped` | yes |
| — | `wayfinder/type/<type>` | yes |
| — | `wayfinder/effort/<slug>` | yes |
| `needs-human` | `needs-human` | n/a, unscoped |

Every scope is genuinely single-valued, so exclusivity is free correctness that no
markdown frontmatter ever gave. Renaming is free because the migration writes the
labels anyway. Two riders:

- **Define every label at org level only, never at repo level.** Same-named org and
  repo labels *both* attach silently, duplicating the pill and double-counting
  every `labels=` query (notes §3.2).
- **Epics stay labels, not milestones.** Milestones are repo-scoped and ticket 03
  found the dashboard has **no milestone filter at all** — a milestone would break
  the cross-project view this migration exists for.

### 6. The `issue-tracker` spec survives but loses default status

1. **Not deprecated.** Its own README already documents this exact escape hatch —
   *"no cross-repo views, no notifications, no rich linking. For projects where
   those matter, use GitHub Issues / Linear / etc."* This migration is the spec
   working, not failing. It stays correct for offline work, forks, and repos that
   want issues to travel with the code.
2. **It stops being the default.** `rust-template` ships an `issues/` dir, so every
   new project currently inherits the markdown tracker. That flips to **forge-first**
   — which graduates the map's *new-project convention* fog.
3. **The other seven migrate lazily, per repo, as each lands on the forge.**
   `pinecad`'s 18 have no bearing on `~/.dotfiles`' 56; coupling them turns a
   scripted afternoon into a project. `taskmaster/tickets/` migrates only if
   taskmaster survives, which is still fog. **`lumin/.scratch/` stays** — its 65
   files are design docs and specs, a different artifact class, not issues.

   **`finance-track` comes over with the rest** — verified against ticket 06 rather
   than assumed: it is in the twenty, `active`, in the *"already on GitHub (5)"*
   group. It is neither one of ticket 08's four executing carve-outs nor one of the
   71 local-less repos, so nothing holds it back.

4. **Archived repos reject issue creation — so import first, archive second.**
   Measured on the live prototype against `oppen`, which ticket 06 archives and
   which holds **15 issues, the second-largest tracker in the set**:
   ```
   curl -s -H "Authorization: token $(cat /var/tmp/forgejo-prototype/.token)" \
     -X POST -H 'Content-Type: application/json' -d '{"title":"archived write probe"}' \
     http://localhost:3210/api/v1/repos/projects/oppen/issues
   → HTTP 423  {"message":"<Repository 4:projects/oppen> is archived"}
   ```
   A hard ordering constraint on the lazy per-repo migration, not a preference:
   **create the repo → import its issues → *then* set `archived`.** If a repo is
   already archived on the forge, un-archive, import, re-archive.

### 7. `bin/forge` plus a CLI cookbook

1. **Write `bin/forge`**, in the shape of `bin/ha` / `bin/unifi` / `bin/kb`. Not
   Gitea's `tea`: an unpackaged Go binary outside the dotfiles module system is a
   worse dependency than a wrapper the repo owns, and the name collides with a
   Debian package. The wrapper also keeps the API token in one place, out of every
   transcript.
2. **`issue-tracker-forgejo.md` is a CLI cookbook against `bin/forge`**, matching
   the other three adapters (~45 lines, one tool apiece). An HTTP cookbook would
   put raw `curl` with inline headers into every skill invocation — precisely what
   `feedback_extend_wrapper_first` exists to prevent.
3. **`bin/wf` gains a third dialect rather than dying.** Forgejo for the
   `.dotfiles` maps, filesystem for the **work** ones (`~/notes/.scratch`,
   `~/yggio/…`), which are explicitly out of scope and stay markdown.

   > ⚠️ **Gap in this resolution, flagged rather than papered over.** The session
   > first wrote "and vault ones" into the out-of-scope half. That was an
   > **assumption, not a decision.** `bin/wf` reports **5 further maps and 50
   > tickets under `~/vault/projects/`** — `diy-speakers`, `finance-rebuild`,
   > `not-so-smart-smartwatch`, `strength-and-weight`, `vardepapperskredit` — and
   > those are **personal**, not work. `diy-speakers` is literally one of ticket
   > 06's twenty repos. Under "everything goes on Forgejo" they have at least as
   > strong a claim as `planning/` does. **Undecided; see the map's fog.**
4. **Skills that move:** `triage` and `code-review` (both pin the tracker today),
   plus **wayfinder's tracker doc gains a Forgejo "Wayfinding operations"
   section** — now mandatory, not optional: maps are issues, and without it no
   future wayfinder session can find one.
5. **Knowingly a divergence.** The adapters live in `setup-matt-pocock-skills/`,
   verbatim upstream since 2026-07-11 (`reference_skills_upstream_mattpocock`). A
   fourth adapter is a deliberate local fork of that directory.

### Riders onto other tickets

- **[11](11-persistence-backup-and-pins.md) becomes materially more load-bearing.**
  Today the tracker is markdown in git — distributed, and on every clone. After
  this migration **Forgejo's SQLite is the only copy of the tracker and of every
  wayfinder map.** Ticket 11's SQLite-vs-Postgres and backup-machinery decision
  now protects the planning record, not just repo metadata. A torn SQLite backup
  loses the issues; the git repos would survive it.
- **[10](10-forge-sync-contract.md) inherits a third source.** Ticket 08 already
  gave it a two-source restore (`configs` from GitHub, the 20 from Forgejo). Add
  the **`projects/planning` assets repo** — and note that a fresh-machine restore
  now recovers *code* but not *tickets*, since those live in the DB rather than in
  any repo.

---

## Scoping amendment (2026-08-24, by [ticket 13](13-vault-personal-maps.md))

**"Everything moves, maps included" is scoped to `~/.dotfiles`** — the repo this
ticket surveyed. It does **not** reach `~/vault`.

[Ticket 13](13-vault-personal-maps.md) decided the **five personal wayfinder maps in
`~/vault/projects/` (50 tickets) stay markdown in the vault**, because their tickets
are link-woven into live vault content that is not moving: **16 `[[tasks]]`**
wikilinks into the daily task board, **14 into `health/`**, and ~25 relative links
into sibling `../research/`, `../design/`, `../food-log.md`. Forgejo resolves none of
those forms, and the targets cannot follow.

Two consequences for anyone implementing this ticket:

1. **A migration script must not walk `~/vault`.** Its scope is `~/.dotfiles/issues/`
   (56 files), `~/.dotfiles/planning/` (the three maps), and the eight repo `issues/`
   dirs — nothing under `~/vault/projects/`.
2. **`bin/wf` gains a THIRD dialect, it does not swap its second.** This ticket's
   "`bin/wf` gains a Forgejo dialect" is an **addition**. The **YAML frontmatter
   dialect must be kept** — the vault's `tickets/` are still its only user, and
   `~/vault/projects` stays a first-class `wf` root alongside `~/notes/.scratch`
   (work, out of scope, prose dialect).

After the migration there are **two** personal ticket homes by design, and `bin/wf`
is the thing that spans them. That is not a contradiction of this ticket — the
discriminator 13 established is *whether the tickets' outbound links have anywhere to
land*, not public-vs-private and not markdown-vs-service.
