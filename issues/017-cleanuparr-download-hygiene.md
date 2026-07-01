---
title: Auto-clean stalled and failed downloads with Cleanuparr
status: open
priority: medium
created: 2026-07-01
closed: null
labels: [epic:services]
---

## Description

The download queues accumulate stalled, failed, and orphaned items — a torrent
that never gets peers, a malformed release the *arr keeps retrying, files left
behind after an import — and today clearing them is a manual chore that quietly
stalls the acquire pipeline. Cleanuparr monitors the Radarr/Sonarr queues and
qBittorrent, removes stalled/blocked/failed downloads, blacklists the offending
release so it is not re-grabbed, triggers a fresh search, and prunes orphaned
files. It is the actively-maintained successor to the now-retired Decluttarr.

Deployed as a compose service on the SSD appdata tier behind the internal
Traefik at `cleanuparr.home.stromdahl.tech`, reachable over the mesh and LAN but
never public (same boundary as the rest of the stack). It reaches the *arr over
the media bridge and qBittorrent via gluetun's published WebUI, using API keys
sourced from sops.

Depends on `issues/014` (the *arr + qBittorrent it manages).

## Acceptance criteria

- [ ] Cleanuparr is reachable at `cleanuparr.home.stromdahl.tech` over the mesh
      with a valid cert; not reachable publicly.
- [ ] A deliberately stalled/failed test download is removed from qBittorrent
      and from the Radarr/Sonarr queue, and the release is blacklisted
      (verified, not assumed).
- [ ] It runs unattended on a schedule (no manual trigger needed for routine
      cleanup).
- [ ] Deployed via the Ansible compose-stack role with config on the SSD tier
      and sops-sourced API keys.
