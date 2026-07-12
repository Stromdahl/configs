---
title: Migrate Profilarr to the v2 line (fresh install, rebuild profiles + sync)
status: open
priority: medium
created: 2026-07-12
closed: null
labels: [epic:services]
---

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

- [ ] The v1→v2 breaking-change / no-migration notes are captured and the fresh-install
      approach is confirmed before touching the running v1 instance.
- [ ] Profilarr v2 (≥ v2.0.9, `ghcr.io/dictionarry-hub/profilarr`) is running on helium
      on a fresh config volume, with the old v1 config preserved/backed up for rollback.
- [ ] The intended profiles + custom formats are re-established in v2 and its sync
      targets point at Radarr and Sonarr.
- [ ] A profile sync/import runs successfully and the resulting Radarr/Sonarr profiles
      still have **non-zero scored custom formats** (sync not silently broken).
- [ ] The pin and any config are committed to the repo so the deploy is reproducible.
