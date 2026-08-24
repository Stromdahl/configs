---
title: Back Forgejo up with its own restic arm and exercise the restore
status: open
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

Forgejo's state gets its own restic arm, owning the whole service end to end, and the
generic nightly appdata walk stops covering it. Depends on `issues/056` (there is
nothing to back up until the service exists).

This matters more than a routine backup chore. After the tracker migration, Forgejo's
SQLite database is the **only** copy of every issue and every wayfinder map — the git
repos would survive a torn backup, the planning record would not. The nightly appdata
walk is a naked filesystem copy, and a file-level copy of a live SQLite database with a
hot WAL is torn and unrestorable. Measured on the prototype: more than half its state
was sitting in an uncheckpointed WAL.

The shape, from personal-forge ticket 11:

- A host-side consistent online copy of the database (not a dump — the upstream dump
  path is disqualified by Forgejo's own upgrade docs, and the image ships no sqlite
  binary, so the existing `docker exec … pg_dump` shape cannot be copied). Measured at
  6 ms, non-invasive, integrity-clean. This is the first arm in the script that needs
  no `docker exec` at all, so the script's per-service database container/user/name
  case variables do not apply to it, and its comments currently assume Postgres
  throughout — both need reshaping rather than extending.
- The arm takes Forgejo's whole appdata directory as its library paths, so the copied
  database and the config file that encrypts its stored credentials and 2FA secrets
  land in **one** snapshot under **one** tag. A restore that recovers only the database
  and the git objects into an empty volume loses those secrets while reporting success.
- The generic appdata backup unit excludes Forgejo's directory — and its header
  comment, which currently claims to cover the whole subvolume, is updated with it.
- A dedicated timer, staggered off the existing slots, with the same failure-alert
  hook the other arms use. Accepted cost: a silently-stopped Forgejo timer is no longer
  backstopped by the appdata run.

The restore runbook is written **and exercised once**. The house standard is
"verified, not assumed", and the two prior backup issues both verified their restores —
but what has never been attempted is restoring a live-walked SQLite database and
opening it. This restore is two-step (restore the directory, then drop the database
copy in over the live file and remove stale sidecars), with two ways to fail silently.

The fleet-wide btrfs-snapshot alternative — which would fix the same tearing for all 26
live SQLite databases on that subvolume — is deliberately **not** in scope here. It was
measured cheap but it is a decision about helium's whole backup posture, and Forgejo is
independently safe without it, so the two need no sequencing.

## Acceptance criteria

- [ ] A scheduled Forgejo backup runs on its own timer and produces a snapshot under
      its own tag containing both the consistent database copy and the service's
      appdata directory.
- [ ] The plaintext database copy is wiped on exit, including on failure.
- [ ] The generic appdata backup no longer walks Forgejo's directory, and its header
      comment no longer claims to cover the whole subvolume.
- [ ] The backup's failure path fires the existing alert hook (demonstrated, not
      assumed).
- [ ] A restore runbook exists and **was exercised**: the previous snapshot restored
      into a throwaway container, which starts and shows a matching issue count.
