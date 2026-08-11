---
title: Automate audiobook acquisition (Sonarr/Radarr-shaped, for audiobooks)
status: open
priority: low
created: 2026-08-11
closed: null
labels: [epic:services, needs-human]
---

## Description

Add the acquisition half issue 048 deliberately left out: search, grab, and
auto-organize audiobooks into the Audiobookshelf library, the way Sonarr/
Radarr do for movies/TV in issue 014 — reusing the *existing* Prowlarr
indexers and qBittorrent-behind-gluetun download client, not standing up
parallel infrastructure.

**Why this is `open` and not just done alongside 048:** Readarr — the
Servarr project's own book/audiobook automator — was officially retired in
early 2026 (its metadata source died with Goodreads' API shutdown, and the
maintainers didn't have capacity to replace it). The two candidates that
have emerged to fill that gap were checked 2026-08-11 and neither clears
this stack's bar of "pin a tagged image like every other service in
`host_vars/helium/vars.yml`":

- **Listenarr** (`Listenarrs/Listenarr`) — closest architectural fit
  (Sonarr-shaped, reuses Prowlarr/qBittorrent directly), active (844 stars,
  16 contributors, commits same-day), but all 136 published image tags are
  `canary-*` or `nightly-*` — no stable release line has ever been cut.
- **Shelfarr** (`Pedro-Revez-Silva/shelfarr`) — a broader "Jellyseerr for
  books" with its own request UI, but younger (created Dec 2025, 287
  stars), its own docker-compose builds the image from source rather than
  pulling a published tag, and it bundles direct-download sources (Anna's
  Archive, Z-Library) that would need explicitly disabling to stay inside
  this stack's private-tracker-only posture (issue 020).

Neither is disqualified forever — re-check when picking this up; a stable
Listenarr release tag would make it the straightforward choice. Until then,
this issue stays parked rather than baking an unpinned/build-from-source
image into the stack.

Depends on `issues/048` (the Audiobookshelf library this imports into) and
`issues/014` (the Prowlarr + qBittorrent pipeline this reuses).

## Acceptance criteria

- [ ] A tool is selected with a pinnable, tagged release image (re-verify
      Listenarr/Shelfarr's release status, or reassess alternatives, at
      pickup time — don't reuse this issue's 2026-08-11 snapshot uncritically).
- [ ] It is configured against the existing Prowlarr indexers and the
      existing qBittorrent client — no new indexer accounts or VPN plumbing.
- [ ] Any direct-download-from-piracy-site sources the tool ships with are
      confirmed disabled, if present.
- [ ] End-to-end grab verified, not assumed: searching for and grabbing an
      audiobook results in a completed download that is auto-organized into
      the library and shows up playable in Audiobookshelf without a manual
      file move.
- [ ] Config/appdata lives under the SSD `appdata` precious subvol.
