---
title: Migrate the media library from neon
status: in-progress
priority: high
created: 2026-06-27
closed: null
labels: [epic:cutover, needs-human]
---

## Description

Move the existing ~932 GB movies+shows library off neon onto helium's HDD pool with
full continuity, so Jellyfin serves the real library. Done as a **live first pass**
while neon keeps serving, then a **final delta sync** at cutover.

This was the media half of the original migration issue; the *arr application state
+ active downloads migration is `issues/015` (it depends on the download-automation
stack existing). The library rsync here only needs the pool and Jellyfin, so it can
start as soon as the pool mount is live — and in fact should run in the background
early, since neon holds the only other copy.

Depends on `issues/003` (the pool the media lands on) and `issues/005` (Jellyfin,
to serve + verify the migrated library).

## Acceptance criteria

- [ ] The full ~932 GB library is present on the HDD pool and visible in Jellyfin.
- [ ] A final delta rsync reconciles any changes made on neon during the build.
- [ ] Playback of a migrated title works end-to-end over the mesh.
