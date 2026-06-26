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
is still open, and every issue it `Depends on` is closed. "Next" = the lowest such
`NNN`. One task per run — do **not** auto-chain into the next; to run several, use a
fresh session or an isolated worktree per task, never one marathon.

## Procedure

1. **Read ground truth first.**
   - **`issues/README.md`** — how `status` and closing work in this repo.
   - **`tasks/README.md`** — the pickup protocol you will follow. It is authoritative;
     this skill only drives it.
   - **The task brief** for the in-scope task, and **its source issue** (ACs, labels,
     `Depends on`). Confirm the issue is open and its dependencies are closed.

2. **Select the task.** Default: the next ready task (above). Named: that one — but if
   it's already in-progress/closed, blocked, or has unmet dependencies, **say so and
   stop**, don't force it.

3. **Claim it — best effort, fast.** Re-read the source issue's `status` *immediately*
   before claiming; if still open, set it to in-progress and **commit that right away,
   on `main`** (bookkeeping is exempt from "branch first"). This commit *is* the grab.
   This is best-effort, not a hard lock: if a concurrent session already flipped it, or
   you later hit a status conflict on pull/push, **yield** — pick the next ready task
   (default scope) or stop (named scope).

4. **Execute from the brief.** Grep the brief's grep-stable anchors to locate the entry
   points, mirror the named prior art, follow the Steps, and stay inside the brief's
   Out-of-scope boundaries. Do the code work on whatever git workflow this repo uses
   (straight to `main` where that's the repo's norm; else a branch) and commit it as a
   coherent, atomic change.

5. **Verify — don't claim done on faith.** Run the brief's exact Verify commands and
   tick every acceptance criterion. If verification fails and you can't fix it within
   the brief's scope, **leave the issue in-progress, report the failure, and stop** —
   never close a task whose ACs don't pass.

6. **Close, or flag a blocker.**
   - All ACs pass → set the issue's `status` to done/closed per `issues/README.md` and
     commit on `main`.
   - A step needs the **user's own hands** (physical access, a secret you lack, an
     external-account/dashboard action, an approval, manual/hardware testing) → flag
     the **issue** (blocked / needs-human, per the repo idiom) with what's needed, and
     **stop**. Don't work around it or fake completion.

7. **Report.** What you did, the commits made, AC status, and any follow-up or blocker —
   concisely, since the durable record is the issue and the commits.

## Guardrails

- **Respect dependencies.** Never start a task whose `Depends on` issues aren't closed.
- **Claiming is best-effort, not a lock.** File+git claims can race across concurrent
  sessions; the re-check-then-commit in step 3 minimises it, but on conflict you yield.
  Say this plainly rather than implying a guarantee.
- **Don't close what you can't verify.** No verify commands in the brief, or they fail
  → report and stop; closing stays gated on green ACs.
- **Commit proactively; push is ask-first.** Land the work and the status commits
  (status always on `main`), but **do not push** unless the user asks — per global git
  rules.
- **Blocked → flag the issue and stop.** A human-hands blocker belongs on the issue
  (the surface the user watches), never silently worked around.
- **Nothing ready?** No task whose issue is open with deps satisfied — say so and stop.
  If issues lack briefs, suggest `/to-tasks` first.

## Composition

`to-tasks` writes briefs; `grab` consumes them. Both treat the issue's `status` as the
single source of truth and the repo's `tasks/README.md` as the protocol of record.
`grab` does the work and the bookkeeping but never authors briefs or decomposes plans —
that's `to-tasks` and `to-issues`.
