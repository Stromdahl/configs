# Task 008 — Migrate the media library and *arr state from neon

**Source issue:** `issues/008-migrate-library-arr-state.md` — move the existing
library off neon onto helium with **full continuity**. Two parts: (a) rsync the
~932 GB movies+shows library into the HDD pool (live first pass + final delta at
cutover); (b) migrate the *arr Docker volumes (radarr/sonarr/prowlarr/bazarr/
profilarr configs + DBs) **intact**, so history/quality-profiles/import-state come
over rather than being rebuilt. Start lean: drop the ~600 GB old completed seeds;
carry only incomplete/recent downloads onto the SSD tier.

> **Depends on `issues/005` (the helium stack must be running to receive the
> volumes + serve the library), `issues/003` (HDD pool), and `issues/011` (the SSD
> appdata subvol the *arr state lands on).** All three must be `done` first — the
> rsync targets (`/srv/media`, `/data/ssd/appdata`, `/data/ssd/downloads`) don't
> exist until then. **Do not grab until 005 is `done`.**

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/008` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief.
3. **Verify** the acceptance criteria below before declaring done. This task is
   mostly **operational** (rsync + container restarts on live hosts), not a repo
   code change — there may be little or nothing to commit beyond a runbook note.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

This issue carries **`needs-human`**: it operates on two live hosts, needs a
coordinated cutover window, a human decision on which seeds to keep, and manual
playback verification. The agent drives the rsync/restart steps; the user owns the
window, the seed-curation call, and the final sign-off.

## Suggested agent

**Sonnet** — this is operational orchestration (SSH, rsync, stop/start containers,
chown), not architectural reasoning. The care points are *data-safety* discipline,
not difficulty: never `--delete` against a half-populated target, always stop the
source app before copying its SQLite DB.

## Human steps / blockers (`needs-human`)

- **Two live hosts reachable:** neon (`192.168.1.153`) and helium on the LAN; rsync
  runs over SSH. Confirm `ssh <user>@neon` works **from helium** before the window
  (servers hold no GitHub key, but host↔host SSH must already be set up — verify,
  don't bootstrap mid-window).
- **Seed-curation decision:** issue says drop ~600 GB old completed seeds but
  defines no exact cutoff (age/ratio). The **user decides** which torrents to keep;
  curate on neon (qBittorrent WebUI lists completion dates) before the downloads
  rsync, or agree an mtime cutoff.
- **Cutover window:** the final delta + *arr state copy needs neon's *arr
  containers **stopped** (SQLite consistency). The user picks the maintenance
  window and signals go — the agent must not stop neon's services unilaterally.
- **Playback sign-off:** after migration, the user tests playback of a few titles
  (varied codecs/containers) end-to-end over the mesh.

## Decisions baked in (read before coding)

- **Compose project name MUST be `jellyfin` on both sides.** neon's stack pins
  `name: jellyfin` (grep `name:` / `COMPOSE_PROJECT_NAME` in
  `servers/neon/docker-compose.yml`), so its volumes are `jellyfin_<app>_volume`.
  helium's stack (`issues/005`/`tasks/005`) must use the **same** project name and
  the **same UID/GID `1001:1003`** (neon's `config.env`), or ownership/volume
  identity diverges. **Confirm `tasks/005` set these before migrating;** if not,
  that's a blocker to raise on `issues/005`, not to paper over here.
- **SQLite state must be copied cold.** Stop each *arr container on the source
  before rsyncing its volume — copying an open SQLite DB risks corruption and a
  silent "rebuilt from scratch" on first start (the exact failure the issue forbids).
- **Media: live first pass, then `--delete` only at the cold cutover.** A
  `--delete` against a still-filling target can wipe good data — the live pass runs
  **without** `--delete`; only the final delta, with the source frozen, uses it.
- **Ownership fix is mandatory after copy.** rsync `-a` preserves neon's `1001:1003`;
  if helium's appdata owner differs, `chown -R` to helium's container UID/GID or the
  *arr apps can't read their config.

## Entry points (operational — grep-stable, not code symbols)

This is a data/runbook migration; "entry points" are the source/target paths.

**Source (neon, deployed at `/opt/neon/`):**
- Media library: `MEDIA_SHARE` → **`/mnt/datastore/media/media`** (grep
  `servers/neon/config.env` for `MEDIA_SHARE`). ~932 GB.
- Downloads: `DOWNLOADS_SHARE` → **`/mnt/datastore/media/downloads`** (grep
  `DOWNLOADS_SHARE`).
- *arr state: **`/var/lib/docker/volumes/jellyfin_<app>_volume/_data`** for
  `<app>` ∈ {radarr, sonarr, bazarr, prowlarr, profilarr} (Docker default volume
  root; project prefix `jellyfin_`). qBittorrent config:
  `jellyfin_qbittorrent_volume`.

**Target (helium — from `host_vars/helium/vars.yml`, grep-stable):**
- Media → `hdd_union_mount` = **`/srv/media`** (003's mergerfs union).
- *arr state → `ssd_subvolumes_precious` `appdata` = **`/data/ssd/appdata/<app>`**
  (CoW + checksums).
- Active downloads → `ssd_subvolumes_scratch` `downloads` = **`/data/ssd/downloads`**.

## Prior art to mirror

- `servers/neon/docker-compose.yml` — the volume names + the `${MEDIA_SHARE}` /
  `${DOWNLOADS_SHARE}` bind mounts (grep `radarr_volume:/config`,
  `${DOWNLOADS_SHARE`). Tells you exactly what to copy and where it lands on helium.
- `servers/neon/deploy.sh` — confirms neon's deploy/runtime layout (`/opt/neon`).
- `tasks/005-media-stack-traefik-netbird.md` — the helium stack the migrated data
  feeds; source of the project name, UID/GID, and Jellyfin's `/srv/media:ro` mount.

## Steps

0. **Don't start until 005 + 003 + 011 are `done`** and `ssh <user>@neon` works
   from helium. Confirm `tasks/005` used project `jellyfin` + UID/GID `1001:1003`.
1. **Media live first pass** (neon keeps serving):
   `rsync -aHAX --info=progress2 <neon>:/mnt/datastore/media/media/ /srv/media/`
   (no `--delete`).
2. **Seed curation** (human): drop old completed seeds on neon; keep only
   active/incomplete.
3. **Freeze + copy *arr state** (cutover window): on neon
   `docker compose stop radarr sonarr prowlarr bazarr profilarr qbittorrent`; then
   per app `rsync -aHAX --delete <neon>:/var/lib/docker/volumes/jellyfin_<app>_volume/_data/ /data/ssd/appdata/<app>/`;
   `chown -R 1001:1003 /data/ssd/appdata/*` (or helium's container UID/GID).
4. **Downloads delta**:
   `rsync -aHAX <neon>:/mnt/datastore/media/downloads/ /data/ssd/downloads/`
   (curated set only).
5. **Media final delta** (source frozen):
   `rsync -aHAX --delete <neon>:/mnt/datastore/media/media/ /srv/media/`.
6. **Start helium stack** (`tasks/005` services) → *arr apps mount the migrated
   appdata and load existing config/DB (no rebuild); Jellyfin scans `/srv/media`.

## Verify

- **library present:** `ansible nas -b -m shell -a 'du -sh /srv/media; find /srv/media -type f | wc -l'` ≈ neon's count + ~932 GB; library visible in Jellyfin.
- ***arr state intact (not rebuilt):** each `/data/ssd/appdata/<app>` holds
  `config.xml` + the app DB; `sqlite3 /data/ssd/appdata/radarr/*.db '.tables'`
  succeeds; the *arr WebUIs show pre-existing library history + quality profiles.
- **lean downloads:** `du -sh /data/ssd/downloads` shows only active torrents (old
  seeds dropped).
- **final delta clean:** the last media rsync reports zero new files transferred.
- **playback (human):** a migrated title plays end-to-end over the mesh.

## Acceptance criteria (from issue 008, verbatim)

- [ ] The full ~932 GB library is present on the HDD pool and visible in Jellyfin.
- [ ] The *arr apps show their pre-existing library history and quality profiles
      (state migrated, not rebuilt).
- [ ] Only lean/active downloads were carried over; old seeds were intentionally
      dropped.
- [ ] A final delta rsync reconciles any changes made on neon during the build.
- [ ] Playback of a migrated title works end-to-end over the mesh.

## Out of scope / don't touch

- Decommissioning neon / DNS cutover — that's `issues/009` (after this verifies).
- Building the helium stack — `issues/005`; this only feeds data into it.
- Immich/Paperless data — those are fresh deployments (`006`/`007`), not migrations.
- Don't `--delete` media on the live first pass; don't copy *arr DBs hot.
