---
title: Jellyfin over the mesh — internal Traefik + NetBird + the compose-stack role
status: in-progress
priority: high
created: 2026-06-27
closed: null
labels: [epic:services, needs-human]
---

## Description

Stand **Jellyfin** up on helium and make it reachable **privately only** — the
"watch my library again, over the mesh" milestone. This is the keystone services
slice: it establishes the **access plumbing every later service reuses**, then runs
Jellyfin on top of it. Deliberately scoped to Jellyfin + plumbing so it is a thin,
demoable vertical slice; the download-automation half (gluetun + qBittorrent + the
*arr stack + Jellyseerr) is `issues/014`, and Immich/Paperless are `issues/006`/`007`.

The plumbing this slice builds:

- A **compose-stack Ansible role** that templates the stack's env/secrets (from
  sops) and runs `docker compose up`.
- **Traefik internal-only**, obtaining real certificates via **Let's Encrypt
  DNS-01** with the existing Cloudflare token (no inbound exposure, no router
  port-forward), routing `*.home.stromdahl.tech`.
- **NetBird client** joined to the mesh (cloud control plane, free personal tier);
  service hostnames resolve to the box's mesh IP via NetBird DNS.
- The **Docker-bypasses-ufw** fix (see note) — closed here once, reused everywhere.

Then **Jellyfin** itself: iGPU/QuickSync transcoding, reading its media from the
HDD pool mount (`issues/003`), with config (appdata) and transcode cache on the SSD
tier (`issues/011`). Stand it up with fresh config here; migrating the real library
is `issues/008`.

**Note — Docker bypasses ufw.** Containers started with published ports (`-p`)
insert their own iptables rules *ahead* of ufw, so the base role's default-deny
does **not** cover them — a published port is reachable on the LAN regardless of
ufw. For the all-private model to hold, published ports must bind to loopback / the
NetBird mesh interface, or `DOCKER-USER` rules must reinstate the default-deny. This
is plumbing every later service reuses, so it belongs in this first slice.

Depends on `issues/002` (docker host), `issues/003` (the pool the media mount comes
from), and `issues/011` (the data tier appdata + transcode cache live on).

## Acceptance criteria

> **Model revised 2026-06-30 → LAN + mesh, never public** (see Status). AC#3's
> "no LAN exposure" was intentionally dropped: the home LAN is allowed; the public
> boundary is OPNsense having no port-forward + helium having no public IP.

- [x] Jellyfin is reachable at `jellyfin.home.stromdahl.tech` with a valid
      (non-self-signed) TLS certificate. *(verified 2026-06-30 from krypton over the
      LAN: 302→`/web/` 200, `ssl_verify=0`, real LE cert. Mesh path wired via
      split-horizon DNS — see Status; final remote-peer test is needs-human.)*
- [ ] Nothing is reachable from the public internet; no port-forward exists.
      *(needs-human: user attests OPNsense has no 80/443 port-forward to helium)*
- [x] ~~No container-published port is exposed on the LAN~~ **superseded by the
      LAN+mesh model** — LAN access is intentional. The DOCKER-USER drop is kept
      ABSENT via `compose_restrict_to_mesh: false`. *(Strict mesh-only stays a
      one-var flip; the drop was verified working on 2026-06-30 before the flip.)*
- [ ] Jellyfin transcodes using the iGPU (QuickSync). *(render device RW-accessible
      in-container; needs-human: confirm QuickSync in a real stream via the UI)*
- [x] Jellyfin reads the library from the HDD pool mount; its config (appdata) and
      transcode cache live on the SSD tier. *(verified 2026-06-30: `/media` ro from
      `/srv/media`, `/config`+`/transcode` on the SSD tier)*
- [x] The stack is brought up by the Ansible compose-stack role from krypton, with
      secrets sourced from sops. *(verified 2026-06-30)*

## Status — 2026-06-30 (in-progress)

Deployed, running, idempotent, and **reachable over the LAN with a valid cert**
(`https://jellyfin.home.stromdahl.tech`). DNS is an **OPNsense Unbound** host
override `*.home.stromdahl.tech → 192.168.1.191` (helium's LAN IP). Exposure model
is **LAN + mesh, never public** (`compose_restrict_to_mesh: false`; DOCKER-USER drop
removed). Details in `hosts/helium/BUILD-LOG.md` (2026-06-30).

**Remote access (done 2026-06-30):** split-horizon DNS — a public Cloudflare
wildcard `*.home.stromdahl.tech` A → `100.65.22.72` (helium's mesh IP, DNS-only)
serves roaming NetBird devices, while OPNsense Unbound keeps serving the LAN IP to
home clients. Verified public resolvers return the mesh IP, LAN still returns
`.191`, and helium serves the name+valid cert on `100.65.22.72`.

Remaining (needs the user's hands):
- **Remote-peer test:** from a roaming NetBird device (phone on cellular), open
  `https://jellyfin.home.stromdahl.tech/` — should load on the valid cert over the mesh.
- **iGPU transcode (AC#4):** confirm QuickSync in a real stream + set the transcode
  temp path to `/transcode` in the Jellyfin UI.
- **No public port-forward (AC#2):** confirm on OPNsense.
- Real library still empty (`/srv/media`) — that's `issues/008`.
