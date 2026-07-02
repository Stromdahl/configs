---
title: Back up service appdata off the mirror with restic
status: in-progress
priority: high
created: 2026-07-01
closed: null
labels: [epic:backup]
---

## Description

The service appdata — *arr databases, quality profiles and custom formats,
Bazarr's language profile, Jellyseerr request history, Jellyfin watch state —
lives on the btrfs raid1 SSD mirror. raid1 survives a *drive* failing; it does
nothing against filesystem corruption (the board is non-ECC), a bad container
upgrade, ransomware, or a fat-fingered delete. SnapRAID protects the media
library, which is re-acquirable anyway. Nothing today protects this appdata,
which is the actual accumulated curation effort and is *not* re-acquirable.

This slice establishes a versioned, deduplicated `restic` backup of the appdata
subvolume to the HDD pool: a scheduled snapshot with a retention/prune policy,
applied by Ansible from krypton. It is a deliberately-scoped subset of the
full-box backup deferred in the PRD (Immich + Paperless + appdata, local repo
now and a versioned offsite later) — this issue does the appdata slice and the
local repo; the media library stays excluded (SnapRAID-protected).

A silent backup failure is as bad as no backup, so a failed run should surface
out of band via the notification mechanism established in `issues/013` — a soft
coupling: this issue is not blocked on 013, but wires into it once it exists.

Depends on `issues/011` (the mirror the appdata lives on) and `issues/003` (the
HDD pool the repo is written to).

## Acceptance criteria

- [ ] A `restic` repository exists on the HDD pool and is initialised with a
      passphrase sourced from sops (never landing in git or world-readable).
- [ ] A scheduled unit snapshots the appdata subvolume unattended, with a
      retention/prune policy applied so the repo does not grow unbounded.
- [ ] A test restore of one application's config from a snapshot succeeds
      (verified, not assumed).
- [ ] Deployed via Ansible from krypton, idempotently.
- [ ] A failed backup run surfaces out of band (wired to `issues/013`'s
      mechanism once available; until then, at minimum a non-silent failure).
