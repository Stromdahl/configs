---
title: Tone-map HDR to SDR on Jellyfin transcodes (Intel OpenCL runtime in the container)
status: open
priority: medium
created: 2026-07-31
closed: null
labels: [epic:services]
---

## Description

When Jellyfin transcodes an HDR title for a client that wants SDR, it currently
hands over the raw BT.2020/PQ picture untouched — the washed-out, grey-looking
result. Tone mapping is the fix, and it is off today because the hardware path
for it is missing rather than because a checkbox is unticked.

helium's iGPU is UHD 630 (Coffee Lake, gen 9.5). Jellyfin's Intel matrix offers
two tone-mapping backends: VPP, which needs a newer GPU generation than this one,
and OpenCL, which works on any Intel GPU with HEVC 10-bit decode — so OpenCL is
the only option here. But the Jellyfin container has no Intel OpenCL runtime: its
ICD directory carries only an unrelated `nvidia.icd`, and initialising an OpenCL
device derived from the VA-API device fails outright ("Failed to get number of
OpenCL platforms"). So enabling tone mapping in the UI alone would achieve
nothing.

The runtime is added at the container layer, which is why this is a compose
change rather than a Jellyfin setting: the linuxserver image accepts a docker mod
that installs the Intel OpenCL packages on container start. That means an image
env-var addition plus a stack redeploy, and the redeploy restarts Jellyfin.

Two things make this worth doing rather than academic. The living-room LG TV does
*not* direct-play today — it transcodes (its own client-side bitrate cap), so the
transcode path is the normal path, not an edge case. And the library does hold
2160p HEVC material, so HDR sources are actually present.

Known risk: the mod's Intel compute-runtime has lagged in the past, and there are
reports of the i915 GPU not being detected for OpenCL after installing it. So
"mod applied" is not "tone mapping works" — the OpenCL device init has to be
re-tested inside the container before this is called done.

Depends on `issues/005` (Jellyfin running).

## Acceptance criteria

- [ ] The Jellyfin container exposes a working Intel OpenCL device — initialising
      an OpenCL device derived from the VA-API device succeeds inside the
      container.
- [ ] Tone mapping is enabled in Jellyfin's transcoding settings and the stack
      redeploy left Jellyfin healthy.
- [ ] Playing an HDR title to a client that forces SDR produces a tone-mapped
      picture, verified from the live ffmpeg invocation carrying a tone-map
      filter (not just from the UI toggle).
- [ ] If the OpenCL runtime cannot be made to work on this GPU, the issue is
      closed best-effort with the finding recorded, as `issues/004` was.
