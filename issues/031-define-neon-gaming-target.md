---
title: Define neon's gaming target — game library, resolution, anti-cheat/Windows needs
status: done
priority: high
created: 2026-07-11
closed: 2026-07-11
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Question

What does this rig actually have to run, and how well? This sets the bar the
GPU and storage decisions are measured against, so it comes before them.

Pin down:
- **Which games / kinds of games** — the specific titles or genres that matter
  (AAA vs indie vs emulation), and whether any are **anti-cheat / kernel-level**
  titles that only run on Windows (this is the single fact that decides whether
  a Windows dual-boot is on the table).
- **Target fidelity** — resolution + rough FPS expectation (1080p60? 1440p?),
  which sets the minimum viable GPU.
- **Steam/Proton only, or also** emulators, Lutris, Heroic/EGS, etc.
- **Rough game-library size** on disk, feeding the storage decision.

Grill one question at a time; resolve with a crisp statement of the target.

Type: grilling (HITL) · Blocks: 032, 033

## Answer

Resolved by grilling 2026-07-11.

- **Must-run library:** Valheim, Planet Crafter, Enshrouded — survival / co-op /
  single-player. All Proton-clean; **none use kernel-level anti-cheat**.
- **Platform:** Steam + Proton **only**. No Lutris/Heroic/EGS, no emulators.
- **Boot model:** **single-boot Debian, no Windows.** The anti-cheat/dual-boot
  branch is closed — nothing in the library forces Windows. (Answers the boot half
  of `issues/033`.)
- **Fidelity target:** **native 3440×1440 (ultrawide UWQHD) @ 60 fps, medium-high
  settings.** The panel is 144 Hz, so refresh headroom above 60 is a bonus in the
  two lighter titles, **not** a build requirement — sustained 100+ fps at native
  ultrawide is not realistic on either candidate GPU. Enshrouded is the load-bearing
  title (heaviest of the three).
- **Library size:** ~30–60 GB for the three games — trivial on the 2 TB NVMe.
- **Display (verified live via the rescue OS):** 3440×1440 ultrawide on HDMI-A-1,
  144 Hz. Confirms the display sub-question of `issues/034`.

Downstream: `issues/032` (GPU) is measured against native ultrawide 3440×1440@60,
which is ~34% heavier than standard 1440p and **tilts toward the RTX 2060** (the
1070 clears the two lighter games but Enshrouded lands ~40–50 fps high at this res);
`issues/033` boot model is settled (single-boot), leaving only the `nvme0n1`
wipe-confirm.
