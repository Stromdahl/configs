---
title: File lumin's three inherited work items on its forge tracker
status: open
priority: low
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

Three work items surfaced by the personal-forge planning belong to **lumin**, not to
this repo, and lumin has no tracker today — its scratch directory holds design docs, not
issues, and the markdown tracker stopped being the default for new projects. So they get
filed as issues on lumin's repo once it exists on the forge. Depends on `issues/063`.

This ticket exists only so the three do not evaporate between the map being retired and
lumin's tracker existing. It is done when they are filed.

The three:

1. **The perf ceilings are stale and need a human re-anchor bless.** One benchmark
   measures well under its blessed ceiling **on the laptop**, so this is code drift
   since the ceilings were set — not an artefact of splitting CI onto another host.
   Filing it should say so, or whoever picks it up will chase the wrong cause.
2. **The spec and justfile amendments**: adding the lockfile-respecting flag to the
   cargo invocations for *reproducibility* (explicitly not for security — the perf gate
   must not compare instruction counts across differing dependency sets), letting the
   mutation recipe take pass-through arguments, and the corresponding spec section and
   agent-doc rule swap. Both changes are flagged under the spec's own change ritual.
3. **Lumin's actual Forgejo Actions workflow** — and this one carries a **live conflict
   that must be raised, not assumed away**. The definition-of-done ticket was shelved
   mid-answer with three of its sections left *proposed*, permanently, until reopened.
   One of those proposes that a workflow may only call recipes and must never inline a
   gate. The runner-topology ticket expressed a different preference. Nothing resolved
   between them. Whoever writes the workflow inherits that conflict and must surface it
   to the owner rather than quietly picking a side.

Also note for whoever writes the workflow: the spec assumes exactly **one machine
measures instruction counts**, and has no rule for which host owns the ceilings once two
do. The recommended resolution was to designate the CI host as the anchoring authority,
and `issues/061` supplies the measurements that say whether that is viable — but the
decision itself is unmade.

## Acceptance criteria

- [ ] Three issues exist on lumin's forge tracker, one per item above.
- [ ] The ceilings issue states that the drift was measured on the laptop, so the cause
      is code drift rather than the CI split.
- [ ] The workflow issue names the unresolved conflict explicitly and says it must be
      raised with the owner before a side is picked.
- [ ] The workflow issue notes the unmade anchoring-authority decision and points at the
      measurements that inform it.
