---
name: decision-docs
description: Capture a crystallized decision or sharpen domain terminology into whatever convention the current repo already uses — an ADR under docs/adr/, a glossary (glossary.md / CONTEXT.md), or a standalone decision-markdown doc. Use when explicitly recording an architectural decision, pinning down terminology, or when grill-context needs to persist decisions as they crystallize. Do NOT auto-fire during ordinary edits.
---

# Decision docs

Persist decisions and terminology *as they crystallize* — not in a batch at the
end. This is the active discipline behind `grill-context`: the moment a real
decision is settled or a fuzzy term is sharpened, write it down where this repo
already keeps such things.

## The detection rule (this is the whole policy)

Look at the current repo and follow what convention is **already present**. Never
impose ceremony a repo doesn't already use.

- **`docs/adr/` exists** → offer to add an ADR — but **sparingly**. Only when all
  three hold: the decision is *hard to reverse*, *surprising without context*, and
  the result of a *real trade-off*. If any is missing, skip the ADR.
- **A glossary exists** (`glossary.md`, `CONTEXT.md`, or similar) **or the project
  has heavy domain jargon** → record/sharpen the term there. Challenge terms that
  conflict with existing definitions; propose one precise canonical term for
  overloaded ones ("you said 'account' — Customer or User?").
- **Neither convention exists** → do **not** create new files unprompted.
  Synthesize the decisions into the conversation and *offer* to create the right
  artifact (an ADR, a glossary, or a decision-doc), letting the user choose. This
  is the correct behavior in shared work repos that have no decision-log
  convention — propose, don't impose.

Create files lazily: only when there's something durable to write, and only with
consent where no convention exists yet.

## Formats (inline — discover the repo's own format first if one exists)

If the repo already has examples, match them. Otherwise:

- **ADR** — `docs/adr/NNNN-kebab-title.md`: Title · Status · Context · Decision ·
  Consequences · Alternatives considered. Short; one decision per file.
- **Glossary entry** — `Term — precise one-line definition.` Devoid of
  implementation detail; it's a shared-language dictionary, not a spec or scratchpad.
- **Decision-doc** (when offering a fresh standalone file) — Problem → Options &
  trade-offs (a table works well) → Decision → Consequences → Sources/links.

## Cross-check against code

When the user states how something works, check whether the code agrees. If it
contradicts, surface it ("your code cancels whole Orders, but you said partial
cancellation is possible — which is right?") rather than recording the claim blind.
