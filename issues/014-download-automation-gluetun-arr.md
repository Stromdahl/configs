---
title: Download automation — gluetun + qBittorrent + *arr + Jellyseerr behind the mesh
status: in-progress
priority: medium
created: 2026-06-30
closed: null
labels: [epic:services, needs-human]
---

## Description

Add the download-automation half of the media stack on top of the plumbing
`issues/005` establishes (the compose-stack role + internal Traefik + NetBird
mesh). This was carved out of the original media-stack issue so Jellyfin could ship
first as its own milestone; everything here is about *acquiring* media, not serving
it.

The services, all behind the existing internal Traefik (`*.home.stromdahl.tech`,
mesh-only):

- **gluetun** — VPN egress (Mullvad/WireGuard), retained for ISP privacy.
- **qBittorrent** behind gluetun (`network_mode: service:gluetun`, kill-switch), with
  downloads on the SSD scratch tier.
- The **\*arr stack** — radarr, sonarr, prowlarr, bazarr, profilarr (prowlarr also
  routed through gluetun) — config on the SSD appdata tier, reading/writing the
  media pool + downloads.
- **Jellyseerr** — request management, feeding the *arr stack.

Stand these up with **fresh config following TRaSH Guides best practices** —
folder structure, naming, quality profiles, and custom formats. (Migrating neon's
*arr state was scoped as `issues/015` but **dropped** in favor of this fresh build.)

**Hardlink note:** downloads live on the SSD scratch tier and media on the HDD pool
— two filesystems — so *arr imports are **copy-then-delete**, not instant hardlink /
atomic moves. This is an intentional deviation from TRaSH's single-filesystem
hardlink requirement, accepted to keep the HDD pool cold/quiet/parity-only (helium
drops long-term ratio seeding, the main thing hardlinks buy).

Depends on `issues/005` (the compose-stack role + internal Traefik + NetBird mesh
this all plugs into).

## Acceptance criteria

- [ ] gluetun reports the VPN egress IP, and qBittorrent's traffic egresses through
      it (kill-switch verified: stopping gluetun kills qBittorrent connectivity).
- [ ] Each *arr service and Jellyseerr is reachable at its `*.home.stromdahl.tech`
      URL over the mesh with a valid cert; nothing is publicly reachable, and no
      published port leaks on the LAN (the `issues/005` Docker/ufw fix holds).
- [ ] The *arr stack reads the media pool and writes downloads to the SSD scratch
      tier; config (appdata) lives on the SSD precious tier.
- [ ] The services are brought up by the Ansible compose-stack role from krypton,
      with secrets sourced from sops.
