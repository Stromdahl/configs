---
title: Decide neon's GPU — reuse existing / iGPU / buy
status: open
priority: high
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Description

Depends on `issues/030` (what GPU, if any, is still in the chassis) and
`issues/031` (the fidelity target the GPU must hit).

## Question

How does neon get a GPU capable of the target from issue 031?

Weigh the branches the inventory leaves open:
- **A discrete card survived** (e.g. the GTX 1070 is still in): does it clear the
  target, and does the `nvidia` module (written for Turing) drive Pascal cleanly?
- **Only the Intel HD 530 iGPU remains:** viable for light/indie/emulation only —
  is that enough, or a non-starter for the target?
- **Buy a card:** if so, roughly which tier / budget, and NVIDIA (reuse the
  `nvidia` module path) vs AMD (different, simpler mesa path — a module that
  doesn't exist yet)?

The GPU vendor choice ripples into the host profile (`nvidia` module vs an AMD
mesa module) — so this decision also settles that fog. Resolve with the chosen
GPU and the driver/module implication.

Type: grilling (HITL) · Depends on: 030, 031
