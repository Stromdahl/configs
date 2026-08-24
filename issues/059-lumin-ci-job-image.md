---
title: Build lumin's CI job image on helium
status: open
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

A purpose-built container image for lumin's deep QA tier, built **on helium** by an
ansible task from a Containerfile in this repo, tagged by date/content-hash and
digest-pinned wherever it is referenced. Depends on `issues/058` (nothing builds
rootless images until Podman exists).

It is built locally rather than pulled from Forgejo's own registry so CI does not
depend on the registry that depends on the forge, and so the registry-exposure question
is sidestepped entirely.

The base is not a free choice. Every stock job image is a glibc generation behind, and
the perf gate compares instruction counts against committed ceilings with only 10%
headroom — a different libc means different code inside the measured region, so a
different result, not a few percent of drift. A musl base is disqualifying outright.
The base must match the glibc and valgrind generation the ceilings were anchored
against.

Contents are the union of what the feasibility research, the runner-topology research
and lumin's own preflight recipe demand: a pinned rust toolchain; the mutation-testing,
unused-dependency, licence-audit and coverage cargo tools; the benchmark runner at an
**exact** version, because preflight string-matches it against a pinned dev-dependency
and a bare install that resolves newer fails preflight; a headless Wayland compositor
and screenshot tool for the smoke gate; valgrind; a compression tool (without it cache
restores silently no-op); node (without it the checkout action breaks); and git.

Several of those compile from source at image-build time on six cores. **A slow,
rarely-rebuilt image is accepted** — that is the whole reason for baking it rather than
installing per run.

The image digest is part of the perf gate's provenance and must be recordable alongside
the toolchain versions.

## Acceptance criteria

- [ ] An ansible task builds the image on helium from a Containerfile in this repo, and
      is idempotent (a second run does not rebuild).
- [ ] The image reports the intended glibc and valgrind generations.
- [ ] `just preflight` for lumin passes **inside** the image, including the exact
      benchmark-runner version check.
- [ ] The image is tagged reproducibly and referenced by digest, not by a floating tag.
- [ ] The digest is recorded somewhere the perf gate's provenance can cite.
