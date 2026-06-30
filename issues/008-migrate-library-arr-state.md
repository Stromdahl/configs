---
title: Migrate the media library and *arr state from neon
status: open
priority: high
created: 2026-06-27
closed: null
labels: [epic:cutover, needs-human]
---

## Description

Move the existing library off neon onto helium with full continuity. Two parts:

- **Media data:** rsync the ~932 GB movies+shows library from neon into the HDD
  pool. Done as a live first pass while neon keeps serving, then a final delta sync
  at cutover.
- **Application state:** migrate the *arr Docker volumes (radarr/sonarr/prowlarr/
  bazarr/profilarr configs + databases) so library history, quality profiles, and
  import state come over **intact** rather than being rebuilt from scratch.

**Start lean:** the ~600 GB of old completed seeds are dropped (ratio is not a
concern); only incomplete/recently-grabbed downloads carry over, onto the SSD tier.

Depends on `issues/005` (the stack must be running to receive the volumes and serve
the library) and `issues/003` (the pool the media lands on).

## Acceptance criteria

- [ ] The full ~932 GB library is present on the HDD pool and visible in Jellyfin.
- [ ] The *arr apps show their pre-existing library history and quality profiles
      (state migrated, not rebuilt).
- [ ] Only lean/active downloads were carried over; old seeds were intentionally
      dropped.
- [ ] A final delta rsync reconciles any changes made on neon during the build.
- [ ] Playback of a migrated title works end-to-end over the mesh.
