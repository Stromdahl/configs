# Tracker cutover: what moves into Forgejo Issues, and what stays markdown?

Type: grilling
Status: open
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
