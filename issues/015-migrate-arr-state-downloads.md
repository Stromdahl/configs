---
title: Migrate *arr state and active downloads from neon
status: dropped
priority: medium
created: 2026-06-30
closed: 2026-06-30
labels: [epic:cutover, needs-human]
---

## Description

> **DROPPED 2026-06-30.** Superseded by the decision to build the *arr stack
> **fresh** with TRaSH Guides best practices (`issues/014`) rather than migrate
> neon's state. neon's *arr DBs / quality profiles are intentionally **not**
> preserved; the fresh stack adopts the migrated library (`issues/008`) as existing
> media and applies TRaSH quality profiles + custom formats. Text below kept for
> history.

Bring the *arr application state off neon onto helium **intact** — radarr / sonarr /
prowlarr / bazarr / profilarr configs + databases — so library history, quality
profiles, and import state come over rather than being rebuilt from scratch. Carry
over only the lean/active downloads; the ~600 GB of old completed seeds are
intentionally dropped (ratio is not a concern).

This was carved out of the media-library migration (`issues/008`) because it needs
the download-automation stack running to receive the volumes. The *arr DBs are
SQLite — the source containers must be stopped during the copy, and a final pass
runs at the cutover window.

Depends on `issues/014` (the *arr + qBittorrent stack must be up on helium to
receive the volumes) and `issues/008` (the library they index is already migrated).

## Acceptance criteria

- [ ] The *arr apps show their pre-existing library history and quality profiles
      (state migrated, not rebuilt).
- [ ] Only lean/active downloads were carried over; old seeds were intentionally
      dropped.
- [ ] A final delta sync reconciles any *arr/download changes made on neon during
      the build.
- [ ] After migration, an existing automation path still works end-to-end (e.g. a
      grab/import that the migrated *arr state recognizes).
