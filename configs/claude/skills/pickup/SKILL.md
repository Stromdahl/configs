---
name: pickup
description: Pick up a /handoff document in a fresh session and route straight into whichever skill actually fits the task. Type /pickup [path] [steering text] to resume from a handoff file — the other half of the /handoff bridge.
argument-hint: "Which handoff file (if not the only one in temp), and any steering for how to proceed?"
disable-model-invocation: true
---

# Pickup

The other half of the `/handoff` bridge: `/handoff` compacts a full session into
a file, `/pickup` reads that file in a fresh session and dispatches into
whichever skill the task actually calls for.

## Procedure

1. **Locate the handoff file.**
   - If the arguments contain something that looks like a file path, use it.
   - Otherwise, glob the OS temp directory for `handoff-*.md`.
     - Exactly one match: use it.
     - Multiple matches: list them with their modification times and ask the
       user which one.
     - No matches: report that plainly and stop. Do not guess or fall back
       to any other file.
2. **Extract any steering text.** Anything in the arguments that isn't the
   path is a steering instruction from the user (e.g. "just review, don't
   implement"). It outranks both the handoff's own suggestion and the flow
   map in step 5.
3. **Read the handoff file.**
4. **Follow its references.** A handoff points at other artifacts (a spec,
   `CONTEXT.md`, an ADR, an issue, a PR/diff) instead of repeating their
   content. Read each one directly — the handoff's summary of an artifact is
   not sufficient grounding for the routing decision in step 5.
5. **Decide the route.** Read `ask-matt`'s `SKILL.md` and apply its flow map
   fresh, grounded in what steps 3-4 actually turned up — not in the
   handoff's own "suggested skills" section, which is a hint from a session
   that may have misjudged the flow. Steering text from step 2 overrides
   both.
6. **Dispatch immediately.** Invoke the chosen skill. Do not pause to confirm
   the routing choice first.

## Guardrails

- Never silently pick among several candidate handoff files — ask.
- Never invoke a skill just because the handoff said to, without checking it
  against the flow map and the referenced artifacts.
- Leave the handoff file itself untouched: no deleting, archiving, or editing.

## Notes

- The flow map lives in `ask-matt`, not here, so the two cannot drift.
- Pairs with `/handoff`, which writes the file this skill reads, named
  `handoff-<YYYY-MM-DD-HHMMSS>-<slug>.md` in the OS temp directory.
