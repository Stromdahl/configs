---
title: Back up Immich and Paperless data (databases + originals) with restic
status: open
priority: high
created: 2026-07-03
closed: null
labels: [epic:backup]
---

## Description

Immich and Paperless hold the box's genuinely-irreplaceable **original** data, and
nothing backs it up today. Immich is the phone auto-backup target, so over time it
trends toward being the *primary* (eventually only) copy of the family photo
library; Paperless holds scanned document originals + the OCR archive, the paper
copies of which may not survive. Both live on the btrfs raid1 SSD mirror as their
own subvolumes.

raid1 survives a *drive* failing; it does nothing against filesystem corruption
(the board is non-ECC), a bad container/DB upgrade, ransomware, or a fat-fingered
delete. Unlike the media library (SnapRAID-protected, and re-acquirable anyway) or
the *arr/Jellyfin appdata (`issues/016`, which is accumulated curation effort),
this photo + document data is **original and not re-acquirable** — losing it is
losing the thing itself.

`issues/016` stood up a versioned, deduplicated restic repository on the HDD pool
for the *arr/Jellyfin appdata slice and **deliberately deferred Immich + Paperless
to a later slice** — this is that slice. It extends the same repository with a
**distinct tag per application**, so each app's retention/prune rolls
independently, on the same scheduled, unattended cadence.

Because both apps are Postgres-backed, a naive file-level copy of a live database
directory can capture a torn, unrestorable state — so the database portion must be
backed up in a form that restores to a **consistent, working** database, not just
whatever bytes were on disk mid-write.

A silent backup failure is as bad as no backup, so a failed run must surface out of
band via the same non-silent mechanism the appdata backup uses (wiring into
`issues/013`'s alerting once it exists).

This remains the **local-repo** slice: replicating the repository **offsite** is
still deferred to the PRD's full-box backup and is out of scope here.

Depends on `issues/016` (the restic repository + backup role this extends).
Depends on `issues/006` (Immich must be running with real data to back up).
Depends on `issues/007` (Paperless must be running with real data to back up).

## Acceptance criteria

- [ ] Immich's Postgres database **and** its photo/upload library are captured in
      the restic repository under a distinct tag, on the established schedule and a
      retention/prune policy.
- [ ] Paperless's Postgres database **and** its documents (originals + archive) are
      captured in the restic repository under a distinct tag.
- [ ] The database backups restore to a **consistent, working** state — verified by
      restoring a snapshot's database and confirming the application reads it — not a
      torn copy of a live data directory.
- [ ] A test restore of one photo (Immich) and one document (Paperless) from a
      snapshot succeeds (verified, not assumed).
- [ ] Deployed via the existing Ansible restic backup role from krypton,
      idempotently; retention/prune is per-tag so each application rolls
      independently of the appdata backup.
- [ ] A failed run surfaces out of band via the same non-silent mechanism as the
      appdata backup (wired to `issues/013` once available).
