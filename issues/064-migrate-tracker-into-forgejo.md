---
title: Migrate the markdown tracker and the wayfinder maps into Forgejo
status: open
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

The repo's 56 markdown issues and its three wayfinder maps become Forgejo issues, with
the label vocabulary defined first, and the markdown files deleted **in the same commit
that records the migration** so there is one live copy and no drift. Depends on
`issues/063`.

This is step 4 of the migration ordering and the **last** step by construction. Nothing
earlier in the epic may delete the markdown tracker or the planning directory, because
this map's own execution issues would be stranded with nowhere to live. The map itself
moves here, mid-flight.

**All 56 migrate, closed ones included.** Only sixteen are live; the rest are done or
dropped. A tracker whose history lives in a different system from its present is two
places, not one — and the closed ones are exactly what gets dug up six months later.

**The status vocabulary changes shape, and one change is a real fix rather than a
rename.** Four states: open, claimed, done, dropped. One current state folds away
(there is exactly one instance of it and its body opens with "Done."). Dropped is real
— both instances mean *superseded* — and becomes a label on a closed issue. And
`in-progress` becomes **claimed, expressed as an assignee, never a label**: the current
coordination rule is "grab work by flipping status", which is a file edit plus a commit,
and many agent sessions run concurrently, so two can both grab an issue and collide in
git. An assignee is one atomic server-side call. The tracker's weakest mechanism becomes
its strongest, and it is the same signal the wayfinder tooling already reads as a claim.

**Labels use the slash form and are exclusive.** Exclusivity is a silent no-op on
colon-separated labels — slash is the scope separator — so the slash form is adopted in
order to take the enforcement. Every scope here is genuinely single-valued, so
exclusivity is free correctness that frontmatter never gave. Two riders: define every
label at **org level only**, because same-named org and repo labels both attach silently
and double-count every label query; and epics stay **labels, not milestones**, because
milestones are repo-scoped and the dashboard has no milestone filter at all, which would
break the cross-project view this migration exists for.

**Hierarchy does not exist and cannot be faked with dependencies.** There are no
sub-issues, decisively — the upstream tracking issue is open and all three
implementation attempts closed unmerged. The substitute is the documented shape on both
comparable platforms: label the map, label its children with the effort and type scopes,
and put a "Part of #map" line at the top of each child body. A task list in the map body
carries order and human legibility **only** — its counts are a regex over literal
characters, are not exposed in the API, and closing a child does not tick its box.
Using dependencies for containment is explicitly rejected: the semantics are "blocks",
it would forbid closing the map before its children, and it would pollute the very
relation the frontier query reads.

Real blocking dependencies **are** native, cross-repo and fully API-driven, and are
better here than on either comparable platform. Note that the forge refuses to close an
issue with open blockers — arguably a feature.

The kanban board is decoration. No workflow, skill or adapter may ever depend on it:
there are zero project API paths, no project field on an issue and no project filter on
issue search, so no agent can read or write it, permanently. Labels, assignee and state
are the source of truth.

Scope boundary, decided explicitly: the migration **must not walk the personal vault**.
Its five maps and fifty tickets stay markdown, because their tickets are link-woven into
live vault content that is not moving. Nor does this ticket touch the eight other repos'
markdown trackers — those migrate lazily, per repo, as each lands on the forge.

The privacy win is future-only and must not be oversold: everything here is already in
public git history across 87 commits, and deleting it from the tip does not unpublish
it. *One place to look* is the real and sufficient justification (see `issues/067` for
the security half).

## Acceptance criteria

- [ ] Every label in the vocabulary exists at org level only, in slash form, with
      single-valued scopes marked exclusive, and no duplicate repo-level labels.
- [ ] All 56 issues exist on the forge with their titles, bodies, state, epic and
      priority preserved, and the folded state no longer appears anywhere.
- [ ] Issues that were in progress are open **and assigned**; dropped ones are closed
      and carry the dropped label.
- [ ] All three wayfinder maps exist as issues, each child labelled and carrying its
      "Part of" line, and each map's assets are reachable from the assets repo.
- [ ] Blocking relationships that existed as prose dependencies are native dependency
      links, and a frontier query returns the same frontier the markdown tooling did.
- [ ] The markdown issues and planning directory are deleted in the same commit that
      records the migration, and nothing in the repo still reads them.
- [ ] Nothing under the personal vault was read or modified.
