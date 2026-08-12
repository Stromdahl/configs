---
title: Add a single-SSD-replace recovery path to the storage_ssd role
status: open
priority: high
created: 2026-08-12
closed: null
labels: [epic:storage]
---

## Description

The `storage_ssd` role only checks whether the btrfs raid1 pool already exists by
probing one SSD member. If that specific drive fails and is replaced with a blank
disk, re-running the role can't tell "one member is dead, rebuild onto the
replacement" apart from "no pool exists yet" — it treats the whole pool as absent
and reformats both SSDs from scratch, including the still-healthy survivor holding
the only live copy of Docker appdata, Immich, and Paperless data.

This slice adds a genuine single-member-replace path — distinct from the existing
first-build path — so recovering from one dead SSD never touches the surviving
member's filesystem.

## Acceptance criteria

- [ ] Re-running the storage_ssd role when one SSD is blank/failed and the other
      already holds the live btrfs raid1 pool does not reformat or otherwise
      mutate the healthy member's filesystem.
- [ ] The role provides (or documents) an explicit, safe procedure to add a
      replacement disk to the existing pool and rebalance, verified against a real
      or simulated single-drive failure drill.
- [ ] The existing first-build (both members blank) and no-op (pool already
      healthy) paths remain unchanged and idempotent.
