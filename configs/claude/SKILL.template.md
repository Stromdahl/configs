---
name: skill-name
description: Use this skill when <concrete trigger situation>. Spell out the phrases and task shapes that should activate it (e.g. "the user asks to X", "discusses Y", "needs Z") — this field is what Claude matches on to decide whether to invoke the skill, so be specific about WHEN, not just what it does.
# version: 1.0.0   # optional
---

# Skill Name

One or two sentences on what this skill does and the outcome it produces.

## When to use

- Trigger 1 — the kind of request that should activate this.
- Trigger 2.
- When NOT to use it (if there's an easy-to-confuse neighbour).

## Instructions

Step-by-step guidance Claude should follow when this skill fires. Be concrete
and imperative. Keep it focused — a skill is contextual guidance injected into
the session, so favour the few rules that actually change behaviour.

1. First do …
2. Then …
3. Verify by …

## Notes

- Optional supporting files can live alongside this one (e.g. `references/`,
  helper scripts). Reference them by relative path from this skill's folder.
- Keep SKILL.md tight; push long reference material into separate files the
  skill points to, so it's only read when needed.
