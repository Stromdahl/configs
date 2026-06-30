---
title: Media stack over the mesh — Jellyfin + Jellyseerr + *arr + gluetun behind internal Traefik and NetBird
status: open
priority: high
created: 2026-06-27
closed: null
labels: [epic:services]
---

## Description

Bring the neon media stack up on helium and make it reachable **privately only**.
This is the first slice of the all-private access model, so it establishes the
plumbing every later service reuses:

- A compose-stack Ansible role that templates the stack's env/secrets (from sops)
  and runs `docker compose up`.
- **Traefik internal-only**, obtaining real certificates via **Let's Encrypt
  DNS-01** with the existing Cloudflare token (no inbound exposure, no router
  port-forward), routing `*.home.stromdahl.tech`.
- **NetBird client** joined to the mesh (cloud control plane, free personal tier —
  control plane is not self-hosted); service hostnames resolve to the box's mesh IP
  via NetBird DNS.
- The media services themselves: Jellyfin (iGPU/QuickSync transcoding), Jellyseerr,
  the *arr stack, and qBittorrent behind **gluetun** (retained for ISP privacy).

Stand the stack up with fresh config here; migrating real library data and *arr
state is a separate cutover slice. Jellyfin reads its media from the HDD pool
mount; downloads/transcode cache live on the SSD tier.

**Note — Docker bypasses ufw.** Containers started with published ports (`-p`)
insert their own iptables rules *ahead* of ufw, so the base role's default-deny
does **not** cover them — a published port is reachable on the LAN regardless of
ufw. For the all-private model to actually hold (not just against the public
internet), published ports must bind to loopback / the NetBird mesh interface, or
`DOCKER-USER` rules must reinstate the default-deny. This is plumbing every later
service reuses, so it belongs in this first slice.

Depends on `issues/002` (docker host), `issues/003` (the pool the media mount
comes from), and `issues/011` (the data-tier mirror the downloads/transcode cache
and appdata live on).

## Acceptance criteria

- [ ] Each service is reachable at its `*.home.stromdahl.tech` URL **over the
      NetBird mesh** with a valid (non-self-signed) TLS certificate.
- [ ] Nothing is reachable from the public internet; no router port-forward exists.
- [ ] No container-published port is exposed on the **LAN** by Docker bypassing
      ufw — published ports bind to loopback / the NetBird interface (or
      `DOCKER-USER` rules reinstate the default-deny), verified from another LAN host.
- [ ] gluetun reports the VPN egress IP, and qBittorrent's traffic egresses through
      it (kill-switch verified).
- [ ] Jellyfin transcodes using the iGPU (QuickSync).
- [ ] The stack is brought up by the Ansible compose-stack role from krypton, with
      secrets sourced from sops.
