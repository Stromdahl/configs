---
title: Point the agent toolchain at Forgejo
status: open
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

The skills and tools that read or write the tracker stop assuming markdown files and
start talking to the forge. Depends on `issues/062` and `issues/064` — there is nothing
to point at until the issues are actually there.

Four pieces:

- **A tracker adapter for Forgejo**, written as a **CLI cookbook over the house
  wrapper**, matching the three existing adapters in size and shape — roughly one tool
  apiece, tens of lines. Deliberately not an HTTP cookbook: that would put raw requests
  with inline auth headers into every skill invocation, which is precisely what the
  "extend the wrapper first" rule exists to prevent.
- **The two skills that pin the tracker today** — triage and code-review — move over.
- **The wayfinder tracker doc gains a "Wayfinding operations" section**, and it is
  **mandatory, not optional**: maps are issues now, and without it no future wayfinding
  session can find one.
- **The wayfinder frontier tool gains a third dialect, it does not swap its second.**
  Forgejo for this repo's maps; the existing frontmatter dialect **stays**, because the
  personal vault's tickets are still its only user and the vault stays a first-class
  root; the prose dialect for work maps is untouched and out of scope. After the
  migration there are two personal ticket homes **by design**, and this tool is the
  thing that spans them.

Knowingly a divergence: these adapters live in a directory that has been kept verbatim
from upstream. A fourth adapter forks it deliberately. Say so where a future reader will
trip over it.

## Acceptance criteria

- [ ] A Forgejo tracker adapter exists in the same shape and size class as the existing
      three, expressed entirely in terms of the house wrapper — no raw HTTP.
- [ ] Triage and code-review operate against the forge end to end, demonstrated on a
      real issue.
- [ ] The wayfinder tracker doc carries a Wayfinding operations section covering how a
      map and its children are found, claimed and resolved on the forge.
- [ ] The frontier tool reports correctly for a forge-hosted map **and** still reports
      correctly for a vault map in the frontmatter dialect and a work map in the prose
      dialect.
- [ ] The upstream-fork divergence is recorded where someone re-syncing that directory
      will see it.
