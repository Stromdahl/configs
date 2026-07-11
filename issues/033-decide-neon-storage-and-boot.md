---
title: Decide neon's storage layout and boot model (single Debian vs dual-boot Windows)
status: done
priority: medium
created: 2026-07-11
closed: 2026-07-11
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Description

Depends on `issues/031` (whether any anti-cheat title forces a Windows dual-boot).
`issues/030` is done: the sole internal drive is the **Samsung 990 PRO 2 TB NVMe**
(the 480 GB SATA SSD was harvested for helium) — capacity is ample, so the
capacity/purchase sub-question is closed and only the boot model remains.

> **Unblocked — `issues/031` resolved (2026-07-11):** boot model is decided —
> **single-boot Debian, no Windows** (the library is Proton-clean, no kernel
> anti-cheat). The dual-boot fork is closed. All that remains here is confirming it's
> fine to **wipe `nvme0n1`** (old docker-host data — nothing to preserve, role retired
> to helium) and the single-OS NVMe layout. Nearly a formality.

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

## Answer

Resolved 2026-07-11. **Single-boot Debian, no Windows** (settled by 031 — Proton-clean
library). Inspected the drive live over the rescue OS to settle the layout:

**Drive ground truth:** `nvme0n1` (Samsung 990 PRO 2 TB) is a **raw ext4 filesystem
with no partition table** — it was old neon's *data* drive, not its boot drive (neon
booted off the now-harvested 480 GB SATA SSD). It was 100 % full:
- `media/` + `downloads/` — **1.5 TB** old Jellyfin/*arr data → **disposable** (role
  retired to helium; user confirmed OK to lose, incl. anything beyond issue 008's
  migration).
- `steam/` — **203 GB**, 14-app Steam library (Split Fiction, Hogwarts Legacy, Green
  Hell, Hollow Knight, Deep Rock Galactic, Factorio, …) → **preserve.**

**Preservation:** back up `steam/` to **helium over the gigabit LAN** and restore it
after install (faster and exact vs a ~200 GB re-download over home internet; keeps
Proton prefixes / local saves).

**Partition layout — fresh GPT, wipe `nvme0n1`:**

| Part | Size | Mount | FS | Purpose |
|---|---|---|---|---|
| ESP | 1 GB | `/boot/efi` | FAT32 | UEFI boot |
| OS | ~150 GB | `/` | ext4 | Debian + KDE + Steam/Proton runtime |
| Games | ~1.85 TB | dedicated mount, added as a Steam library | ext4 | the 203 GB library + growth |

ext4 on the games partition on purpose (btrfs CoW fragments large Steam files). No LVM.

**Future second drive is handled by this shape** (user wants to be ready for one):
games live on their own partition/mount, so a later drive slots in with no
repartitioning — either added as a **second Steam library folder** (games-only), or
the new drive takes the OS and this whole 2 TB becomes games.

**Install procedure (feeds the build ticket):** rsync `steam/` → helium → wipe
`nvme0n1` → GPT (ESP / OS / games) → install Debian 13 to the OS partition → rsync
`steam/` back onto the games partition → register it as a Steam library.
