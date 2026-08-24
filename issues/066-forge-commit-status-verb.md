---
title: Read the CI verdict through a forge verb instead of raw curl
status: open
priority: low
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

The house forge wrapper gains a verb over Forgejo's commit-status API, so an agent asks
"what did CI say about this commit" through a tool rather than assembling a request.
Depends on `issues/062` (the wrapper) and `issues/060` (there are no verdicts until the
runner runs).

This is small but it is the difference between a repeatable call shape and a bespoke one
pasted into every session — the same reasoning that produced the wrapper in the first
place. It also matters more here than it looks, because per-job commit statuses are the
*only* verdict channel that exists on push: there are none for scheduled or manually
dispatched runs, and notification wiring was deliberately deferred whole. Until that is
picked up, this verb is how a verdict is read at all.

No badges — that was decided and declined: the instance is mesh-only, so the only viewer
is the owner, who has the run list one click away.

## Acceptance criteria

- [ ] The wrapper exposes a verb returning the combined and per-context commit statuses
      for a given ref.
- [ ] It distinguishes "no status reported" from "status is failing" — the two must not
      collapse into one answer.
- [ ] Demonstrated against a real run: a red gate and a green gate each read correctly.
