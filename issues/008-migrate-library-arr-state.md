---
title: Migrate the media library from neon
status: done
priority: high
created: 2026-06-27
closed: 2026-07-03
labels: [epic:cutover]
---

## Description

Move the existing ~932 GB movies+shows library off neon onto helium's HDD pool with
full continuity, so Jellyfin serves the real library. Done as a **live first pass**
while neon keeps serving, then a **final delta sync** at cutover.

This was the media half of the original migration issue; the *arr application state
+ active downloads migration is `issues/015` (it depends on the download-automation
stack existing). The library rsync here only needs the pool and Jellyfin, so it can
start as soon as the pool mount is live — and in fact should run in the background
early, since neon holds the only other copy.

Depends on `issues/003` (the pool the media lands on) and `issues/005` (Jellyfin,
to serve + verify the migrated library).

## Acceptance criteria

- [x] The full ~932 GB library is present on the HDD pool and visible in Jellyfin.
      *(first-pass rsync completed `DONE rc_total=0` 2026-06-30; `/srv/media` now
      holds 611 G movies + 734 G tv — larger than the original library, as the live
      014 download stack has been acquiring since. Imported in-place into Radarr
      (15 movies) + Sonarr (17 series); snapraid parity synced 874 G, 0 errors.)*
- [x] A final delta rsync reconciles any changes made on neon during the build.
      *(reconciled by construction: neon's download side was stopped and its library
      frozen at/before the first pass, which completed cleanly — so neon made no
      changes during the build. All new content landed on helium, which now holds
      strictly more than neon ever did; a from-neon delta could only be empty. User
      confirmed 2026-07-03 neon is frozen and helium is authoritative.)*
- [x] Playback of a migrated title works end-to-end over the mesh.
      *(observed 2026-07-02: Poirot S01E01 — a migrated title — transcoded via QSV
      and played over the mesh during the issue-005 verification.)*

## Status — 2026-07-03 (done)

Closed on the evidence above rather than by running a proof-only final delta. The
first-pass migration completed cleanly (`rc_total=0`, 2026-06-30) and the library is
live in Jellyfin + the *arr apps, parity-protected. The user confirmed neon's
download side was stopped and all new content now lands on helium, so neon has been
frozen since before the first pass finished — there is nothing on neon to reconcile,
and helium is the authoritative copy (611 G movies + 734 G tv, larger than the
original ~932 GB). Running a real neon→helium delta would only confirm the known
zero, against a root-only ephemeral-key source that may already be torn down, with a
live `--delete` foot-gun — low value, non-zero risk.

**Handed to `issues/009`:** the leftover migration scaffolding is teardown that
belongs with decommissioning neon — unmount `/mnt/neon-src` on neon-rescue and remove
the ephemeral key (`/root/.ssh/neon_migrate*` on helium + the matching line in
neon-rescue's `authorized_keys`). Both are root/neon-side and fold naturally into the
neon retirement, so they are not blocking this issue.
