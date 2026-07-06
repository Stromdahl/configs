---
name: to-tasks
description: Turn an issue into a self-contained execution brief a cold agent can run from alone — grep-stable entry points, prior-art to mirror, exact verify commands, don't-touch boundaries, and the issue's acceptance criteria as a checklist. Discovery runs once in a throwaway Explore subagent so the executing agent's context holds only the distilled conclusion and stays token-lean. The execution-prep sibling of /to-issues (which emits work items *without* paths because they go stale; this freezes the paths in, while fresh, because the brief is consumed immediately). Type /to-tasks to brief the earliest open issue without a task, /to-tasks <issue> for a named one, or /to-tasks all to brief every open issue at once.
disable-model-invocation: true
---

# To tasks

Turn an **issue** into a **task** — a self-contained execution brief that a cold
agent with zero conversation context can run from alone, at low token cost.

This is the execution-prep stage of the pipeline: `grilling` → `to-prd` /
`to-issues` → **`to-tasks`**. Where `to-issues` deliberately *omits* file paths
(they go stale over a project's life), `to-tasks` deliberately *bakes them in* —
because a task is consumed immediately, while fresh, by an agent that would
otherwise re-pay the discovery cost on every turn of its loop.

**The token win is the whole point, and it is specific:** pre-baking a brief does
*not* lower the cost of one pickup — it adds the authoring cost. The saving is that
the expensive *discovery* runs once in a **throwaway `Explore` subagent** whose
context is discarded, leaving the executing agent's lean context holding only the
*distilled conclusion* — not the exploration trace. So delegating discovery to
`Explore` (step 3) is the **core** of this skill, not an optimization.

**The design test for every brief:** the task file is the executing agent's entire
prompt. If a cold agent couldn't execute from it alone, the brief is incomplete.

## Scope (one issue per run; `all` for a whole queue)

The argument selects what a run briefs:

- **(none)** → the **earliest open issue that has no task yet** (default).
- **`<issue>`** (e.g. `issues/007`, a number, or a slug) → that issue.
- **`all`** → every open issue without a task, in one pass.

An issue is "already briefed" when `tasks/` holds a task for its `NNN`. Check that
first, so re-running a scope is **idempotent** and never dups.

## Procedure

1. **Read ground truth first — never improvise from memory.**
   - **The tracker spec:** read *this repo's own* `issues/README.md` to learn how
     status and IDs work here (the `status` field is the source of truth for what's
     open / grabbable). Follow that file; do not assume one.
   - **The source issue(s):** read the in-scope `issues/NNN-*.md` — its
     `## Description`, `## Acceptance criteria`, labels, and any `Depends on` lines.
   - **The decisions:** read the repo's ADRs and glossary, wherever it keeps them
     (`adr/`, `docs/adr/`, `docs/decisions/`, … — the dirs `decision-docs` detects);
     write the brief in that vocabulary and never contradict a locked decision.
   - **Existing tasks:** scan `tasks/` for which issues already have a task and for
     the brief shape in use — that repo's `tasks/README.md` is the format authority.
     If there is **no `tasks/` dir**, *offer to adopt it* — `mkdir tasks/` and copy
     the canonical spec shipped beside this skill,
     `~/.claude/skills/to-tasks/tasks-README.md`, to `tasks/README.md` — but don't
     impose it.

2. **Triage out trivial issues.** If the issue is a one-line / one-file change an
   agent could do without discovery, **a brief costs more than it saves** — say so
   and skip it (or point at the issue directly). Brief only issues with real
   surface area to map.

3. **Delegate discovery to a fresh `Explore` subagent — one per issue.** This is the
   core. Spawn an `Explore` agent with the issue text and ask it to return *only the
   distilled conclusion* needed to execute:
   - **Entry points** — the files and the **symbols** (functions, types, headings)
     to touch, expressed grep-stably (see Guardrails), never as raw line numbers.
   - **Prior art to mirror** — the existing file(s) whose shape/pattern the change
     should copy.
   - **Verify commands** — the *exact* test / lint / build / run commands this repo
     uses (from its `package.json`, `Makefile`, CI config, AGENTS.md, etc.).
   - **Gotchas & boundaries** — anything adjacent the agent must *not* touch.
   - **Human hands needed?** — whether any part can't be done by an agent alone:
     physical access, a secret/credential it lacks, an external-account or dashboard
     action, an approval, or hardware/manual testing.
   Use a **separate** subagent per issue and do not let the authoring session
   accumulate their context across issues — that re-introduces the marathon cost
   this skill exists to avoid.

4. **Distill into the brief.** Compress the `Explore` return into the brief shape the
   repo's `tasks/README.md` defines (the canonical spec; see below). Carry the issue's
   acceptance criteria across verbatim as a checklist.
   Suggest an agent tier (cheap model for mechanical work; escalate only for genuine
   reasoning). Keep it tight — a brief is a launchpad, not a transcript. **If
   discovery flagged human hands as needed, also flag it on the issue** (see
   Guardrails) — the user watches the issue, not the brief.

5. **Write `tasks/NNN-slug.md`, mirroring the issue ID, then report.** Reuse the
   issue's `NNN` and slug so task ↔ issue traceability is trivial. Idempotent:
   never overwrite an existing task without saying so. Report each file written and
   any issue skipped (trivial, or already briefed).

## Task brief format

The canonical brief shape **and** the executing agent's pickup protocol live in
`tasks/README.md` — shipped beside this skill as `tasks-README.md`, copied into a repo
on first adoption (step 1). That file is the single source of truth; follow the repo's
copy rather than restating it here. In short, each `tasks/NNN-slug.md` carries: source
issue · pickup protocol · suggested agent · **human steps / blockers** · entry points ·
prior art to mirror · steps · verify · acceptance-criteria checklist · out of scope.
Keep briefs lean — the agent greps the anchors itself, so prose stays short.

## Guardrails

- **Grep-stable anchors, never raw line numbers.** Line numbers are the most
  volatile reference there is — the moment one task edits a file, every later task's
  line numbers in it drift, silently invalidating pending briefs. Anchor instead on
  things `grep` finds: ``the `handleAuth` function in `src/auth.ts` ``, a heading, a
  unique string, a prior-art file. The agent greps once (negligible) and is immune
  to drift. This rule is what makes `all` safe to batch.
- **Issue status is the single source of truth — no separate claim system.** Don't
  invent a lock/owner field on tasks. An agent "grabs" work by flipping the *issue's*
  `status` to in-progress; that is the only coordination concurrent sessions need.
- **Update status fast, and on `main`.** Issue/task status edits are queue
  bookkeeping, not feature work — the executing agent commits them **promptly and
  directly on `main`** (exempt from the usual "branch first" rule) so other sessions
  see an accurate queue immediately. The brief must instruct this explicitly.
- **Work needing the user's hands must be visible on the issue.** If discovery (or
  the executing agent, mid-work) finds the task can't be finished by an agent alone —
  physical access, a secret/credential it lacks, an external-account or dashboard
  action, an approval, or hardware/manual testing — that must show on the **issue**
  (the surface the user watches), not just in the brief. Use the repo's idiom: a
  `blocked` status / `needs-human` label if the spec has one, else a clearly marked
  note in the issue body — invent no new label. List the exact human steps in the
  brief too.
- **Create-only — one carve-out.** This skill *writes briefs*. It does not change
  issue status, close issues, or do the work — that's the executing agent's job,
  driven by the brief. Authoring a task must not start the work. The *only* exception
  is the human-hands flag above: annotating the issue so a blocker is visible is
  allowed, because that visibility is the point.
- **In-repo only.** Target the file-based `issues/` + `tasks/` convention. A `gh` /
  Linear backend is out of scope — note it as possible future work, don't branch.
- **Nothing to brief?** Every open issue already has a task, or the only candidates
  are trivial — say so and stop. If the issues themselves aren't hashed out, suggest
  `/to-issues` (or `/grill-context`) first; alignment is not this skill's job.

## Composition

`grilling` → `to-prd` *or* `to-issues` → `to-tasks` → `grab`. `to-issues` decomposes a
plan into grabbable work items (no paths, so they survive the project); `to-tasks`
freezes each into an execution brief (paths in, consumed fresh) so an agent runs cheap;
`grab` is the consumer that claims a brief and executes it. `to-issues` and `to-tasks`
read the ADRs and glossary that `decision-docs` maintains and write in that vocabulary.
