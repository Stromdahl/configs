---
name: to-prd
description: Turn the current conversation into a durable PRD and put it where this repo keeps such things — no interview, just synthesis of what you've already discussed (ideally after a /grill-me or /grill-context session). Type /to-prd to write the PRD.
disable-model-invocation: true
---

# to-prd

Synthesize the current conversation and codebase understanding into a PRD, then
put it where this repo already keeps durable docs. **Do NOT interview** — this
skill only crystallizes what's already been discussed. The canonical flow is
`/grill-me` or `/grill-context` to reach alignment, then `/to-prd` to make it
durable.

If the conversation is too thin to write a real PRD (the feature hasn't actually
been hashed out), say so and suggest `/grill-me` first — don't start asking
questions yourself. That's grilling's job, not this skill's.

## Process

1. **Read the repo for context.** Understand the current state of the code in the
   area you're touching. Read any existing **glossary** and **ADRs** and write the
   PRD *in that vocabulary*, respecting those decisions. (These are what the
   `decision-docs` skill maintains.)

2. **Sketch the test seams** — *only when the PRD describes a code feature with a
   real testable surface.* Name the highest-level seams at which the feature will
   be tested; prefer existing seams to new ones; the fewer the better (ideal: one).
   For config/infra changes with no meaningful test surface, skip this and note
   "no test surface" rather than inventing one.

3. **Detect the destination — propose, don't impose** (same discipline as
   `decision-docs`):
   - A **`gh`-backed issue tracker** (GitHub remote + issues enabled) → *offer* to
     publish the PRD as an issue.
   - Else a **docs convention** (`docs/`, `docs/prd/`, `docs/rfc/`, …) → write a
     repo-local markdown PRD matching it.
   - Else → synthesize the PRD into the conversation and *offer* to write it
     somewhere (a repo file, or `~/notes/inbox` for personal/dotfiles work).
   Never invent triage labels, assignees, or ceremony the repo doesn't use.

4. **Propose, then confirm — gated by how irreversible the destination is.**
   Present the PRD plus the detected destination (and, when relevant, the proposed
   seams).
   - Writing a local file or synthesizing inline → a light confirm.
   - **Publishing to an issue tracker** is outward-facing → always confirm first.
   Only after confirmation do you write/publish.

5. **Offer a `decision-docs` hand-off.** If writing the PRD surfaced a *net-new
   durable decision* (an architectural call that'll outlive this feature), offer
   to capture it via `decision-docs` — consent-based, never auto-created. The PRD
   is this skill's only deliverable; ADRs and glossary entries are `decision-docs`'
   job.

## PRD template

Keep the sections below. Use the repo's glossary vocabulary throughout. Do **not**
include specific file paths or code snippets — they go stale fast. *Exception:* if
a prototype produced a snippet that encodes a decision more precisely than prose
(state machine, reducer, schema, type shape), inline just the decision-rich bits
and note it came from a prototype.

- **Problem Statement** — the problem, from the user's perspective.
- **Solution** — the solution, from the user's perspective.
- **User Stories** — a numbered `As an <actor>, I want <feature>, so that
  <benefit>` list covering the feature. Scale the length to the feature's size —
  extensive for a real product feature, a handful for a small change. Don't pad.
- **Implementation Decisions** — modules built/modified and their interfaces,
  technical clarifications, architectural decisions, schema changes, API
  contracts, specific interactions. (No file paths / code, per above.)
- **Testing Decisions** — *conditional on a real test surface (step 2).* What
  makes a good test (test external behavior, not implementation details), which
  modules get tested, and prior-art tests in the codebase to mirror. Omit, or
  reduce to a one-line "no test surface", for config/infra changes.
- **Out of Scope** — what this PRD explicitly does not cover.
- **Further Notes** — anything else worth recording.
