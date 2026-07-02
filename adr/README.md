# Architecture Decision Records

An **ADR** captures a single architectural decision that is a real trade-off and
would be *surprising without context* — so future work doesn't unknowingly undo it.
This directory is a peer to `issues/` and `tasks/`: those say *what to build*; ADRs
record *why a choice was made*.

- **One decision per file:** `adr/NNNN-kebab-title.md`, `NNNN` zero-padded and
  monotonic.
- **Sections:** Title · Status · Context · Decision · Consequences · Alternatives
  considered.
- **Status** is `Proposed | Accepted | Superseded by NNNN`. ADRs are **append-only**
  — a reversal is a *new* ADR that supersedes the old one; the old file stays.
- Keep them short and durable. The *what/how* lives in `hosts/<host>/PRD.md`,
  `issues/`, and `tasks/`.

Write an ADR **sparingly** — only when a choice is hard to reverse, a genuine
trade-off, and non-obvious later. Routine choices don't need one.
