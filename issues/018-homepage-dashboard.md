---
title: Single-pane dashboard for the stack (Homepage)
status: done
priority: medium
created: 2026-07-01
closed: 2026-07-01
labels: [epic:services]
---

## Description

helium has no landing page — the `homer` dashboard neon carried was dropped in
the rebuild — so reaching a service means remembering its subdomain, and there is
no at-a-glance view of the stack's state. This slice deploys Homepage as a single
front door: grouped links to every service, live health, and API-fed widgets
(*arr queue depth, qBittorrent speed, disk usage on the tiers). It reads the
application APIs directly rather than duplicating state.

Served on the SSD appdata tier behind the internal Traefik at a dedicated
subdomain under `*.home.stromdahl.tech`, reachable over the mesh and LAN but
never public. Service API keys are sourced from sops and rendered at deploy time,
never committed.

Depends on `issues/005` (internal Traefik + NetBird mesh + compose-stack role);
benefits from `issues/014` (the services it surfaces).

## Acceptance criteria

- [x] Homepage is reachable at its `*.home.stromdahl.tech` subdomain over the
      mesh with a valid cert; not reachable publicly.
      → `homepage.home.stromdahl.tech` resolves to helium's mesh IP (100.65.22.72)
      from a roaming krypton; curl over the tunnel returns HTTP 200 with a valid
      LE chain (`ssl_verify=0`). Public boundary unchanged (no port-forward).
- [x] It shows grouped links and live health for the running stack services.
      → 4 groups (Media / Automation / Downloads / Infrastructure) + a Smart Home
      bookmark; per-service status dots fed by the docker-socket-proxy provider.
- [x] At least the *arr queue and tier disk-usage widgets render live data
      pulled via API.
      → Radarr + Sonarr queue widgets (API 200, authed) and SSD (`/app/config`)
      + HDD (`/mnt/media` mergerfs union) disk widgets; qBittorrent speed too.
- [x] Deployed via the Ansible compose-stack role with config on the SSD tier
      and sops-sourced API keys.
      → `homepage` service in the compose template; config verbatim-copied to
      `/data/ssd/appdata/homepage`; radarr/sonarr keys + qbit pass from sops via
      `{{HOMEPAGE_VAR_*}}`.
