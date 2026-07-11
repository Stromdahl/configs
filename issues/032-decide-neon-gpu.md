---
title: Decide neon's GPU — reuse existing / iGPU / buy
status: open
priority: high
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:grilling]
---

## Description

Depends on `issues/031` (the fidelity target the GPU must hit). `issues/030` is
done: the **GTX 1070 is still installed** — no card was harvested — so this is no
longer a reuse/iGPU/buy fork but a "is the surviving card enough" check.

## Question

Does the in-place **GTX 1070** clear the target from issue 031?

- If the target is 1080p (and most 1440p) it comfortably does → reuse as-is, and
  the only follow-up is the **Pascal / `nvidia` module** check (the module was
  written for Turing — same driver family, confirm it drives GP104 cleanly).
- Only if the target turns out to be high-refresh 1440p / 4K AAA does an upgrade
  come back on the table — and only then does NVIDIA-vs-AMD (and a possible AMD
  mesa module) matter.

Resolve with: reuse the 1070 (expected) or a named upgrade, plus the driver/module
implication for the profile rewrite.

Type: grilling (HITL) · Depends on: 031
