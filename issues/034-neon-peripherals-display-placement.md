---
title: Settle neon's peripherals, display, and physical placement
status: open
priority: low
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:task]
---

> **Display sub-question confirmed via `issues/031` (2026-07-11):** a monitor is
> present and verified live off the rescue OS — **3440×1440 ultrawide, 144 Hz, on
> HDMI-A-1.** Remaining here: keyboard + mouse for the desk, physical placement, and
> wired 1 GbE (onboard I219-V) vs Atheros WiFi.

## Question

A desk gaming rig needs a place to sit and things to plug into — confirm these
exist so they don't become a surprise blocker after the box is provisioned.

- **Display:** is there a monitor for it (resolution/refresh — this cross-checks
  the fidelity target in issue 031), and how does it connect (the GPU decision in
  issue 032 constrains available outputs)?
- **Input:** keyboard + mouse for the desk; controllers are already handled by
  the `gamepad` module.
- **Placement + connectivity:** where the box physically lives, and whether it's
  on wired 1 GbE (onboard I219-V) or needs the Atheros WiFi.

Not blocked by inventory — this is about what the user has/needs around the
machine. Resolve with a short confirmation (or a shopping note if something's
missing).

Type: task (HITL) · unblocked
