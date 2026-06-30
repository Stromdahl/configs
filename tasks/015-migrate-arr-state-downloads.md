# Task 015 — Migrate *arr state and active downloads from neon

**Source issue:** `issues/015-migrate-arr-state-downloads.md` — bring the *arr
Docker volumes (radarr/sonarr/prowlarr/bazarr/profilarr config + DBs) off neon onto
helium **intact** so history/quality-profiles/import-state come over rather than
being rebuilt, and carry only the lean/active downloads (drop the ~600 GB old seeds).

> **Depends on `issues/014` (the *arr + qBittorrent stack must be up on helium to
> receive the volumes) and `issues/008` (the library they index is migrated).**
> Do not grab until 014 is `done`.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/015` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief.
3. **Verify** the acceptance criteria below before declaring done. **Operational**
   task (rsync + container stop/start between live hosts) — little/nothing to commit
   beyond a runbook note.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: two live hosts, a coordinated stop window for SQLite
consistency, and a human call on which seeds to keep.

## Suggested agent

**Sonnet** — operational. The care points are *data-safety*: stop the source app
before copying its SQLite DB; fix ownership after copy.

## Human steps / blockers (`needs-human`)

- **`ssh <user>@neon` from helium** must work (verify, don't bootstrap mid-window).
- **Seed-curation decision:** the issue drops ~600 GB old completed seeds but defines
  no exact cutoff (age/ratio). The **user decides** which to keep; curate on neon
  (qBittorrent WebUI lists completion dates) before the downloads rsync.
- **Cold-copy window:** neon's *arr containers must be **stopped** during the state
  copy; the user signals go — the agent must not stop neon's services unilaterally.

## Decisions baked in (read before coding)

- **Project name + UID/GID must match what `tasks/014` deployed.** neon's stack pins
  project `jellyfin` (grep `name:`/`COMPOSE_PROJECT_NAME` in
  `servers/neon/docker-compose.yml`) with UID/GID `1001:1003` (`config.env`). Confirm
  `tasks/014` used the same, or volume identity/ownership diverges.
- **SQLite must be copied cold.** Stop each *arr container on the source before
  rsyncing its volume — copying an open DB risks corruption and a silent
  "rebuilt from scratch" (the failure the issue forbids).
- **Ownership fix is mandatory after copy.** rsync `-a` preserves neon's `1001:1003`;
  if helium's container UID/GID differs, `chown -R` or the apps can't read config.
- **qBittorrent download paths** referenced in the carried-over torrents point at
  neon's path — only active/incomplete torrents carry over and may need re-pointing
  in the WebUI (or re-scan on the new `/data/ssd/downloads`).

## Entry points (operational — grep-stable paths)

- **Source (neon):** *arr state →
  **`/var/lib/docker/volumes/jellyfin_<app>_volume/_data`** for `<app>` ∈
  {radarr, sonarr, bazarr, prowlarr, profilarr} (+ `jellyfin_qbittorrent_volume`).
  Downloads → `DOWNLOADS_SHARE` → **`/mnt/datastore/media/downloads`** (grep
  `servers/neon/config.env`).
- **Target (helium — grep `host_vars/helium/vars.yml`):** *arr config →
  `ssd_subvolumes_precious` `appdata` = **`/data/ssd/appdata/<app>`**; active
  downloads → `ssd_subvolumes_scratch` `downloads` = **`/data/ssd/downloads`**.

## Prior art to mirror

- `servers/neon/docker-compose.yml` — the volume names + the `${DOWNLOADS_SHARE}`
  bind mount (grep `radarr_volume:/config`, `${DOWNLOADS_SHARE`).
- `tasks/014-download-automation-gluetun-arr.md` — the helium stack receiving the
  volumes; source of the project name, UID/GID, and appdata/downloads paths.

## Steps

0. **Don't start until 014 + 008 are `done`** and `ssh <user>@neon` works from helium.
1. **Seed curation** (human): drop old completed seeds on neon; keep active only.
2. **Freeze + copy *arr state** (window): on neon
   `docker compose stop radarr sonarr prowlarr bazarr profilarr qbittorrent`; per app
   `rsync -aHAX --delete <neon>:/var/lib/docker/volumes/jellyfin_<app>_volume/_data/ /data/ssd/appdata/<app>/`;
   `chown -R 1001:1003 /data/ssd/appdata/*`.
3. **Downloads** (curated): `rsync -aHAX <neon>:/mnt/datastore/media/downloads/ /data/ssd/downloads/`.
4. **Start helium's *arr stack** (014 services) → they load the migrated config/DB
   (no rebuild); re-point qBittorrent paths if needed.

## Verify

- ***arr state intact (not rebuilt):** each `/data/ssd/appdata/<app>` holds
  `config.xml` + the app DB; `sqlite3 /data/ssd/appdata/radarr/*.db '.tables'`
  succeeds; the WebUIs show pre-existing library history + quality profiles.
- **lean downloads:** `du -sh /data/ssd/downloads` shows only active torrents.
- **final delta clean:** the last state/downloads sync reports zero new files.
- **automation works (human):** a grab/import the migrated state recognizes runs
  end-to-end.

## Acceptance criteria (from issue 015, verbatim)

- [ ] The *arr apps show their pre-existing library history and quality profiles
      (state migrated, not rebuilt).
- [ ] Only lean/active downloads were carried over; old seeds were intentionally
      dropped.
- [ ] A final delta sync reconciles any *arr/download changes made on neon during
      the build.
- [ ] After migration, an existing automation path still works end-to-end (e.g. a
      grab/import that the migrated *arr state recognizes).

## Out of scope / don't touch

- The media library rsync — `issues/008` (this assumes it's done).
- Building the *arr stack — `issues/014`; this only feeds data into it.
- Don't copy *arr DBs hot (stop the source container first).
