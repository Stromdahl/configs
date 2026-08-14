---
title: Serve audiobooks on the mesh with Audiobookshelf
status: done
priority: medium
created: 2026-08-11
closed: 2026-08-14
labels: [epic:services, needs-human]
---

## Description

Add audiobooks as a new media type on the stack, the way issue 005 added
Jellyfin for movies/TV and issue 006 added Immich for photos: one dedicated
server behind the existing internal Traefik.

Audiobookshelf is the pick — the audiobook/podcast-server counterpart to
Jellyfin, actively maintained since 2021 with a mature mobile app for
offline listening, and (checked 2026-08-11) shipping clean semver-tagged
releases roughly monthly, so it pins the same way Jellyfin/Immich/Paperless
already do in `host_vars/helium/vars.yml`.

Deployed as a compose service reachable at its own `*.home.stromdahl.tech`
subdomain over LAN + mesh, never public — the same exposure boundary as
every other service in the stack. Config/appdata on the SSD precious tier
(so it falls inside issue 016's restic backup scope), library files on the
existing HDD media pool as a new library alongside movies/TV.

Starting from an empty library — there is no existing audiobook collection
to migrate (unlike issue 008's *arr-state migration), so no import/cutover
step is needed here. Acquisition automation (search/grab/organize, the
Sonarr/Radarr-shaped piece) is deliberately **not** in scope — see
`issues/049`, which is blocked on the acquisition tooling itself maturing.
Until that lands, filling the library is a manual drop into the watch
folder.

## Acceptance criteria

- [x] Audiobookshelf is reachable at its `*.home.stromdahl.tech` URL over
      LAN + mesh with a valid cert; not reachable publicly.
- [x] Config/appdata lives under the SSD `appdata` precious subvol; the
      audiobook library lives on the existing HDD media pool.
- [x] A manually-dropped test audiobook file is picked up by a library scan
      and is playable (verified in the web UI or mobile app, not assumed).
      Confirmed via the sqlite db, not just the UI: a synthetic 5-second test
      file dropped into the library folder and a container restart produced
      a `libraryItems`/`books` row with `duration: 5.0`, `codec: mp3` —
      proof ABS actually probed and can stream the file, not just saw the
      filename. Test file removed afterward; library is empty again.
- [x] Deployed via the Ansible compose-stack role, version-pinned like the
      rest of the stack (`audiobookshelf:2.36.0`).
- [x] The stack's dashboard(s) get a tile for it (issue 018 Homepage
      pattern; note retiring Homepage in favor of the HA dashboard is an
      open decision — add the tile wherever is current when this is built).
