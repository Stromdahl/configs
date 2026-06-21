---
name: skill-design
description: Principles for writing Claude Code skills that route predictably and behave the same every run — used both when authoring a new skill and when reviewing or hardening an existing one. Fires when a skill file is itself the artifact in hand: creating or editing a SKILL.md, working under a skills/ directory, or the user asks to write / improve / review a skill. Do NOT auto-invoke during ordinary code work or when merely *using* another skill — only when a skill file is the thing being designed or audited.
---

# Skill design

A skill is **predictable** when it routes the same way every time — fires when it
should, stays silent when it shouldn't — and **robust** when it behaves the same
once loaded, regardless of which session runs it. Those are two layers: the
**description** (routing) and the **body** (execution). Get both right and a skill
is a reliable tool; get the description wrong and the best body never runs.

Apply these whether writing a new skill or hardening an existing one. When reviewing,
read the skill against the six principles below — the description first, since a skill
that misroutes is broken no matter how good its body is.

**Hard frontmatter, soft body.** The frontmatter shape and the composition rules
(principles 1 and 6) are uniform across every skill — that uniformity *is* the house
"unified language." Body structure is a toolkit, not a mandate: `## Procedure` /
`## Guardrails` / `## Notes` are the common shapes, but a skill is free to differ when
its job differs (a detection rule, an example, a table). Don't flatten useful variety.

## The principles

1. **The description is the router — this is the most important rule.** It is the
   *only* text the model sees when deciding whether to load the skill, so it must
   encode routing, not just summary. Write it as: **what it does + the concrete
   triggers a user actually types or does + an explicit "Do NOT …" anti-trigger.**
   Third person, specific, with literal trigger words. The anti-trigger applies to
   **model-invokable** skills; a `disable-model-invocation` wrapper can't auto-fire,
   so it skips the anti-trigger and just says "Type /x to …". A description isn't
   finished until you've checked it **routes**: name a case where it should fire and
   one where it shouldn't, and confirm the wording draws that line.

2. **Operate on ground truth, not memory.** The body should make the skill *read real
   state* — the repo, the file, `git status` — before it acts, never improvise from
   what it assumes is there. This is what makes two runs agree. (See `committing`:
   "Ground truth first" — enumerate what is actually changed, not what was imagined.)

3. **Determinism in the body.** Prefer a tight imperative `## Procedure` of numbered
   steps with bold lead-ins over loose prose. Same inputs should yield the same
   behavior; vague instructions ("handle it appropriately") let the model wander
   differently each run. Pin the order when order matters.

4. **Name the failure modes.** A robust skill says where to *stop*: "if the hook
   fails, surface it and stop"; "nothing in scope? say so." Spell out the guardrails
   and the not-to-do's so the edge cases resolve the same way every time, instead of
   being improvised. (See `committing`'s `## Guardrails`.)

5. **Progressive disclosure & token economy.** The description and SKILL.md cost
   context on every routing decision — keep them lean. Push detail to supporting files
   loaded on demand, and *reference* auto-loaded context rather than restating it (see
   `dotfiles-module` deferring the module contract to `AGENTS.md`). Split out a file
   only when the main one would bloat — being short enough not to need it is the most
   honest way to dogfood this.

6. **Compose, don't sprawl.** One skill = one job. When a job has distinct *scopes* or
   *modes*, factor the shared logic into an **engine** and add **thin wrappers** that
   only pick the scope, each with `disable-model-invocation: true` (see `committing` ←
   `commit` / `commit-all`, `grilling` ← `grill-me` / `grill-context`). Cross-link
   sibling skills by backtick name and **hand off** rather than duplicate
   (`grilling` → `to-prd` → `decision-docs`). Gate deliberate, destructive, or
   outward-facing actions; document the choice when you *don't* gate (as `committing`
   documents its no-confirmation commit-then-report).

## Dogfood check

A skill about skills must be one. Before calling a skill done, audit it against the
six above — most sharply its own description against principle 1. If a principle is
awkward to follow in the very skill that states it, the principle is wrong: fix the
principle, not just the file.
