---
title: Install a plain single-disk Debian boot OS on the NVMe
status: done
priority: high
created: 2026-06-27
closed: 2026-06-29
labels: [epic:bootstrap]
---

## Description

Stand up the base operating system for helium: a plain single-disk Debian install
on the 970 EVO Plus 250 GB NVMe, carrying the **OS/boot only** and kept lean. The
NVMe is a single non-redundant drive — an accepted trade, because the OS is fully
Ansible-reproducible: a failure means reinstall + re-run, with all data intact on
the redundant tiers below.

The NVMe still holds titan's old Proxmox install — a full LVM stack
(`pve-root`, `pve-data` thin pool, `pve-swap`) — which must be wiped during the
install.

The btrfs **raid1 data pool** across the two 500 GB SSDs is no longer part of this
step: it is built later by Ansible as a NAS storage role. The earlier "a raid1
root can't be built from within the same Ansible run" constraint that forced a
manual mirror no longer applies now that the root is a single NVMe.

This issue also covers the physical-build prerequisites that gate a stable boot:
the HBA is seated in the PCIe x16 slot with active cooling confirmed, and all four
SAS drives plus both SSDs enumerate.

**Human step:** requires physical access (install media, BIOS settings, cabling).

## Acceptance criteria

- [x] Debian boots from a plain single-disk root on the 970 EVO Plus NVMe.
      **Done 2026-06-29:** Debian 13.5 trixie, native **UEFI** boot (GPT, ESP at
      `nvme0n1p1` → `/boot/efi`, root ext4 `nvme0n1p2`, `grub-efi-amd64` via shim).
- [x] titan's old Proxmox LVM stack on the NVMe is wiped — no stale `pve-*` volumes
      remain. (NVMe zapped from the rescue OS before reinstall; no pve-* devices.)
- [x] All 4× 12 TB SAS drives enumerate through the HBA, and both 500 GB SSDs are
      visible. (sda–sdd SAS, sde/sdf Kingston SSDs, all present.)
- [x] The HBA is seated in the PCIe x16 slot with active airflow (Noctua fan)
      confirmed. (Confirmed in the 2026-06-28 build session; SAS3008 + 4 disks live.)
- [x] An admin user with the standard SSH key is present and reachable over SSH.
      (`ms`, in `sudo` group; key-auth SSH from krypton confirmed.)
