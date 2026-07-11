---
title: Rewrite hosts/neon docker-host profile into a KDE gaming-desktop profile
status: in-progress
priority: high
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:task]
---

## Description

Turn neon's host profile from its retired docker-host shape into a **desk gaming
desktop**, composing the existing titan-100 gaming module suite **minus the
couch/HTPC layer**. neon keeps its hostname and identity — this is a rewrite of the
`hosts/neon/` profile in place, not a new element.

The gaming stack is the one already proven on titan-100:
`i386-multiarch`, `nvidia`, `pipewire`, `kde`, `flatpak`, `steam`, `gamepad`, on top
of the common modules every host gets (`base`, `ssh`, …). The `nvidia` module applies
**as-is** — issue 032 settled the GPU as the RTX 2060 (Turing), the exact card the
module is already proven on. The box boots to a **normal KDE desktop**; Steam is
launched manually.

**Explicitly excluded** (the titan-100 couch layer, ruled out of scope in the PRD):
`couch-user`, `sddm-autologin`, `htpc-tweaks`, and any Big-Picture autostart. No
autologin, no CEC, no living-room launcher — this is a machine the user sits at.

Depends on `issues/032` (GPU decided → `nvidia` confirmed in the list; done). Touches
only `hosts/neon/`, so it can proceed **in parallel with `issues/036`** (which removes
the old server identity). Pure in-repo work — no physical machine needed; verified by
`--dry-run`.

## Acceptance criteria

- [ ] neon's `modules.conf` lists the gaming-desktop stack (common modules + `i386-multiarch`, `nvidia`, `pipewire`, `kde`, `flatpak`, `steam`, `gamepad`) and **none** of titan-100's couch modules.
- [ ] No docker-host / server modules remain in neon's module list.
- [ ] `./install.sh --host neon --dry-run` runs clean end-to-end from krypton (no missing-module or unresolved-package errors) and previews the gaming stack.
- [ ] The profile is diffable against `hosts/titan-100/` and the only intended delta is the removed couch layer.
