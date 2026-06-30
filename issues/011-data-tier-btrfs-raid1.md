---
title: Data tier — btrfs raid1 SSD mirror with nodatacow scratch subvolumes
status: in-progress
priority: high
created: 2026-06-29
closed: null
labels: [epic:storage, needs-human]
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
and re-cabling. **Use `ata-KINGSTON_SUV400S37480G_<serial>`, not `wwn-*`:** both
SSDs share an identical malformed WWN (`0 550380 440010000`, NAA=0 — a known
Kingston UV400 firmware bug), so no usable `/dev/disk/by-id/wwn-*` link exists. The
per-serial `ata-*` links are the only unique, safe identifiers (sde =
`…50026B767400167E`, sdf = `…50026B776705BF4D`). Applies to the mkfs/mount role,
fstab, and any smartd / disk-replacement runbook.

**Human prerequisite:** both data-tier SSDs must be physically installed and
cabled. As of 2026-06-29 **both are now available** and the tier builds raid1 in
one shot — no degraded/single-device window. The second SSD is the **Kingston
SUV400 447 GB** released from neon (it was neon's OS drive): `/home/ms` was backed
up to krypton, neon's *arr state is intentionally dropped (rebuilt on helium), and
neon's games + media library stay safe on its NVMe. See the BUILD-LOG entry for
2026-06-29. This resolves the latent build-graph cycle where the second SSD would
otherwise only be freed at neon retirement (`issues/009`), downstream of this
issue — neon no longer needs to keep serving, so its SSD is freed up front.

Note: on install, **both** SSDs turned out to be the same `KINGSTON SUV400S37480G`
480 GB (447 GiB) — a matched pair, not the "500 GB + 447 GB" mix earlier notes
assumed. Usable raid1 capacity ~447 GiB — ample (hot data is ~15 GB).

Depends on `issues/002` (Ansible foundation + a configured host).

**Manual verification (human hands):** two acceptance criteria can't be completed
by the Ansible run alone — *reboot survival* (a human reboots helium and confirms
the pool re-mounts) and *simulated single-drive loss* (a human offlines/pulls one
SSD at the console, confirms a degraded mount with data intact, then re-adds and
rebalances). Building the tier itself is fully automatable from krypton. Briefed in
`tasks/011`.

## Acceptance criteria

- [x] Both SSDs are healthy under smartctl and enumerate. **Done 2026-06-29:**
      both `KINGSTON SUV400S37480G` 480 GB — overall-health PASSED, 0 reallocated/
      pending/uncorrectable, ~95–96 % life left, extended self-test completed
      without error. See the BUILD-LOG entry for 2026-06-29.
- [ ] A btrfs raid1 filesystem spans both SSDs and survives a reboot, mounted at a
      stable location. **Built + verified 2026-06-30:** label `helium-ssd`, 2 devices
      (sde, sdf), Data/Metadata/System all RAID1, mounted by fs UUID at `/data/ssd/*`.
      **Reboot survival pending human:** after `sudo reboot`, check `findmnt /data/ssd/appdata`
      returns a mount — an *absent* mount is the failure (multi-device btrfs needs udev's
      `btrfs device ready` to see BOTH sde+sdf before systemd gives up, and `nofail` means
      a failed scan boots silently with the pool unmounted). If missing, the fix is on the
      device-scan side (`btrfs device scan`, check the btrfs-progs udev rule fired), NOT the
      fstab — the fstab is verified correct.
- [x] Precious subvolumes (appdata, Immich, Paperless) carry full CoW + checksums;
      the scratch subvolumes (downloads, transcode cache) are nodatacow
      (`chattr +C` confirmed) and excluded from checksumming. **Verified 2026-06-30:**
      `lsattr -d` shows `C` on downloads/transcode, clean on appdata/immich/paperless.
- [ ] A simulated single-drive loss is survived with data intact (mirror degrades,
      not fails). **Pending human (console):** offline one SSD, `mount -o degraded`,
      confirm data intact, re-add + `btrfs balance ... -dconvert=raid1 -mconvert=raid1`.
- [x] The tier is built by an idempotent Ansible storage role run from krypton.
      **Verified 2026-06-30:** `ansible/roles/storage_ssd` run via `--tags storage_ssd`;
      a clean second run reports `changed=0`.
