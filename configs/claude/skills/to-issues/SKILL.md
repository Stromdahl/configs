---
name: to-issues
description: Break a plan, PRD, or finished /grill-context session into independently-grabbable issues in the repo's in-repo `issues/` convention — thin vertical "tracer-bullet" slices grouped by epic (≈ project phases), written in dependency order. The work-breakdown sibling of /to-prd (which writes one durable doc; this emits many grabbable issues). Type /to-issues to slice the earliest not-yet-decomposed epic, /to-issues <epic> for a named one, or /to-issues all to decompose the whole plan at once.
disable-model-invocation: true
---

# To issues

Decompose a plan into independently-grabbable issues, written into this repo's
**in-repo `issues/` convention** as thin vertical "tracer-bullet" slices, grouped
by **epic** (≈ the plan's phases) and numbered in **dependency order**.

This is the work-breakdown sibling of `to-prd`: `to-prd` writes one durable doc;
`to-issues` decomposes a plan into many grabbable work items. **Do NOT interview for
alignment** — that's `grilling`'s job. This skill only confirms the *decomposition*
(granularity + dependencies) before writing. A finished `/grill-context` session, a
`PLAN.md`, or a `docs/PRD.md` is the ideal input.

## Scope (one epic per run; `all` for small projects)

The argument selects what a run decomposes:

- **(none)** → the **earliest not-yet-decomposed epic** (default).
- **`<epic>`** (e.g. `phase-1`, a phase name/slug) → that epic.
- **`all`** → every epic in one pass — for small, single-phase projects.

An epic is "already decomposed" when `issues/` already holds issues carrying its
label. Check that first, so re-running a scope is **idempotent** and never dups.

## Procedure

1. **Read ground truth first — never improvise from memory.**
   - **The tracker spec:** read *this repo's own* `issues/README.md`. The format
     differs by spec version (older repos move closed issues into `issues/closed/`;
     newer ones never move files and key off the `status` field). Follow that file;
     do not assume one. If there is **no `issues/` dir**, *offer to adopt it* — `mkdir
     issues/`, copy the canonical spec README, then proceed — but don't impose it
     without consent.
   - **The plan:** read the source — conversation context, a plan/PRD doc
     (`PLAN.md`, `docs/PRD.md`), or an issue reference passed as the argument
     (`issues/NNN`) when breaking one large issue into sub-slices.
   - **The decisions:** read any `docs/decisions/` ADRs and glossary; write issue
     titles and bodies in that vocabulary and never contradict a locked decision.
     (This is the context `decision-docs` maintains.)
   - **Existing issues:** scan `issues/` for the highest `NNN` and for which epics
     already have issues.

2. **Identify the epics.** Epics ≈ the plan's **phases** (a `PLAN.md` "Phasing"
   section, or a PRD's stages). The epic-level list — its scope and order — lives in
   that planning surface, **not** in the copied `issues/README.md` (keep that spec
   file pristine; it is version-pinned). Each epic is just a **label** on its issues
   — `phase-N` where the repo already uses it, else `epic:<slug>`. Confirm the tag
   style from existing labels rather than inventing one.

3. **Draft vertical slices for the in-scope epic(s).** Each issue is a thin slice
   that cuts **end-to-end** through every layer it touches — NOT a horizontal slice
   of one layer.
   - A completed slice is **independently demoable or verifiable**.
   - For non-web projects (pipelines, agents, infra) a slice is a runnable
     end-to-end capability (e.g. "one sender's mail → an `inbox/` file,
     propose-only"), not "the IMAP layer".
   - Any **prefactoring** goes first, as its own earliest issue — "make the change
     easy, then make the easy change".
   - Express dependencies as the repo's idiom: a body line ``Depends on `issues/NNN`
     (reason).`` — not a frontmatter field.

4. **Confirm the decomposition (not the alignment).** Present the proposed slices as
   a numbered list — **title · epic label · depends-on · the user stories / ACs it
   covers**. Ask only about *granularity and dependencies*: too coarse / too fine?
   deps correct? merge or split any? Iterate until approved. Deep design
   disagreements belong back in `grilling`, not here.

5. **Allocate IDs in dependency order, then write.** Assign `NNN` to the approved
   slices **in dependency order** (blockers get the lower numbers), starting at
   `max-existing + 1`, so every ``Depends on `issues/NNN``` reference resolves. Then
   write each `issues/NNN-slug.md` in the exact shape the repo's `issues/README.md`
   defines: frontmatter (`title`, `status: open`, `priority`, `created` from `date
   +%F`, `closed: null`, `labels: [<epic-tag>, …]`) and a body of `## Description`
   (end-to-end behavior, no stale file paths) and `## Acceptance criteria` (a
   checklist). Report each file written and any epic left un-decomposed.

## Guardrails

- **Create-only.** This skill *creates* issues from a plan. It does **not** close,
  reopen, re-number, or change the status of any existing issue, and it never
  modifies a parent/source issue — lifecycle changes are a separate, manual action.
- **Never reuse or move an ID.** Next free `NNN`, monotonic; honor the repo's own
  move-vs-never-move rule from its `issues/README.md`.
- **In-repo only.** Target the file-based `issues/` convention. A `gh` / Linear
  backend is out of scope for now — note it as possible future work, don't build a
  detection branch.
- **No new ceremony.** Don't invent labels, priorities, or body sections the repo's
  spec doesn't already define; match existing labels and the README's skeleton.
- **Nothing to decompose?** The epic already has issues, or the plan is too thin —
  say so and stop. If the plan isn't actually hashed out, suggest `/grill-context`
  first; alignment is not this skill's job.

## Composition

`grilling` → `to-prd` *or* `to-issues`. `to-prd` crystallizes a conversation into one
durable PRD; `to-issues` decomposes a plan into many grabbable slices. Both read the
ADRs and glossary that `decision-docs` maintains and write in that vocabulary.
