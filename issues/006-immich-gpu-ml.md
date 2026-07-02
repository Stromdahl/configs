---
title: Immich with CPU-based ML, mesh-only
status: in-progress
priority: medium
created: 2026-06-27
closed: null
labels: [epic:services, needs-human]
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

- [ ] Immich is reachable at `immich.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly.
- [ ] Photo/video upload from the phone app succeeds over the mesh.
- [ ] Machine-learning jobs (faces, smart-search) run on the CPU and complete; the
      initial bulk index finishes and incrementals keep up.
- [ ] Immich library and Postgres data reside on the data-tier SSD mirror.
- [ ] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets.

## Status — 2026-07-02 (in-progress)

Machine-side IaC complete + validated; the deploy is a needs-human gate (one secret + the
phone-app AC + the slow first index). helium is reachable over the mesh (`100.65.22.72`).

**Done:** Immich's 4-service group (server + ML + valkey + postgres) added to the
`compose_stack` role, mirroring the official immich-app **v3.0.0** release compose — CPU ML
(plain image, no `hwaccel` extends), no published ports (Traefik router
`immich.home.stromdahl.tech` → :2283, security-headers reused), a dedicated internal `immich`
network (db/redis/ML off the shared media bridge), library + Postgres bound to the SSD
`immich` precious subvol, valkey/postgres digest-pinned to the upstream-tested pair. Validated
with `docker compose config` on the rendered stack (schema + 20 structural assertions). Full
detail in `hosts/helium/BUILD-LOG.md` (2026-07-02, "later").

**Deviation from the brief:** pinned **v3.0.0** (the brief predated it and suggested v2.7.5).
Fresh-install-safe (v3's breaking changes are API + pgvecto→VectorChord, neither of which
affects a new install). Switching to the matured v2.x line is the user's call — it needs a
different postgres image.

**Remaining (needs-human):**
- Mint `immich_db_password` (`[A-Za-z0-9]` only) into `host_vars/helium/secrets.sops.yml`
  (deliberately not minted by the agent).
- Run the deploy: `ansible-playbook site.yml --tags compose,services` (target helium's mesh
  IP `100.65.22.72` while krypton roams off-LAN).
- Phone-app auth + first upload over the mesh (AC #2).
- Confirm the initial CPU bulk ML index (faces + CLIP) finishes and incrementals keep up
  (AC #3 — observed over time, not in a deploy run).
