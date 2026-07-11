---
title: Bump Traefik off v3.6.11 to pick up security fixes and decide the 3.6 vs 3.7 line
status: open
priority: high
created: 2026-07-11
closed: null
labels: [epic:services]
---

## Description

Traefik is the internal ingress in front of the whole helium stack, and it is pinned at
v3.6.11 — behind the recent security advisories (middleware, Kubernetes, TLS) that were fixed
in early July 2026. Because it fronts every service, this is the highest-priority bump: a
stale ingress is both a security exposure and a single point of failure for all routers.

There is a line decision to make:

- **v3.6.23** — stay on the current 3.6 line, latest patch, minimal change.
- **v3.7.7** — move to the newer 3.7 minor line.

Both shipped the same recent security fixes, so either closes the exposure. Review the 3.7.0
changelog before choosing 3.7; if nothing there is needed, staying on 3.6.23 is the lower-risk
choice. Whichever is picked, the critical verification is that **every** service router still
resolves after the bump — Traefik is the one image whose failure takes the whole stack
offline.

## Acceptance criteria

- [ ] Traefik is re-pinned in the compose-stack role to either v3.6.23 or v3.7.7 (decision
      recorded in the commit / issue), off the vulnerable v3.6.11.
- [ ] The stack is redeployed to helium and Traefik comes up cleanly (no config/parse errors
      in its logs).
- [ ] Every service router still resolves after the bump — Jellyfin, Immich, Paperless,
      Homepage, and the *arr/qBittorrent/Jellyseerr subdomains all serve over the internal
      Traefik as before.
- [ ] The pin is committed to the repo.
