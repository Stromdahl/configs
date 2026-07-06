# Issues

An **issue** is one independently-grabbable unit of work — a thin vertical slice
that cuts end-to-end through every layer it touches and is independently demoable
or verifiable when done.

- **Issues say what & why.** They deliberately carry **no file paths** — they
  outlive the work, and paths go stale. The *how* (paths, symbols, commands) is
  frozen later into a `tasks/NNN-slug.md` execution brief (see the `to-tasks`
  skill).
- **One file per issue:** `issues/NNN-slug.md`, `NNN` zero-padded and monotonic.
- **`status` is the single source of truth.** Files **never move** — an issue's
  lifecycle is its `status` field, not its location. This is the only coordination
  concurrent sessions need: grab work by flipping `status`.
- **Epics are labels**, not directories. An issue belongs to an epic via an
  `epic:<slug>` label.

## Frontmatter

```yaml
---
title: <imperative one-line summary>
status: open          # open | in-progress | done
priority: medium      # high | medium | low
created: YYYY-MM-DD    # from `date +%F`
closed: null           # YYYY-MM-DD when status: done, else null
labels: [epic:<slug>]  # epic membership + any other tags
---
```

## Body

- `## Description` — the end-to-end behavior the slice delivers, and why. No file
  paths. Express dependencies inline as a line:
  ``Depends on `issues/NNN` (reason).``
- `## Acceptance criteria` — a `- [ ]` checklist of externally-verifiable
  outcomes (what a reviewer checks, not implementation steps).

## Lifecycle

1. **Grab:** pick an issue whose `status` is `open` and whose `Depends on` issues
   are all `done`. Set its `status` to `in-progress` and commit that immediately
   on `main` (queue bookkeeping is exempt from "branch first").
2. **Work + verify**, then commit the change only once the acceptance criteria
   pass.
3. **Close:** set `status: done` and `closed: <date>`, and commit. The file stays
   where it is.
4. **Blocked by something needing the user's hands?** Note it in the issue and
   stop — don't work around it.

## Conventions are create-only here

`to-issues` only *creates* issues from a plan; it never closes, renumbers, or
moves them. A `gh`/Linear backend is possible future work, not currently used.
