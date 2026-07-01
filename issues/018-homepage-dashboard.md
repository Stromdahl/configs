---
title: Single-pane dashboard for the stack (Homepage)
status: open
priority: medium
created: 2026-07-01
closed: null
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

- [ ] Homepage is reachable at its `*.home.stromdahl.tech` subdomain over the
      mesh with a valid cert; not reachable publicly.
- [ ] It shows grouped links and live health for the running stack services.
- [ ] At least the *arr queue and tier disk-usage widgets render live data
      pulled via API.
- [ ] Deployed via the Ansible compose-stack role with config on the SSD tier
      and sops-sourced API keys.
