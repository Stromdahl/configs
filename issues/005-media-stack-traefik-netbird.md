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

- [ ] Jellyfin is reachable at `jellyfin.home.stromdahl.tech` **over the NetBird
      mesh** with a valid (non-self-signed) TLS certificate. *(cert ✅ real LE; mesh
      reachability blocked on the DNS mapping below — needs-human)*
- [ ] Nothing is reachable from the public internet; no router port-forward exists.
      *(needs-human: user attests no router port-forward)*
- [x] No container-published port is exposed on the **LAN** by Docker bypassing
      ufw — published ports bind to loopback / the NetBird interface (or
      `DOCKER-USER` rules reinstate the default-deny), verified from another LAN host.
      *(verified 2026-06-30 from krypton: :80/:443 to helium's LAN IP both time out)*
- [ ] Jellyfin transcodes using the iGPU (QuickSync). *(render device RW-accessible
      in-container; needs-human: confirm QuickSync in a real stream via the UI)*
- [x] Jellyfin reads the library from the HDD pool mount; its config (appdata) and
      transcode cache live on the SSD tier. *(verified 2026-06-30: `/media` ro from
      `/srv/media`, `/config`+`/transcode` on the SSD tier)*
- [x] The stack is brought up by the Ansible compose-stack role from krypton, with
      secrets sourced from sops. *(verified 2026-06-30)*

## Status — 2026-06-30 (in-progress; machine-side done)

Deployed and running; idempotent. The remaining ACs need the user's hands — see
the handoff in `hosts/helium/BUILD-LOG.md` (2026-06-30 entry). The single gating
item is **DNS**: map `jellyfin`/`traefik.home.stromdahl.tech` → helium's mesh IP
`100.65.22.72` (NetBird DNS, or a Cloudflare A record), which the playbook does
not and cannot do (DNS-01 only writes cert-validation TXT records).
