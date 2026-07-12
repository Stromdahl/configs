---
title: Bump routine helium stack images to current stable within their version lines
status: in-progress
priority: medium
created: 2026-07-11
closed: null
labels: [epic:services]
---

## Description

The helium compose stack (deployed by the Ansible compose-stack role) has drifted a few
releases behind on most of its media/automation images. This slice bumps the low-risk ones
— patch-only and small minor bumps with no major-version crossings and no known breaking
changes — in a single deploy, and verifies each service comes back up healthy.

Images to bump (as of 2026-07-11):

- jellyfin 10.11.8 → 10.11.11 (patch)
- sonarr 4.0.17 → 4.0.19 (patch, same v4 branch)
- cleanuparr 2.9.14 → 2.9.16 (patch)
- immich-server + immich-machine-learning v3.0.0 → v3.0.2 (patch; all v3 breaking changes
  already landed in v3.0.0 which is running today)
- qbittorrent 5.1.4 → 5.2.3 (minor; skim 5.2 changelog)
- bazarr 1.5.6 → 1.6.0 (minor)
- prowlarr 2.3.5 → 2.4.0 (minor, same master branch)
- radarr 6.1.1 → 6.2.1 (minor, same master branch)
- flaresolverr v3.4.6 → v3.5.0 (minor; adds Cloudflare Turnstile solving)

Immich's supporting images (valkey:9 and immich-app/postgres) keep the same tags in the
v3.0.2 release compose — only the pinned digests would change. Re-pinning those digests to
match v3.0.2 exactly is optional and can be folded into this slice or skipped.

Excluded deliberately (own tickets): Traefik (security bump + line decision, `issues/040`),
Jellyseerr (major 2→3, `issues/041`), Profilarr (5-minor jump, `issues/042`). Images already
on current stable (docker-socket-proxy, homepage, gluetun, paperless-ngx, redis, postgres,
gotenberg, tika) are untouched.

## Acceptance criteria

- [ ] All nine images above are re-pinned to the listed versions in the compose-stack role.
- [ ] The stack is redeployed to helium and every bumped service is running/healthy (Jellyfin
      serves, the *arr apps and qBittorrent load their web UIs, Immich server + ML are up,
      FlareSolverr responds).
- [ ] Immich still starts against its existing database (no migration failure on the v3.0.0 →
      v3.0.2 bump).
- [ ] The version pins are committed to the repo so the deploy is reproducible.
