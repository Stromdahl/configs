# Ticket 11 premise measurements — persistence, backup, ownership

Run 2026-08-23, before the grilling, to replace the ticket's assumptions with facts.
Every command below is reproducible; hosts named per measurement.

---

## M1 — UID 1000 on helium is `ms` (ticket premise CONFIRMED)

```
$ ssh ms@192.168.1.191 'getent passwd 1000'
ms:x:1000:1000:ms,,,:/home/ms:/bin/bash
```

`getent passwd 1001` and `getent group 1003` return **nothing** — the stack's
service uid/gid (`jellyfin_puid: 1001` / `jellyfin_pgid: 1003`, reused by the *arr,
Paperless and Audiobookshelf) are **numeric-only, with no passwd/group entry**. That
is the existing house convention, not an accident.

## M2 — the rootless image runs fine as a non-1000 uid (ticket Q3 DISSOLVES)

The ticket asks whether Forgejo's data ends up owned by `ms` or whether a dedicated
uid is remapped. Measured: the image's baked-in `USER 1000:1000` is **overridable by
the plain compose `user:` directive**, with no `USER_UID`/`USER_GID` env and no
entrypoint complaint.

```
$ docker run ... codeberg.org/forgejo/forgejo:15-rootless   # user: "1001:1003"
  volumes: ./data:/var/lib/gitea    # host dir chowned 1001:1003 BEFORE first start
$ docker ps --filter name=forgejo-uidtest --format '{{.Status}}'
Up 30 seconds
$ curl -s -o /dev/null -w '%{http_code}' http://localhost:3211/
200
$ docker exec forgejo-uidtest id
uid=1001 gid=1003 groups=1003
```

Log confirms a clean start: `Listen: http://0.0.0.0:3000`,
`SSH server started on :2222`, `CustomConf changed from '' to
'/var/lib/gitea/custom/conf/app.ini'`.

**The chown is genuinely load-bearing** — the same test with the dir left owned by
1000 fails hard and immediately:

```
mkdir: can't create directory '/var/lib/gitea/git': Permission denied
/var/lib/gitea/git is not writable
docker setup failed        # container Exited (1)
```

So: `user: "1001:1003"` + a pre-create/chown task is the answer, and it is the
**exact Audiobookshelf precedent** already in `host_vars/helium/vars.yml` ("Upstream
image has no PUID/PGID env support … it runs whatever uid the `user:` compose
directive sets"). No collision with `ms`, no new uid to provision.

## M3 — `app.ini` really is inside the backed-up data dir (trap 2 CONFIRMED)

Against the live ticket-05 prototype:

```
$ docker exec forgejo-proto2 env | grep GITEA_APP_INI
GITEA_APP_INI=/var/lib/gitea/custom/conf/app.ini
$ docker exec forgejo-proto2 ls -la /var/lib/gitea/custom/conf/
-rw-------  1 git git 1435  app.ini
$ docker exec forgejo-proto2 ls -la /etc/gitea/
(empty)
```

Note the prototype's compose mounts `./config:/etc/gitea` and that mount is
**vestigial — it stays empty**. Ticket 01's "no config bind mount at all" holds; the
prototype's extra mount is dead weight and should not be copied into the ansible
template.

## M4 — the naked walk already covers 26 live SQLite DBs, 13 with hot `-wal`

`restic-backup.service` walks `/data/ssd/appdata` with no pre-step. What is in there:

```
$ sudo find /data/ssd/appdata \( -name '*.db' -o -name '*.sqlite*' \) | wc -l
26
$ sudo find /data/ssd/appdata -name '*-wal' | wc -l
13
```

Largest: `sonarr/sonarr.db` 25.6 MB, `jellyfin/data/data/jellyfin.db` 20.7 MB,
`profilarr.db` 6.9 MB, `radarr.db` 5.7 MB; hot WAL sidecars up to
`bazarr.db-wal` 4.25 MB. Also `hermes/state.db`, `hermes/kanban.db`,
`audiobookshelf/config/absdatabase.sqlite`, `cleanuparr/*.db`,
`jellyseerr/db/db.sqlite3`.

**So the torn-SQLite failure class is not new — it is already accepted 26 times
over, silently.** But it has never been exercised: the repo holds 12 appdata
snapshots (8.6 → 9.2 GiB, nightly 02:00, ~10 s wall / 5.3 s CPU per run) and no
restore of a torn SQLite DB has ever been attempted (see the correction below).

**Correction to an earlier draft of this asset, which overclaimed.** A restore
*has* been verified on both paths — but not the part that matters here. Issue 016's
AC reads "A test restore of one application's config from a snapshot succeeds
(verified, not assumed)" [x], and issue 026 went further, verifying that "the
database backups restore to a consistent, working state" plus a real file restore of
an 8.2 MB Immich original. So the mechanism is proven and the *Postgres* DB path is
proven. What has **never** been verified is that a **live-walked SQLite database**,
restored from the naked appdata walk, opens cleanly — which is precisely the untested
claim, and the house standard in both those ACs is "verified, not assumed".

The blast radii are not equal, and that is the argument that matters: a torn Sonarr
DB costs an afternoon with the media library still on disk as ground truth. Ticket 07
makes Forgejo the **only** copy of 56 issues plus every wayfinder map.

## M5 — no top-level btrfs mount on helium … but one is NOT required

```
$ ssh ms@192.168.1.191 'findmnt -t btrfs -o TARGET,OPTIONS'
/data/ssd/downloads   subvol=/@downloads
/data/ssd/immich      subvol=/@immich
/data/ssd/paperless   subvol=/@paperless
/data/ssd/transcode   subvol=/@transcode
/data/ssd/appdata     subvol=/@appdata
/data/ssd/vault       subvol=/@vault
```

Six per-subvol mounts, **no `subvolid=5` mount** — `storage_ssd/tasks/subvolumes.yml`
mounts the top level only transiently and deliberately unmounts it. The obvious worry
is that snapshotting therefore needs new persistent-top-level-mount machinery against
that role's design. **Measured false.** Reproduced helium's exact mount shape on a
loopback btrfs (privileged container, `btrfs-progs` 6.x, Debian trixie):

```
mount -o subvol=@appdata   $LOOP /data/ssd/appdata
mount -o subvol=@transcode $LOOP /data/ssd/transcode      # no top-level mount

# A: dest nested inside the source subvol
btrfs subvolume snapshot -r /data/ssd/appdata /data/ssd/appdata/.snap1   -> OK
# B: dest inside a DIFFERENT mounted subvol on the same fs
btrfs subvolume snapshot -r /data/ssd/appdata /data/ssd/transcode/appdata-snap -> OK
# C: delete, also from the subvol-only mount
btrfs subvolume delete /data/ssd/transcode/appdata-snap  -> OK
```

One wrinkle from variant A: a later snapshot lists the earlier one as an entry
(`ls .snap2` shows `.snap1`) — snapshots are not recursive, so it is an empty stub,
but it is clutter. Variant B (sibling subvol) avoids it.

**Cost of the snapshot route, corrected:** no `storage_ssd` change, no persistent
top-level mount, no `@snapshots` subvol at the top level. It is a create → restic →
delete pipeline — i.e. exactly the "ordered multi-step pipeline that does not fit a
static ExecStart line" that `restic-app-backup.sh` was written for. The one real
consequence is that **restic's source path changes** from `/data/ssd/appdata` to the
snapshot path, which changes the `paths` metadata on future snapshots (dedup is
content-addressed, so no storage cost).

## M6 — the third option the ticket does not consider: host-side `sqlite3 .backup`

Neither `docker exec` nor `forgejo dump` is available or advisable:

```
$ docker exec forgejo-proto2 sh -c 'command -v sqlite3 || echo NONE'
NONE                     # no sqlite3 in the image -> no pg_dump-shaped docker exec
```

(`forgejo dump` is separately disqualified by ticket 01's primary source: Forgejo's
own upgrade docs say it "has serious long standing open bugs that may introduce
problems when re-injecting the SQL dump".)

But **host-side works, and helium is one apt away**:

```
$ ssh ms@192.168.1.191 'apt-cache policy sqlite3'
sqlite3:  Installed: (none)   Candidate: 3.46.1-7+deb13u1
```

Proven against the **live, running** ticket-05 prototype (sqlite3 3.46.1 in a
trixie container bind-mounting the same data dir — same inode, same host POSIX
locks, so equivalent to a host-side run):

```
$ sqlite3 /d/forgejo.db 'pragma journal_mode;'          -> wal
$ time sqlite3 /d/forgejo.db ".backup /out/fj-backup.db"
real 0m0.006s
$ sqlite3 /out/fj-backup.db 'pragma integrity_check;'   -> ok
$ # rows in the copy vs live, while Forgejo is serving:
copy: 20 issues / 5 repos / 2 issue_dependency
live: 20 issues / 5 repos
$ ls -la /out/fj-backup.db*     # single file, no -wal/-shm sidecars
$ ls -la /d/forgejo.db*         # live db + wal mtimes UNCHANGED — non-invasive
```

The live DB carried a **4.17 MB uncheckpointed WAL against a 2.48 MB main file** at
the time — i.e. more than half the state was in the WAL, which is precisely the
condition under which a naked file walk tears. The copy picked it up (the 2 blocking
dependencies live in the WAL) and `.backup` did **not** checkpoint or otherwise
mutate the live database.

`VACUUM INTO` also works (20 ms, 2.47 MB — defragmented) and is the same guarantee.
`.backup` is the safer default: it does not rewrite page layout.

**Structurally this is the exact analogue of `pg_dump` in `restic-app-backup.sh`:**
consistent online copy → staging dir → one restic backup under a tag → per-tag
`forget --prune`, with the same `trap cleanup EXIT` wipe. It needs `sqlite3` in
`restic_backup/tasks/packages.yml` and a `forgejo)` arm in the existing `case` — and
**no storage machinery at all**.

Residual, worth naming rather than fixing: the DB copy is at time T while the git
object store is walked at T+n, so a repo created in between can exist in one and not
the other. Immich and Paperless already accept the identical skew, and git's store is
write-once, so this is a known-and-accepted seam, not a new defect.
