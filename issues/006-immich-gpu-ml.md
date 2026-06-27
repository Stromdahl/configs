---
title: Immich with GPU-accelerated ML, mesh-only
status: open
priority: medium
created: 2026-06-27
closed: null
labels: [epic:services]
---

## Description

Deploy Immich as a private Google-Photos replacement. The full Immich stack
(server + machine-learning + Postgres + Redis) runs on the SSD tier, with its
**machine learning accelerated on the RTX 2060 (CUDA)** for face recognition and
CLIP smart-search — keeping that heavy work off the CPU. Served at
`immich.home.stromdahl.tech` behind the internal Traefik, reachable only over the
NetBird mesh, so the phone app's auto-backup works whenever the netbird client is
up.

Library and database live on the redundant SSD tier (covered by the future backup
work, which is out of scope here).

Depends on `issues/005` (Traefik internal + NetBird mesh + compose-stack role).

## Acceptance criteria

- [ ] Immich is reachable at `immich.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly.
- [ ] Photo/video upload from the phone app succeeds over the mesh.
- [ ] Machine-learning jobs (faces, smart-search) run on the RTX 2060, confirmed by
      GPU utilization during indexing.
- [ ] Immich library and Postgres data reside on the SSD tier.
- [ ] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets.
