---
title: Skip intros and credits in Jellyfin (Intro Skipper plugin)
status: in-progress
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

Two findings from the install that change the shape of the last acceptance
criterion:

- **The plugin no longer draws a skip button.** Since Jellyfin 10.10 it only
  writes typed *media segments* to the server; rendering the prompt (or acting on
  it) is the client's job. So "a skip prompt appears" is now a client capability,
  not something the plugin can deliver.
- **The living-room client is the LG TV (Jellyfin for webOS), which does not
  render the ask-to-skip prompt but does honour auto-skip.** The action is a
  per-client playback setting on the TV itself, so the last mile stays
  `needs-human`: set the segment action to auto-skip in the webOS app, not to
  "ask".

## Acceptance criteria

- [x] The plugin is installed and enabled, with a build matching the running
      Jellyfin version. (Intro Skipper `1.10.11.22`, `targetAbi 10.11.11.0`,
      exactly the running server; ffmpeg `7.1.4-Jellyfin` clears the plugin's
      `>= 7.1.1-7` floor.)
- [ ] A detection pass has run over the TV library and playback of a detected
      episode skips the intro on the LG TV (auto-skip enabled client-side).
- [x] It is documented (in the build log or the issue) that a Jellyfin version
      bump requires installing the matching plugin build.
