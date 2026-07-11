---
title: Decide neon's storage layout and boot model (single Debian vs dual-boot Windows)
status: open
priority: medium
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Description

Depends on `issues/031` (whether any anti-cheat title forces a Windows dual-boot).
`issues/030` is done: the sole internal drive is the **Samsung 990 PRO 2 TB NVMe**
(the 480 GB SATA SSD was harvested for helium) — capacity is ample, so the
capacity/purchase sub-question is closed and only the boot model remains.

## Question

Is one OS enough on the 2 TB NVMe, or is a Windows dual-boot needed?

- **Boot model:** single-boot Debian (expected), or **dual-boot Windows** —
  driven entirely by whether issue 031 surfaced anti-cheat/kernel titles that
  can't run under Proton. If dual-boot, decide the Windows/Debian split of the
  2 TB and the partition/install order.
- **Install target:** confirm Debian installs to `nvme0n1`, and that wiping the
  old docker-host data on it is fine (nothing to preserve — the role retired to
  helium).

Resolve with the boot model and the NVMe layout.

Type: grilling (HITL) · Depends on: 031
