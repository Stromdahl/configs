---
title: Fix the steam & kde modules so a couch-less desk install boots and installs cleanly
status: in-progress
priority: high
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:task]
---

## Description

Two shared modules assume the titan-100 **couch/HTPC layer** is present, so a
desk-rig install that omits that layer (neon — issue 035) fails or under-configures.
Both surfaced during the 035 profile rewrite; `--dry-run` masks them, so they only
bite a real install. Fix them at the **module** level so the same module works for
both the couch host (titan-100) and the desk host (neon).

1. **`steam` hard-fails without a `couch` user.** The module installs a Steam
   Big-Picture autostart owned by user `couch` and **aborts** (`die`) if that user is
   absent. On neon there is no `couch` — and a desk rig deliberately wants **no
   autostart** (Steam is launched manually). The Big-Picture autostart is an
   HTPC concern, not a property of "Steam is installed." Steam-the-package must
   install cleanly on a couch-less host, and the autostart must only ever land on a
   host that actually runs the couch layer.

2. **`kde` never brings up the display manager on its own.** It installs
   `task-kde-desktop` + `sddm` but does not enable SDDM or set `graphical.target` as
   the default — on titan-100 the couch autologin module did that. Without it, whether
   neon boots to a graphical login is left to Debian's `sddm` postinst behavior. The
   desktop must reliably boot to SDDM on a host that has `kde` but not the autologin
   module.

The fixes must be **idempotent** and must **not regress titan-100** — re-running the
modules on the couch host stays a no-op and its Big-Picture autostart still lands.
Pure in-repo work; no hardware needed. **Blocks `issues/037`** (its "apply the profile"
step runs `steam` on the real box).

## Acceptance criteria

- [ ] Running the `steam` module on a host **without** a `couch` user completes successfully (exit 0) and installs no `couch`-owned autostart — no `die`.
- [ ] On a host **with** the couch layer (titan-100), the Steam Big-Picture autostart still installs correctly and re-running is a no-op.
- [ ] After the `kde` module runs on a host that has **no** autologin module, the box boots to the SDDM graphical login (`systemctl get-default` is `graphical.target` and the display-manager is enabled) — verified on the real neon install, or ensured proactively by the module.
- [ ] `./install.sh --host neon --dry-run` and `./install.sh --host titan-100 --dry-run` both remain clean.
