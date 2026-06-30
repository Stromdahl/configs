# Task 008 — Migrate the media library from neon

**Source issue:** `issues/008-migrate-library-arr-state.md` — rsync the ~932 GB
movies+shows library off neon into helium's HDD pool, so Jellyfin serves the real
library. **Live first pass** while neon keeps serving, then a **final delta** at
cutover. (The *arr state + active-downloads migration is `issues/015`.)

> **Depends on `issues/003` (HDD pool) and `issues/005` (Jellyfin, to serve +
> verify).** The pool mount `/srv/media` is **already live** — so the live rsync
> first pass can start **now, in the background**, before 005's stack is built; it
> only needs the pool, and neon holds the only other copy. Closing the issue (final
> delta + Jellyfin verification) waits on 005.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/008` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief.
3. **Verify** the acceptance criteria below before declaring done. This is an
   **operational** task (rsync between live hosts), not a repo code change — there
   may be nothing to commit beyond a runbook note.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: it operates on two live hosts, needs `ssh helium→neon`,
and the final delta + playback sign-off happen in a coordinated window.

## Suggested agent

**Sonnet** — operational orchestration (SSH + rsync), not architectural reasoning.
The care point is data-safety discipline: never `--delete` against a half-populated
target.

## Human steps / blockers (`needs-human`)

- **Two live hosts reachable:** neon (`192.168.1.153`) + helium on the LAN; rsync over
  SSH. Confirm `ssh <user>@neon` works **from helium** before starting (servers hold
  no GitHub key, but host↔host SSH must already be set up — verify, don't bootstrap).
- **Final delta window:** the last `--delete` pass should run when neon isn't being
  actively written; the user signals go.
- **Playback sign-off:** after migration + 005 live, the user tests playback of a
  few titles over the mesh.

## Decisions baked in (read before coding)

- **Live first pass WITHOUT `--delete`; `--delete` only at the cold final delta.**
  A `--delete` against a still-filling target can wipe good data.
- **Media only — *arr state + downloads are `issues/015`.** Don't copy
  `/var/lib/docker/volumes/*` or the downloads dir here.
- **Don't disturb SnapRAID content files.** `tasks/003` keeps `.snapraid.content`
  on the data drives outside the `/srv/media` union — the rsync targets `/srv/media`
  and won't touch them.

## Entry points (operational — grep-stable paths)

- **Source (neon, deployed at `/opt/neon/`):** `MEDIA_SHARE` →
  **`/mnt/datastore/media/media`** (grep `servers/neon/config.env` for `MEDIA_SHARE`).
  ~932 GB.
- **Target (helium):** `hdd_union_mount` = **`/srv/media`** (grep
  `host_vars/helium/vars.yml`; 003's mergerfs union).

## Prior art to mirror

- `servers/neon/config.env` — confirms `MEDIA_SHARE` (the source path).
- `tasks/003-hdd-pool-mergerfs-snapraid.md` — confirms `/srv/media` is the union mount.
- `tasks/005` — the Jellyfin stack that serves + lets you verify the migrated library.

## Steps

1. **Live first pass** (neon keeps serving, start now):
   `rsync -aHAX --info=progress2 <neon>:/mnt/datastore/media/media/ /srv/media/`
   (no `--delete`).
2. **Final delta** (cutover window, source quiescent):
   `rsync -aHAX --delete <neon>:/mnt/datastore/media/media/ /srv/media/`.
3. Trigger a Jellyfin library scan; confirm titles appear.

## Verify

- **library present:** `ansible nas -b -m shell -a 'du -sh /srv/media; find /srv/media -type f | wc -l'` ≈ neon's count + ~932 GB.
- **visible in Jellyfin:** the library populates after a scan.
- **final delta clean:** the last rsync reports zero new files transferred.
- **playback (human):** a migrated title plays end-to-end over the mesh.

## Acceptance criteria (from issue 008, verbatim)

- [ ] The full ~932 GB library is present on the HDD pool and visible in Jellyfin.
- [ ] A final delta rsync reconciles any changes made on neon during the build.
- [ ] Playback of a migrated title works end-to-end over the mesh.

## Out of scope / don't touch

- *arr Docker volumes + active downloads — `issues/015`.
- Decommissioning neon / DNS cutover — `issues/009`.
- Don't `--delete` on the live first pass.
