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

> **Unblocked — `issues/031` resolved (2026-07-11):** target is **native 3440×1440
> ultrawide @ 60 fps, medium-high** (144 Hz panel; refresh headroom a bonus). This is
> ~34% heavier than standard 1440p, so the choice is now the live **RTX 2060 vs GTX
> 1070** call: the user has a spare 2060 (likely the ex-titan-100 passthrough card).
> The 1070 clears Valheim/Planet Crafter but **Enshrouded** lands ~40–50 fps high at
> native ultrawide; the 2060 does better (DLSS/NVENC, and the `nvidia` module is
> already proven on exactly that Turing card — moots the Pascal check). Caveat: vanilla
> 2060 is **6 GB** vs the 1070's 8 GB — confirm the card + VRAM variant (6 GB / 8 GB
> Super / 12 GB) to resolve.

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
