---
name: grilling
description: Interview the user relentlessly about a plan or design until every branch of the decision tree is resolved. Use when the user explicitly wants to stress-test or sharpen a plan/design before building, or uses a 'grill' trigger phrase ("grill me", "grill this", "grill with docs"). The reusable loop behind grill-me and grill-with-docs. Do NOT auto-invoke during ordinary planning chat — only when alignment-before-building is clearly wanted.
---

# Grilling

Interview the user relentlessly about every aspect of the plan or design until you
reach a shared understanding. Walk down each branch of the decision tree, resolving
dependencies between decisions one-by-one. The goal is to close the gap between what
the user means and what would actually get built.

## The loop

1. **One question at a time.** Ask a single question, then wait for the answer
   before continuing. Asking several at once is bewildering and defeats the point.
2. **Always recommend an answer.** For every question, give your recommended answer
   and the reasoning behind it — don't just pose an open void. The user steers; you
   propose.
3. **Prose, not menus.** Ask in prose with a recommendation. Do **not** use
   AskUserQuestion option-menu cards — they flatten reasoning into clicks. Reserve a
   structured card only for a genuinely crisp either/or, and even then lead with the
   reasoning. (This matches how the user prefers to be asked.)
4. **Explore before you ask.** If a question can be answered by reading the repo —
   what convention exists, how something already works, what files are there — go
   read it instead of asking. Spend the user's attention only on what the code can't
   tell you. Delegate read-heavy exploration to a subagent when it's broad.
5. **Resolve dependencies in order.** Settle upstream decisions first; let each
   answer narrow the branches still open below it.

## Closing synthesis

When the tree is resolved, stop interviewing and **restate the shared understanding
as a short plan** before any building begins — the decisions made, the chosen
approach, and what's now out of scope. This synthesis is the output of a plain
grilling session. (When `decision-docs` is also in play, it additionally persists
the durable decisions to the repo's convention.)
