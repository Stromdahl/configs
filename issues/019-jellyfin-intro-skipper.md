---
title: Skip intros and credits in Jellyfin (Intro Skipper plugin)
status: open
priority: low
created: 2026-07-01
closed: null
labels: [epic:services, needs-human]
---

## Description

TV playback has no way to skip recurring intros and end credits — a per-episode
annoyance across a series. The Intro Skipper plugin auto-detects intro and credit
sequences and offers a skip prompt during playback. It is plugin-only (its state
lives in Jellyfin's own config, not a separate compose service) and near-zero
footprint.

Two hard constraints: the plugin build must match the running Jellyfin release
exactly (a mismatched build fails to load or crashes on startup), and it requires
Jellyfin's ffmpeg fork — satisfied by the linuxserver Jellyfin image, which ships
jellyfin-ffmpeg. Because the build is version-locked, any future Jellyfin version
bump must be paired with the matching plugin build. Install is via adding the
plugin repository to Jellyfin and installing from the catalogue, then running a
library detection pass — largely a Jellyfin-UI step (hence `needs-human`).

Depends on `issues/005` (Jellyfin running).

## Acceptance criteria

- [ ] The plugin is installed and enabled, with a build matching the running
      Jellyfin version.
- [ ] A detection pass has run over the TV library and a skip prompt appears
      during playback of a detected episode.
- [ ] It is documented (in the build log or the issue) that a Jellyfin version
      bump requires installing the matching plugin build.
