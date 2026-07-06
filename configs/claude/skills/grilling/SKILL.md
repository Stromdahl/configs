---
name: grilling
description: Interview the user relentlessly about a plan or design until every branch of the decision tree is resolved. Use when the user explicitly wants to stress-test or sharpen a plan/design before building, or uses a 'grill' trigger phrase — "grill me" / "grill this" (plain mode), "grill context" (context-persisting mode). The engine behind grill-me and grill-context. Do NOT auto-invoke during ordinary planning chat — only when alignment-before-building is clearly wanted.
---

# Grilling

Interview the user relentlessly about every aspect of the plan or design until you
reach a shared understanding. Walk down each branch of the decision tree, resolving
dependencies between decisions one-by-one. The goal is to close the gap between what
the user means and what would actually get built.

## Modes

The caller — a wrapper skill or the user's trigger phrase — picks one:

- **plain** (from `/grill-me`, or a bare "grill me" / "grill this") — interview and
  closing synthesis only; nothing is persisted during the session.
- **context-persisting** (from `/grill-context`, or "grill context") — additionally
  persist decisions and terminology via the `decision-docs` skill as they
  crystallize. Before the first question, confirm **once** where decisions will land
  (per `decision-docs`' detection rule); after that one-time consent, persist
  as-you-go without re-asking — still applying `decision-docs`' sparing bar for ADRs.

Invoked directly with no clear signal, default to plain.

## The loop

1. **Open with a map.** Name the major branches you plan to walk (3–7 areas), most
   upstream first, then start on the first. Update the map as branches close — it
   shows the user how much grilling remains, and briefly restating it in long
   sessions is what keeps settled decisions alive across compaction.
2. **One question at a time.** Ask a single question, then wait for the answer
   before continuing. Asking several at once is bewildering and defeats the point.
3. **Always recommend an answer.** For every question, give your recommended answer
   and the reasoning behind it — don't just pose an open void. The user steers; you
   propose.
4. **Prose, not menus.** Ask in prose with a recommendation. Do **not** use
   AskUserQuestion option-menu cards — they flatten reasoning into clicks. Reserve a
   structured card only for a genuinely crisp either/or, and even then lead with the
   reasoning. (This matches how the user prefers to be asked.)
5. **Facts from the repo; decisions from the user.** If a question can be answered
   by reading the repo — what convention exists, how something already works, what
   files are there — go read it instead of asking; delegate read-heavy exploration
   to a subagent when it's broad. The *decisions*, though, are the user's: never
   settle one silently because the repo suggested a plausible answer — put it to
   them and wait.
6. **Stress-test with concrete scenarios.** When the boundary between concepts is
   fuzzy, invent an edge-case scenario that forces precision ("a user cancels half
   an order mid-shipment — what happens?") rather than asking in the abstract.
7. **Resolve dependencies in order.** Settle upstream decisions first; let each
   answer narrow the branches still open below it.

## Guardrails

- **Nothing to grill?** If no plan or design is identifiable in the conversation or
  the arguments, ask what to grill — don't interview about nothing.
- **Depth matches stakes.** Settle trivial branches yourself with a stated default;
  relentless does not mean exhaustive on a small change.
- **"You decide the rest" / "defaults are fine"** → stop asking; collapse the still-
  open branches into stated recommendations inside the closing synthesis.
- **An answer invalidates an upstream decision?** Reopen that branch explicitly
  ("this contradicts what we settled about X — revisiting") — never continue down a
  broken tree.

## Closing synthesis

When the tree is resolved, stop interviewing and **restate the shared understanding
as a short plan** — the decisions made, the chosen approach, what's now out of
scope, and (in context-persisting mode) the artifacts written during the session.
This synthesis is the output of a grilling session, and it is where the session
**stops**.

**Do not enact the plan, and never create durable artifacts, off the back of a grill
without explicit confirmation.** The synthesis is an offer, not a trigger: do **not**
start implementing, do **not** auto-invoke `to-prd` or `to-issues`, and do **not**
write a PRD, issue files, or any other durable artifact, until the user has said they
want it. Closing a grill means presenting the plan and naming the possible hand-offs —
then waiting. Each hand-off is consent-based:

- `to-prd` — crystallize the alignment into one durable PRD (no re-interviewing).
- `to-issues` — decompose the plan into independently-grabbable issues.
- a review pass — spawn parallel critical / out-of-the-box / pragmatic reviewer
  agents on the synthesized plan before building.
