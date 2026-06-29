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

**Human prerequisite:** both data-tier SSDs must be physically installed and
cabled. As of 2026-06-29 **both are now available** and the tier builds raid1 in
one shot — no degraded/single-device window. The second SSD is the **Kingston
SUV400 447 GB** released from neon (it was neon's OS drive): `/home/ms` was backed
up to krypton, neon's *arr state is intentionally dropped (rebuilt on helium), and
neon's games + media library stay safe on its NVMe. See the BUILD-LOG entry for
2026-06-29. This resolves the latent build-graph cycle where the second SSD would
otherwise only be freed at neon retirement (`issues/009`), downstream of this
issue — neon no longer needs to keep serving, so its SSD is freed up front.

Note: the Kingston is 447 GB, so a raid1 across it and a 500 GB SSD yields usable
capacity capped to the smaller drive (~447 GB) — still ample (hot data is ~15 GB).

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
