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
- [Decide storage & boot](../../issues/033-decide-neon-storage-and-boot.md) —
  **single-boot Debian**; fresh GPT on the 2 TB NVMe: ESP + ~150 GB OS + ~1.85 TB
  games (both ext4). The NVMe was a raw-ext4 *data* drive — its 1.5 TB old Jellyfin
  media is disposable, but the **203 GB Steam library is preserved** by backing it up
  to helium over LAN and restoring it after install. Games on their own partition →
  ready for a future second drive.
- [Settle peripherals & placement](../../issues/034-neon-peripherals-display-placement.md) —
  all on hand, **no shopping:** ultrawide 3440×1440@144 on HDMI, keyboard+mouse ready,
  desk placement, **wired onboard 1 GbE** (no WiFi).

## Charted — the build frontier

<!-- fog has fully graduated; these are the open executable tickets -->

**All decision tickets (030–034) are resolved — nothing is left to *decide*.** The
map's fog graduated into three executable build tickets; the two in-repo ones are now
**done**:

- ✅ [Rewrite neon's profile → gaming desktop](../../issues/035-rewrite-neon-gaming-desktop-profile.md)
  (035, done) — `hosts/neon/modules.conf` is now the titan-100 gaming stack (`nvidia`
  RTX 2060) minus the couch layer; `--host neon --dry-run` clean. (Also dropped
  `qemu-guest-agent` — Proxmox-guest-only, meaningless on bare metal.)
- ✅ [Retire neon's old server role](../../issues/036-retire-neon-server-role.md) (036,
  done) — `servers/neon/`, its `.sops.yaml` rule, and the deploy-doc references are
  gone; surviving sops files still decrypt.
- ✅ [Fix steam & kde modules for couch-less installs](../../issues/038-fix-steam-kde-modules-for-non-couch-desk-installs.md)
  (038, done) — `steam` is now package-only (no `couch` `die`); the Big-Picture autostart
  moved to `htpc-tweaks` (couch layer); `kde` now enables SDDM + sets `graphical.target`
  on any KDE host. Both host dry-runs clean; titan-100 unregressed. Unblocks 037.
- ⬜ [Provision neon bare-metal](../../issues/037-provision-neon-bare-metal.md) (037,
  needs-human) — GPU swap, back up the 203 GB Steam library to helium, wipe + partition
  `nvme0n1` (ESP / OS / games), install Debian 13, apply the 035 profile, restore the
  library. Depends on 035 (done) + 038; awaits the physical session.

> Housekeeping from 036: the stale local `neon` git remote is removed (done). The
> `bup` offsite target still names neon (a backup-architecture decision, left
> untouched).

## Out of scope

<!-- ruled beyond the destination; never graduates -->

- **Couch/HTPC layer** — decided desk rig; no autologin-to-Big-Picture, no CEC,
  no living-room launcher.
- **Any homelab / docker / server workload on neon** — that role retired to
  helium in issue 009. neon is now purely a personal gaming desktop; the
  git-push deploy pipeline and Jellyfin/*arr do not return.
