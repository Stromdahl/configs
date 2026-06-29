---
title: Data tier — btrfs raid1 SSD mirror with nodatacow scratch subvolumes
status: open
priority: high
created: 2026-06-29
closed: null
labels: [epic:storage]
---

## Description

Build the hot/precious data tier: the two 500 GB SATA SSDs as a **btrfs raid1**
mirror carrying all Docker appdata (configs + databases), the Immich library,
Paperless, plus the lean downloads and transcode cache. btrfs is chosen for data
checksumming (the board is non-ECC, so this guards against silent bit-rot) and
cheap snapshots. The precious subvolumes keep full CoW + checksums; the
**scratch subvolumes (downloads, transcode cache) get `chattr +C` / nodatacow**
to avoid CoW fragmentation (important for torrents) and pointless checksumming of
throwaway data.

This is the tier the service stacks land on — it must exist before any service or
migration work that references "the SSD tier" can land its data. The OS root no
longer being a btrfs raid1 means this pool is built cleanly by Ansible as a NAS
storage role (sibling to the HDD-pool role), not carved out during the install.

Drives should be referenced by stable identifiers so the mirror survives reboots
and re-cabling.

**Human prerequisite:** the two 500 GB SATA SSDs must be physically installed and
cabled — per the BUILD-LOG they are not yet present.

Depends on `issues/002` (Ansible foundation + a configured host).

## Acceptance criteria

- [ ] Both 500 GB SSDs are healthy under smartctl and enumerate.
- [ ] A btrfs raid1 filesystem spans both SSDs and survives a reboot, mounted at a
      stable location.
- [ ] Precious subvolumes (appdata, Immich, Paperless) carry full CoW + checksums;
      the scratch subvolumes (downloads, transcode cache) are nodatacow
      (`chattr +C` confirmed) and excluded from checksumming.
- [ ] A simulated single-drive loss is survived with data intact (mirror degrades,
      not fails).
- [ ] The tier is built by an idempotent Ansible storage role run from krypton.
