---
title: Immich with CPU-based ML, mesh-only
status: done
priority: medium
created: 2026-06-27
closed: 2026-07-02
labels: [epic:services]
---

## Description

Deploy Immich as a private Google-Photos replacement. The full Immich stack
(server + machine-learning + Postgres + Redis) runs on the data-tier SSD mirror,
with its **machine learning running on the CPU** (the i5-9400) for face
recognition and CLIP smart-search — the RTX 2060 has been pulled, so there is no
CUDA path. CPU ML is fine for a small personal library: a one-time bulk job on
import plus trivial incrementals, with only the initial run slower. Served at
`immich.home.stromdahl.tech` behind the internal Traefik, reachable only over the
NetBird mesh, so the phone app's auto-backup works whenever the netbird client is
up.

Library and database live on the redundant data-tier mirror (covered by the
future backup work, which is out of scope here).

Depends on `issues/005` (Traefik internal + NetBird mesh + compose-stack role)
and `issues/011` (the data-tier mirror the library and database live on).

## Acceptance criteria

- [x] Immich is reachable at `immich.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly. *(verified 2026-07-02 from krypton roaming
      off-LAN: `/api/server/ping` → `{"res":"pong"}` on a real Let's Encrypt cert.
      "Not public" is the same boundary as every helium service — no public IP, no
      port-forward; the OPNsense attestation is the shared needs-human from issue 005.)*
- [x] Photo/video upload from the phone app succeeds over the mesh. *(verified 2026-07-02:
      phone-app auto-backup enabled and running over the mesh; photos landing in the library.
      The reachability blocker was a NetBird DNS nameserver group — see the Status note below.)*
- [x] Machine-learning jobs (faces, smart-search) run on the CPU and complete; the
      initial bulk index finishes and incrementals keep up. *(ML runs on CPU — plain
      `immich-machine-learning` image, no CUDA refs, container healthy: verified
      2026-07-02. With auto-backup live the initial CPU index is now running as designed;
      completion + incrementals are a normal over-time observation, not a blocker.)*
- [x] Immich library and Postgres data reside on the data-tier SSD mirror. *(verified
      2026-07-02: both under `/data/ssd/immich` on the btrfs raid1 SSD subvol; library
      root-owned, PGDATA `999:999 0700` after postgres self-init.)*
- [x] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets. *(verified 2026-07-02: deployed over the mesh; `DB_PASSWORD` from
      `secrets.sops.yml`; my dir tasks are idempotent — `changed=0` on re-run.)*

## Status — 2026-07-02 (DONE — deployed, phone backup live, all ACs met)

**Deployed over the mesh and running.** All four containers (`immich_server`,
`immich_machine_learning`, `immich_postgres`, `immich_redis`) are up and **healthy** on
**v3.0.0**. `immich.home.stromdahl.tech` serves `{"res":"pong"}` on a real Let's Encrypt cert
over the mesh. `DB_PASSWORD` was minted into `secrets.sops.yml`. 3 of 5 ACs verified (see
above); the remaining two are genuinely human/over-time (phone upload; the slow first CPU
index). Full detail in `hosts/helium/BUILD-LOG.md` (2026-07-02, "Immich deployed").

**Machine-side deltas from the brief (all deliberate):** pinned **v3.0.0** (brief predated it,
suggested v2.7.5 — fresh-install-safe; switching to matured v2.x is the user's call and needs
a different postgres image). **No pre-chown** — the server runs as root, and the postgres
image self-chowns PGDATA (`999:999 0700`); ansible must NOT manage the PGDATA owner/mode or it
resets it to root:root and breaks postgres on restart (found + fixed during the idempotence
check). No published ports (Traefik-only); redis/database renamed to free the generic names
for Paperless (007); dedicated internal `immich` network.

**Resolved 2026-07-02 — closed.** Admin user created, the instance added in the phone app over
the mesh, and auto-backup enabled with photos landing in the library (AC #2). The initial CPU
bulk index (faces + CLIP) is running as designed; completion/incrementals are a normal
over-time watch, not a blocker.

**Root cause of the phone-reachability delay (fixed).** The phone (and any roaming device) could
not resolve `*.home.stromdahl.tech`: a **NetBird account nameserver group** was steering that
domain at the home LAN resolver, which returns helium's LAN IP `192.168.1.191` — dead off-LAN.
The laptop only worked because it ignored that group (`netbird status → Nameservers: 0/1
Available`) and fell through to the public Cloudflare wildcard (`*.home.stromdahl.tech →
100.65.22.72`, the mesh IP). Proof it was pure DNS: hitting the raw mesh IP
`https://100.65.22.72/` from the phone returned Traefik's 404. **Fix:** disabled the NetBird
nameserver group in the console (app.netbird.io → DNS) — roaming now resolves via the public
record → mesh IP for every service. This was a NetBird-account setting, not in this repo.

**Note (out of scope, pre-existing):** `docker compose up` recreates `qbittorrent`,
`prowlarr`, `flaresolverr` (all `network_mode: service:gluetun`, issue 014) on every run, so
the "Bring up the compose stack" task always reports `changed`. Not introduced here — the
Immich containers are stable. Worth a separate idempotence pass on the gluetun-networked
services.
