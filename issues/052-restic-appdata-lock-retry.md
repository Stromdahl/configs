---
title: Add lock-retry to the appdata restic backup unit
status: open
priority: low
created: 2026-08-12
closed: null
labels: [epic:backup]
---

## Description

All three restic timers (appdata, Immich, Paperless) share one restic repository,
so a prune step from one can hold the exclusive lock when another's backup/prune
tries to run. The Immich and Paperless backup script already retries against a
held lock, added after a prior incident where a stale lock failed all three prune
steps at once. The original appdata backup unit predates that fix and still has no
lock-retry, so it can still fail outright — rather than wait — if another unit's
prune is mid-flight when it starts. It does alert on failure, so this isn't a
silent gap, but it leaves one of the three units still exposed to the exact
failure mode the other two were hardened against.

## Acceptance criteria

- [ ] The appdata restic backup and prune commands wait for a held repository lock
      (matching the Immich/Paperless units' retry-lock behavior) instead of
      failing immediately.
- [ ] Running the appdata backup while a long Immich/Paperless prune holds the
      lock completes successfully once the lock is released, rather than
      triggering the failure alert.
