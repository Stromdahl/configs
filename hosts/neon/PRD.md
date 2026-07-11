# neon — reborn as a Debian gaming desktop (wayfinder map)

> Wayfinder map for bringing **neon's physical body back to life** as a
> personal, desk-based Debian gaming rig. neon was the Debian docker host
> (Jellyfin + *arr); its role migrated to helium (issue 009) and parts of it
> were harvested to build helium. The chassis remains — same ASUS Z170I / i5-6600K
> box — and gets a second life as a machine the user sits at and games on.
>
> This file is the **map**: the low-resolution index. Tickets are `issues/NNN`
> tagged `epic:neon-gaming` + a `wayfinder:<type>` label; blocking is the repo's
> inline `Depends on issues/NNN`. Charted from a grilling session 2026-07-11.

## Destination

A **decided build plan** for reprovisioning the neon chassis as a single-user,
desk-based Debian gaming desktop — managed by this dotfiles repo (the existing
`hosts/neon/` docker-host profile rewritten to a gaming-desktop `modules.conf`),
reusing titan-100's gaming module suite **minus** the couch/HTPC layer. The map
is done when every hardware, storage, and profile decision below is resolved and
the executable build issues are written — i.e. nothing is left to *decide* before
someone provisions the box.

Scope-fixing decisions taken while naming the destination:
- **Desk rig, not couch.** Monitor + keyboard/mouse, boots to a normal KDE
  desktop, Steam launched manually. titan-100's couch layer (`couch-user`,
  `sddm-autologin`, `htpc-tweaks`, Big Picture autostart) is **out of scope**.
- **Keep the hostname `neon`.** Same physical chassis → reuse the identity;
  rewrite `hosts/neon/` in place rather than mint a new element.

## Notes

- **Domain:** dotfiles module system (`AGENTS.md` at repo root). A "gaming rig"
  here means composing existing modules into a host profile, not building tools
  from scratch — the whole software stack already exists for titan-100.
- **Reference host:** `hosts/titan-100/` is the near-template (desk variant =
  titan-100 minus the couch modules). Its gaming stack: `i386-multiarch`,
  `nvidia`, `pipewire`, `kde`, `flatpak`, `steam`, `gamepad`.
- **Stale data warning:** `hosts/neon/HARDWARE.md` describes neon *before* it was
  gutted for helium (still lists GTX 1070, 990 PRO 2 TB NVMe, 16 GB RAM). Do not
  trust it — the inventory ticket refreshes it against ground truth.
- **Live access:** neon's body is currently booted on the **Debian rescue OS**
  (Ventoy `debian-rescue.img.vtoy`) and is on the network, so the inventory ticket
  is AFK-runnable over SSH. Follow the AGENTS.md SSH rules (`ssh-add -l` first).
- **Skills:** `/grilling` + `/domain-modeling` for decision tickets;
  `/dotfiles-module` when the profile/module work graduates from fog.

## Decisions so far

<!-- index — one line per closed ticket; zoom the link for detail -->

- [Inventory neon's current hardware](../../issues/030-inventory-neon-current-hardware.md) —
  chassis is intact (GTX 1070 + 2 TB 990 PRO NVMe + 16 GB all present); helium
  took only the secondary 480 GB SATA SSD. No GPU/storage purchase implied.
- [Define neon's gaming target](../../issues/031-define-neon-gaming-target.md) —
  Valheim / Planet Crafter / Enshrouded, Steam+Proton only, **no Windows**
  (single-boot Debian). Target: **native 3440×1440 ultrawide @ 60 fps**, medium-high
  (panel is 144 Hz — headroom a bonus, not a requirement). Ultrawide load tilts the
  GPU call toward the RTX 2060.
- [Decide neon's GPU](../../issues/032-decide-neon-gpu.md) —
  **swap the GTX 1070 for the RTX 2060** (ex-titan-100 card, on the desk). DLSS
  clears native 3440×1440@60 on Enshrouded; the `nvidia` module is already proven
  on this exact Turing card, so it enters `modules.conf` as-is and the Pascal-compat
  question is moot.

## Not yet specified

<!-- in-scope fog; graduates into tickets as the frontier advances -->

- **Rewrite `hosts/neon/` docker-host profile → gaming-desktop `modules.conf`**
  (adapt titan-100 minus couch layer). GPU decision is settled (issue 032):
  **`nvidia` is in the list** (RTX 2060, Turing). Ready to graduate into a build
  ticket.
- **Retire neon's old server role from the repo** — prune the deploy pipeline
  bits (`deploy-user`, `bare-git-repo`, `sops`) and docker-host framing from
  `hosts/neon/`. Graduates alongside the profile rewrite.
- **Bare-metal Debian 13 install procedure** for the desk rig (which disk, boot
  mode, partition layout). Graduates once storage/boot (issue 033) is decided.

## Out of scope

<!-- ruled beyond the destination; never graduates -->

- **Couch/HTPC layer** — decided desk rig; no autologin-to-Big-Picture, no CEC,
  no living-room launcher.
- **Any homelab / docker / server workload on neon** — that role retired to
  helium in issue 009. neon is now purely a personal gaming desktop; the
  git-push deploy pipeline and Jellyfin/*arr do not return.
