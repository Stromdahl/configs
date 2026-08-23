# Tracker cutover: what moves into Forgejo Issues, and what stays markdown?

Type: grilling
Status: open
Blocked by: 03, 05

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
