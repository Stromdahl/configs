---
title: Upgrade Profilarr from v1.1.4 to v1.6.0
status: dropped
priority: medium
created: 2026-07-11
closed: 2026-07-12
labels: [epic:services]
---

## Description

> **DROPPED 2026-07-12.** The premise is wrong: **v1.6.0 never existed.** The repo
> moved to `Dictionarry-Hub/profilarr`; the v1 line ends at **v1.1.5** (now EOL) and
> then jumps straight to a **v2** that is a hard, non-migratable break (new registry
> `ghcr.io/dictionarry-hub/profilarr`, fresh install, the v1 sync/merge model is gone —
> profiles + sync targets must be rebuilt by hand). A v1.1.4 → v1.1.5 bump is purely
> cosmetic and stays on dead software, so it was **not** done — helium keeps running
> v1.1.4 untouched. The real upgrade (v2.0.9) is split out as its own deliberate
> migration in `issues/043`. Text below kept for history.

The requested bump (`v1.1.4 → v1.6.0`) does not exist. Original text follows.

Profilarr is pinned at v1.1.4; current stable is v1.6.0 — a five-minor jump. Profilarr is the
source of truth for the Radarr/Sonarr quality profiles and custom formats (the profile sync
runs from Profilarr, not hand-built), so a config/sync-format change across five minors could
ripple into the *arr profiles. Review the changelog between v1.1 and v1.6 for any change to the
sync config format or the `data_to_sync` mechanism before upgrading.

Bump the pin in the compose-stack role, redeploy, and confirm Profilarr comes up with its
existing config intact and can still run a profile import into Radarr/Sonarr without the synced
profiles losing their scored custom formats.

## Acceptance criteria

- [ ] The v1.2–v1.6 changelogs have been reviewed for sync/config-format changes before the bump.
- [ ] Profilarr is re-pinned to v1.6.0 in the compose-stack role and redeployed to helium.
- [ ] Profilarr loads with its existing config and can trigger a profile import; the resulting
      Radarr/Sonarr profiles still have non-zero scored custom formats (sync not broken).
- [ ] The pin is committed to the repo.
