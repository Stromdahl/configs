---
name: grab
description: Claim the next ready task off this repo's tasks/ queue (or a named one) and execute it end-to-end following that repo's tasks/README pickup protocol — flip the source issue to in-progress and commit, do the work from the brief, run its verify commands, tick the acceptance criteria, then close the issue. If a step needs the user's own hands it flags the issue and stops instead of faking completion. The consume end of the to-tasks pipeline. Type /grab for the next ready task, or /grab <issue> for a specific one.
disable-model-invocation: true
---

# Grab

Claim a task off the `tasks/` queue and execute it. This is the **consume** end of
the pipeline: `grilling` → `to-prd` / `to-issues` → `to-tasks` → **`grab`**. `to-tasks`
froze an issue into a brief; `grab` runs that brief.

Your ground truth is the **task brief** plus the repo's **`tasks/README.md` pickup
protocol** — follow them, don't improvise. The brief was built so a *cold* agent can
execute from it alone, so **run this from a lean context**: a fresh session, or a
spawned executor subagent. Dragging a marathon session's context into the work throws
away the token win the brief exists to deliver.

## Scope (one task per run)

- **(none)** → the **next ready task** (default).
- **`<issue>`** (e.g. `issues/007`, a number, or a slug) → that specific task.

A task is **ready** when it has a `tasks/NNN-*.md` brief, its source issue's `status`
is still open, and every issue it `Depends on` is `done`. "Next" = the lowest such
`NNN`. One task per run — do **not** auto-chain into the next; to run several, use a
fresh session or an isolated worktree per task, never one marathon.

## Procedure

1. **Read ground truth first.**
   - **`issues/README.md`** — how `status` and closing work in this repo.
   - **`tasks/README.md`** — the pickup protocol you will follow, step for step. It is
     authoritative; this skill adds task *selection* and a hardened claim, then runs it.
   - **The task brief** for the in-scope task, and **its source issue** (ACs, labels,
     `Depends on`).

2. **Select the task.** Default: the next ready task (above). Named: that one — but if
   it's already in-progress/done, blocked, or has unmet dependencies, **say so and
   stop**, don't force it.

3. **Claim it — best effort, fast.** Re-read the source issue's `status` *immediately*
   before claiming; if still open, run the protocol's claim step (set in-progress,
   commit on `main`) right away. This commit *is* the grab — but it's best-effort, not
   a hard lock: if a concurrent session already flipped it, or you later hit a status
   conflict on pull/push, **yield** — pick the next ready task (default scope) or stop
   (named scope).

4. **Run the rest of the pickup protocol exactly as `tasks/README.md` specifies** —
   work from the brief, **verify before committing the code, commit only on green**,
   then close the issue; or, on a verify failure or a human-hands blocker, flag/stop
   per that file. Don't deviate from the repo's protocol — where this skill and that
   file differ, **the repo's file wins**.

5. **Report.** What you did, the commits made, AC status, and any follow-up or blocker —
   concisely, since the durable record is the issue and the commits.

## Guardrails

- **Respect dependencies.** Never start a task whose `Depends on` issues aren't `done`.
- **Claiming is best-effort, not a lock.** File+git claims can race across concurrent
  sessions; the re-check-then-commit in step 3 minimises it, but on conflict you yield.
  Say this plainly rather than implying a guarantee.
- **Verify gates both the code commit and the close.** Never commit the change or close
  the issue on red — on failure leave the change uncommitted and the issue in-progress,
  report, and stop.
- **Commit proactively; push is ask-first.** Land the work and the status commits
  (status always on `main`), but **do not push** unless the user asks — per global git
  rules.
- **Nothing ready?** No task whose issue is open with deps satisfied — say so and stop.
  If issues lack briefs, suggest `/to-tasks` first.

## Composition

`to-tasks` writes briefs; `grab` consumes them. Both treat the issue's `status` as the
single source of truth and the repo's `tasks/README.md` as the protocol of record.
`grab` does the work and the bookkeeping but never authors briefs or decomposes plans —
that's `to-tasks` and `to-issues`.
