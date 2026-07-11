---
title: Decide neon's storage layout and boot model (single Debian vs dual-boot Windows)
status: open
priority: medium
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Description

Depends on `issues/030` (which disks remain) and `issues/031` (library size +
whether any anti-cheat title forces a Windows dual-boot).

## Question

Where does the OS and the game library live, and is one OS enough?

- **Capacity:** if only the 480 GB SATA SSD remains, is that enough for Debian +
  the intended library, or does storage need buying (an NVMe back in the M.2
  slot)? The target size from issue 031 decides this.
- **Boot model:** single-boot Debian, or **dual-boot Windows** — driven entirely
  by whether issue 031 surfaced anti-cheat/kernel titles that can't run under
  Proton. If dual-boot, that reshapes partitioning and the install procedure.
- **Install target:** which physical disk Debian installs to, and what happens to
  any leftover data on the surviving drives.

Resolve with the chosen disk layout, boot model, and install target.

Type: grilling (HITL) · Depends on: 030, 031
