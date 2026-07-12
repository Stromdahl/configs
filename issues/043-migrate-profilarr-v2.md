---
title: Migrate Profilarr to the v2 line (fresh install, rebuild profiles + sync)
status: closed
priority: medium
created: 2026-07-12
closed: 2026-07-12
labels: [epic:services]
---

## Outcome (2026-07-12)

Done. helium runs `ghcr.io/dictionarry-hub/profilarr:2.0.9` + the new
`profilarr-parser:2.0.9` sidecar (v2 tags are plain semver, no `v` prefix) on a
fresh `/config`; v1 config backed up to `/data/ssd/profilarr.v1-pre043` (outside
the restic source) for rollback. Compose change committed (`74a3cad`), incl. a
healthcheck fix (v2 image ships `curl`, not `wget`).

v2's arr-connection + profile-selection + push-sync are **UI/session-only** (no
`X-Api-Key` path — upstream #401 unshipped), so the setup was driven via the app's
SvelteKit **form-actions** with `AUTH=off` (no session needed): linked+synced the
pre-listed Dictionarry DB (id 1, `v2` branch) via `POST /api/v1/databases/1/sync`;
created Radarr (id 1, `http://radarr:7878`) + Sonarr (id 2, `http://sonarr:8989`)
via `POST /arr/new`; saved selections `1080p Quality` + `2160p Quality` via
`saveQualityProfiles`; triggered `syncQualityProfiles` (jobs 7+8 succeeded).

**Gotcha:** `apply_default_delay_profiles` defaults ON in v2 and would have written
a **600-min (10h) grab delay + prefer-torrent** default delay profile into both
arrs on instance creation — out of scope vs v1. Suppressed it first via the
`settings/general` `save` form-action (kept all other settings). Sync trigger is
**manual** (matches v1 intent); DB auto-pull stays on.

Verification (diff vs pre-migration baseline): both arrs keep exactly the two
profiles with non-zero scored CFs, up slightly from the newer DB — Radarr 1080p
89→103 / 2160p 117→130; Sonarr 1080p 81→93 / 2160p 105→120. **PASS.**

## Description

Profilarr is the source of truth for the Radarr/Sonarr quality profiles and custom
formats — the profile sync runs *from* Profilarr, not hand-built. It is pinned at
**v1.1.4**; the v1 line is now end-of-life (final tag v1.1.5, cosmetic only) and the
project has moved to a **v2** line under a new home: repo `Dictionarry-Hub/profilarr`,
image `ghcr.io/dictionarry-hub/profilarr` (current stable v2.0.9).

v2 is **not an in-place upgrade** — upstream states existing v1 databases and
configuration **cannot be migrated**. v2 rearchitects Profilarr wholesale: multiple
databases at once, a new customisation/change layer that replaces the v1 git
three-way-merge sync model, plus built-in upgrade automation, new UI, and OIDC. So
this is a deliberate rebuild, not a tag bump: stand v2 up on a fresh config volume,
re-establish the databases, re-select the profiles + custom formats, re-point the
sync at Radarr/Sonarr, run a sync, and confirm the resulting *arr profiles still
carry their scored custom formats (early v2 had a custom-format sync bug fixed by
v2.0.4 — pin ≥ v2.0.9 and re-verify scores after the first sync). The profiles and
custom formats **already written into Radarr/Sonarr stay in place** during all this;
what is rebuilt is Profilarr's own side.

Requirements to confirm before starting: Docker host kernel ≥ 3.17 (helium is fine)
and Radarr v5+ / Sonarr v4+ (helium is on Radarr v6 / Sonarr v4 after `issues/039`).

Supersedes `issues/042` (whose stated v1.6.0 target never existed). Independent of
other open work; schedule it as a small project rather than folding it into a routine
image bump.

## Acceptance criteria

- [x] The v1→v2 breaking-change / no-migration notes are captured and the fresh-install
      approach is confirmed before touching the running v1 instance.
- [x] Profilarr v2 (≥ v2.0.9, `ghcr.io/dictionarry-hub/profilarr`) is running on helium
      on a fresh config volume, with the old v1 config preserved/backed up for rollback.
- [x] The intended profiles + custom formats are re-established in v2 and its sync
      targets point at Radarr and Sonarr.
- [x] A profile sync/import runs successfully and the resulting Radarr/Sonarr profiles
      still have **non-zero scored custom formats** (sync not silently broken).
- [x] The pin and any config are committed to the repo so the deploy is reproducible.
