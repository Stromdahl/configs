---
title: Upgrade Jellyseerr from 2.7.3 to the 3.x line
status: done
priority: medium
created: 2026-07-11
closed: 2026-07-12
labels: [epic:services]
---

## Description

> **DONE 2026-07-12.** Migrated to **Seerr v3.3.0** — the 3.x line is not on
> `fallenbagel/jellyseerr` (frozen at 2.7.3); it moved to `ghcr.io/seerr-team/seerr`.
> Compose now pins `ghcr.io/seerr-team/seerr:v3.3.0` with `init: true`, keeping the
> issue-010 uid override (1001:1003, config already owned by it — sidesteps the common
> 1000:1000 permission crash). Container healthy, settings/DB migrations applied clean,
> no permission errors. **Verified from CLI:** request history intact (live DB matches
> pre-migration backup: `media_request`=6, `season_request`=24) and connection config
> survived (Jellyfin server entry + 1 Radarr + 1 Sonarr in `settings.json`).
> **Residual (accepted & noted):** the runtime "Jellyfin login works + a live test
> request flows to the *arr apps" is a UI spot-check left to the user. **Rollback:**
> restore appdata snapshot `/data/ssd/appdata/jellyseerr.pre-seerr-v3-20260712-070255`
> and re-pin `fallenbagel/jellyseerr:2.7.3` (the migration is forward-only).

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
