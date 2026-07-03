---
title: DNS cutover to helium and retire neon
status: done
priority: high
created: 2026-06-27
closed: 2026-07-03
labels: [epic:cutover]
---

## Description

Make helium the live home for all services and decommission neon. Point the
`*.home.stromdahl.tech` records at helium (its mesh IP via NetBird DNS), and
**remove the old public `jellyfin.stromdahl.tech` record** — the setup is now
fully private. Verify every service end-to-end over the mesh before pulling neon
out of service.

After verification, neon retires; its 1.8 TB NVMe is freed (a candidate local
backup target, handled by the deferred backup work).

**Migration-scaffolding teardown (folded in from `issues/008`):** as part of
retiring neon, tear down the library-migration plumbing — unmount `/mnt/neon-src`
on neon-rescue and remove the ephemeral key (`/root/.ssh/neon_migrate*` on helium +
the matching line in neon-rescue's `authorized_keys`). 008 closed without doing this
because it is root/neon-side teardown that belongs with the decommission.

Depends on `issues/008` (library migrated — done), `issues/014` (download automation
— done; `issues/015`, the *arr-state migration, was **dropped** in favour of a fresh
014 build), and `issues/006` + `issues/007` (Immich + Paperless — done) — so every
service is live on helium before the final cutover. All dependencies are now met.

## Acceptance criteria

- [x] `*.home.stromdahl.tech` resolves to helium and every service (Jellyfin,
      Jellyseerr, *arr, Immich, Paperless) is reachable over the mesh with valid
      certs. (Immich was down over the mesh — Traefik multi-network routing bug —
      found + fixed under this issue; full 11/11 sweep green.)
- [x] The public `jellyfin.stromdahl.tech` record is removed; nothing is publicly
      reachable. (NXDOMAIN on public resolvers.)
- [x] All services verified working on helium with neon powered off. (Final
      neon-dark sweep: 11/11 reachable, valid certs.)
- [x] neon is decommissioned and its role fully retired. (Powered off via helium
      ProxyJump; helium- + neon-side migration teardown complete.)
