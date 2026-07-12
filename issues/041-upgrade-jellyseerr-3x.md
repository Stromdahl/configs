---
title: Upgrade Jellyseerr from 2.7.3 to the 3.x line
status: done
priority: medium
created: 2026-07-11
closed: 2026-07-12
labels: [epic:services]
---

## Description

Jellyseerr is pinned at 2.7.3; the current stable is v3.3.0 — a major-version jump (2.x → 3.x)
plus three minors. Unlike the routine bumps in `issues/039`, this crosses a major boundary, so
the v3.0 release notes must be read for breaking changes (config schema, database migration,
API/integration changes) before upgrading, and the existing Jellyseerr data (request history,
Jellyfin + *arr connections) must survive the migration.

Bump the pin in the compose-stack role, redeploy, and confirm Jellyseerr still authenticates
against Jellyfin, still talks to Radarr/Sonarr, and still holds its request history. If v3
requires an irreversible on-disk migration, note that its appdata is covered by the restic
backup (`issues/016`/`026`) so a rollback path exists.

## Acceptance criteria

- [ ] The v3.0.0 (and intervening) release notes have been reviewed and any required migration
      steps captured before the bump.
- [ ] Jellyseerr is re-pinned to the 3.x line in the compose-stack role and redeployed to helium.
- [ ] After the upgrade Jellyseerr loads, authenticates against Jellyfin, and its Radarr/Sonarr
      connections still work (a test request reaches the *arr apps).
- [ ] Existing request history survived the migration (or the loss is explicitly accepted and
      noted).
- [ ] The pin is committed to the repo.
