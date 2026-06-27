---
title: Install Debian on a btrfs raid1 root across the two SSDs
status: open
priority: high
created: 2026-06-27
closed: null
labels: [epic:bootstrap]
---

## Description

Stand up the base operating system for helium: a fresh Debian install whose root
filesystem is a **btrfs raid1 mirror across the two 500 GB SATA SSDs**, so the OS
and (later) all hot/precious data survive a single SSD failure. btrfs is chosen
for data checksumming (the board is non-ECC) and snapshots.

This is a one-time manual/preseed step performed at the machine — a raid1 root
cannot be created from within the Ansible run that later configures the host, so
it is the foundation every other issue builds on. The bootloader/ESP must be set
up so the box still boots with either SSD removed.

This issue also covers the physical-build prerequisites that gate a stable boot:
confirm the HBA has active cooling and the M.2→PCIe adapter has its external power
lead, and that all four SAS drives + both SSDs enumerate.

**Human step:** requires physical access (install media, BIOS settings, cabling).

## Acceptance criteria

- [ ] Debian boots from a btrfs raid1 root spanning both 500 GB SSDs.
- [ ] Pulling either SSD still boots the system (mirror + bootloader verified on
      both members).
- [ ] All 4× 12 TB SAS drives enumerate through the HBA, and both SSDs are visible.
- [ ] HBA has active airflow and the M.2 adapter's external power lead is connected.
- [ ] An admin user with the standard SSH key is present and reachable over SSH.
