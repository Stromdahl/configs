---
title: Run service containers as non-root where the image supports it
status: open
priority: medium
created: 2026-06-29
closed: null
labels: [epic:hardening, needs-human]
---

## Description

Tighten the Docker stack so each service runs as an unprivileged user rather than
container-root, reducing the blast radius of a service compromise on a box where
everything shares one host kernel. Most of the stack already supports this via the
`PUID`/`PGID` convention (the *arr images, linuxserver-style); the goal is to make
non-root the deliberate, audited default across the whole compose stack rather than
relying on per-image defaults, and to drop unnecessary capabilities and privileged
flags.

Explicitly **not** in scope: host-wide `userns-remap`. It conflicts with the iGPU
`/dev/dri` passthrough that Jellyfin needs and with gluetun's network capabilities,
so the hardening is done per-service (run-as-user, `cap_drop`, `no-new-privileges`,
read-only bind mounts where possible) rather than by remapping the whole daemon.

This is post-bring-up hardening, not a bootstrap blocker. Depends on the service
stack being up (`issues/005` Jellyfin, `issues/014` download automation, `issues/006`
Immich, `issues/007` Paperless) so each container can be hardened against a
known-working baseline.

## Acceptance criteria

- [ ] Every service in the compose stack runs as a non-root user, or its need for
      root is explicitly documented (e.g. a sidecar that legitimately requires it).
- [ ] Containers that don't need extra Linux capabilities run with them dropped and
      `no-new-privileges` set.
- [ ] Bind mounts are read-only wherever the service only reads (e.g. media for
      Jellyfin), and writable mounts are scoped to the minimum path.
- [ ] All services still function after hardening: Jellyfin transcodes on the iGPU,
      gluetun's tunnel is up, the *arr stack reads/writes its volumes, Immich and
      Paperless ingest normally.
- [ ] No use of host-wide `userns-remap` (the per-service approach is preserved).
