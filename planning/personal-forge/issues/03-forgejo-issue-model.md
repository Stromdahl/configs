# Forgejo's issue model — can it carry the tracker *and* wayfinder maps?

Type: research
Status: resolved

## Question

The tracker decision is made (Forgejo Issues win; taskmaster loses). What is not
established is whether Forgejo's issue model can actually express what the current
markdown tracker and the agent skills rely on.

Establish, from Forgejo's docs and API reference for the current stable release:

1. **Blocking dependencies.** Does Forgejo have native issue dependencies
   ("blocked by" / "blocks"), across repos as well as within one? **Wayfinder
   requires this** — it is how the frontier is computed and rendered.
2. **Parent/child (sub-issues).** Does Forgejo support a parent issue with child
   issues? **Wayfinder's map is a parent issue and its tickets are child issues.**
   If this is missing, say what the closest expressible substitute is.
3. **Cross-repo views.** Is there a single view of open issues across every repo
   (the thing the in-repo markdown tracker explicitly cannot do, per
   `~/projects/issue-tracker/README.md`)? Global issue search, filters, and
   whether **kanban boards / projects** exist and are per-repo or org-wide.
4. **The API surface an agent adapter needs** — create/read/update/close an issue,
   labels, comments, assignees, dependencies, and *listing* by state+label+repo.
   Token scopes required. Rate limits, if any.
5. **Attachments** — can a wayfinder *asset* (a research markdown file) be attached
   to an issue, or does it need to stay in-repo and be linked?

Then answer the design question this feeds: **what would
`issue-tracker-forgejo.md` have to say?** The existing adapters live at
`~/.claude/skills/setup-matt-pocock-skills/issue-tracker-{github,gitlab,local}.md`
— there is **no Forgejo one**, and every skill (`/wayfinder`, `/to-tickets`,
`/triage`, `/implement`, `/pickup`) resolves tickets through that doc. Read
`issue-tracker-github.md` and `issue-tracker-local.md` and report which sections
map cleanly, which need a workaround, and which cannot be expressed at all.
Include the **"Wayfinding operations"** section specifically.

Do **not** write the adapter — that is execution. Report what it would contain.

Capture findings as `../assets/03-forgejo-issue-model-research.md`.

## Answer

Resolved 2026-08-23. **Verdict: GO-WITH-WORKAROUND.** Full findings, with sources
and live verification against codeberg:
[`../assets/03-forgejo-issue-model-research.md`](../assets/03-forgejo-issue-model-research.md).
The verdict rests on **v15 (the LTS line ticket 01 chose)**.

1. **Blocking dependencies — native, cross-repo, fully API-driven. ✅** The
   load-bearing capability, and Forgejo is **better than the GitHub adapter's own
   instruction** (no database-id lookup — the human-visible index works) and
   **better than GitLab free** (no Premium gate). `POST
   /repos/{o}/{r}/issues/{child}/dependencies`. Cross-repo works with
   `ALLOW_CROSS_REPOSITORY_DEPENDENCIES` (default on). Two things the adapter must
   handle: the `dependencies`-vs-`blocks` **direction inversion**, and the per-repo
   `internal_tracker.enable_issue_dependencies` flag — default on, and both readable
   and settable via the repo API, so an adapter can **pre-flight** instead of
   discovering it through a failed POST.
2. **Parent/child sub-issues — absent, and decisively so. ❌** The one hard gap.
   Tracking issue forgejo#5448 is still open, **all three implementation attempts
   are closed unmerged**, and there is nothing in the `16.0.0-dev` swagger, the
   `Issue` struct, or the locale strings. Not "coming soon" — absent.
   **Substitute (and it is not novel):** label the map `wayfinder:map`, label
   children `wayfinder:effort:<slug>` + `wayfinder:<type>`, and put
   `Part of #<map>` at the top of each child body. That is **GitLab's primary
   documented shape and GitHub's own documented fallback** — already proven in use.
   A task list in the map body carries **order and human legibility only**: task
   counts are a regex over literal `- [ ]` characters in the parent's body, are
   **not exposed in the API at all**, and **closing a child does not tick its box**.
   Explicitly rejected: using dependencies for containment — its semantics are
   "blocks", it would forbid closing the map before its children, and it would
   pollute the very relation the frontier reads.
3. **Cross-repo views. ✅ and a bonus:** `GET /repos/issues/search?labels=wayfinder:map&state=open`
   is a **one-call, cross-repo list of every open map** — neither `gh` nor `glab`
   manages that in one call. **But kanban boards are a dead end for automation:**
   zero `/projects` API paths, no `project` field on `Issue`, no project filter on
   issue search. A board is a fine *human* view — probably the very "UI I actually
   open" that justified the tracker decision — but **no agent skill can read or
   write it, permanently.** Design accordingly.
4. **API surface. ✅ sufficient**, no rate limits found (established by absence in
   primary sources, not by an upstream statement). Six footguns documented; the two
   that bite hardest: `labels=` is **OR**, so narrowing by effort *and* type needs
   client-side filtering, and **issues and PRs share one number space**.
5. **Attachments. Capable, but the recommendation is link, don't attach** — keeps
   assets in-repo and greppable.
6. **Frontier query — N+1, but cheap.** No dependency-summary endpoint: list the
   map's children by label, drop the assigned ones, then one
   `GET …/issues/{n}/dependencies` per remaining child. ~11 calls for a ten-ticket
   map, and nothing to rate-limit against.
7. **A real behavioural difference to know about:** Forgejo **refuses to close** an
   issue that still has open blockers (HTTP 412 `DependenciesLeft`). Arguably a
   feature.

**Placement, which is the useful framing for ticket 07:** Forgejo sits **strictly
between GitHub and GitLab-free** — better than GitLab-free on the load-bearing
capability (native, unpaid, cross-repo dependencies), worse than GitHub on hierarchy
(no sub-issues at all), at parity or better on everything else. That reframes 07
from *"does this work?"* to **"is the labelled-map + `Part of #<map>` convention
acceptable?"** — a convention question, not a capability question.

**Cannot be expressed at all:** parent/child hierarchy; anything board-driven
(human-only, forever); and — worth noting — **an adapter here is an HTTP cookbook,
not a CLI cookbook** like the existing three, unless this repo writes a wrapper
first (cf. `feedback_extend_wrapper_first`).
