# Tasks

A **task** is an execution brief frozen from an **issue** — the concrete pointers
an agent needs to do the work from a cold start, at low token cost. The expensive
discovery was done once, up front; a task is the distilled result.

- **Issues say what & why** and deliberately carry *no* file paths — they outlive the
  project, and paths go stale. **Tasks say how** and deliberately bake paths in —
  they're consumed immediately, while fresh.
- One task per issue: `tasks/NNN-slug.md` **mirrors the issue's `NNN` and slug**, so
  task ↔ issue traceability is trivial.
- The **issue's `status` is the single source of truth.** There is no claim, lock, or
  owner field on a task — an agent grabs work by flipping the *issue's* status. That
  is the only coordination concurrent sessions need.

## Brief format

Each `tasks/NNN-slug.md` contains, in order:

- **Source issue** — `issues/NNN-slug.md` and a one-line restatement of the goal.
- **Pickup protocol** — the first/last/blocked actions (see below).
- **Suggested agent** — model/agent tier and why (e.g. "Sonnet; mechanical").
- **Human steps / blockers** — anything needing the user's own hands (physical
  access, a secret the agent lacks, an external-account/dashboard action, an
  approval, manual/hardware testing). Omit only if there are genuinely none.
- **Entry points** — the files and the **symbols** (functions, types, headings) to
  touch.
- **Prior art to mirror** — the existing file(s) whose shape/pattern to copy.
- **Steps** — a short numbered plan of the change (the *how*, not full code).
- **Verify** — the exact test / lint / build / run commands, and what passing means.
- **Acceptance criteria** — the issue's ACs as a `- [ ]` checklist, verbatim.
- **Out of scope / don't touch** — explicit boundaries.

## Anchors are grep-stable, never line numbers

Entry points reference things `grep` finds — a symbol name, a heading, a unique
string, a prior-art file — **not** raw line numbers. Line numbers drift the moment a
sibling task edits the same file, silently invalidating every later brief. A
grep-stable anchor costs the agent one cheap search and survives that drift.

## Pickup protocol (for the executing agent)

The task file is your entire prompt — execute from it alone.

1. **Pick** a task whose source issue is still open (status not in-progress / done).
   Issue status is the only coordination; you'll never collide with another session.
2. **Claim it — first action:** set the source issue's `status` to in-progress and
   **commit that immediately, directly on `main`.** Status is queue bookkeeping, not
   feature work — it's exempt from "branch first", and committing it now is what keeps
   the queue accurate for every other session.
3. **Do the work** per the brief; grep the anchors to locate them.
4. **Verify:** run the brief's Verify commands and tick every acceptance criterion.
5. **Close it — last action:** set the issue's `status` to done/closed per this repo's
   `issues/README.md` spec, and commit (again, fine on `main`).
6. **Blocked by something needing the user's hands?** Flag the **issue**
   (blocked / needs-human, per this repo's idiom) and **stop** — don't work around it.
   The user watches the issue queue, so that's where a blocker has to show.
