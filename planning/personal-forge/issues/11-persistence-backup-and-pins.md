# Forgejo's persistence, backup, and image pins

Type: grilling
Status: resolved
Assignee: claude (session 2026-08-23c)

## Question

Graduated from the fog by ticket 01 (2026-08-23). Ticket 01 was research and
correctly stopped short of deciding these — but they are now sharp, load-bearing,
and all four are the owner's call. Full evidence:
[`../assets/01-forgejo-deployment-research.md`](../assets/01-forgejo-deployment-research.md) §1, §2.

**1. SQLite or PostgreSQL — which is really a question about backup machinery.**

- Forgejo's docs recommend **SQLite** unambiguously at this size (one user, ~20
  repos). PostgreSQL is for "high amount of activity".
- **But** helium's existing `restic-backup.service` is a naked filesystem walk, and
  a file-level copy of a live SQLite DB is **torn and unrestorable**. That is
  exactly why `restic-app-backup.sh` already exists for other services.
- So: **SQLite + a btrfs snapshot (or a stop window)** follows the docs and fixes
  tearing for *every* app on the precious subvol — the larger win. **Postgres**
  slots into the existing script with near-zero new code but goes against the docs
  for this size.
- **"Start on SQLite, migrate later" is not the free escape hatch it sounds like.**
  Ticket 01's premise here was wrong: `forgejo doctor convert` is a MySQL charset
  repair, **not** a cross-engine converter. There is no documented first-party
  SQLite→Postgres path — only `forgejo dump` plus manual re-injection, with the docs
  warning it "must be done carefully."
- **Either way, `.dotfiles/issues/016`'s backup unit has to change.** That is the
  fact that escapes this ticket's boundary and should be named in the answer.

**2. Pin `:15-rootless` (LTS) or track stable `:16`?**

LTS gives ~11 months of support vs ~9 weeks, turning "Forgejo maintenance" from a
quarterly chore into an annual one — and rootless matches the stack's
`cap_drop: ALL` house style. Recommendation is the LTS rootless pin, but confirm,
because it means deliberately running a version behind.

**3. The UID 1000 collision.** The rootless image wants its data dir
`chown 1000:1000` **before first start** or it may not start at all. On Debian, UID
1000 is **`ms`**. Decide whether Forgejo's data is owned by `ms`, or whether a
dedicated uid is remapped — rather than absorbing the collision silently and
discovering it later.

**4. Two mount-path traps to accept explicitly, so nobody rediscovers them:**
- The bind mount must target **`/var/lib/gitea`**, not `/data`, in the rootless
  image — otherwise the restic coverage silently misses the real data.
- `app.ini` lives at `/var/lib/gitea/custom/conf/app.ini`, **inside** the backed-up
  dir, and carries the `SECRET_KEY` that encrypts stored credentials (push-mirror
  creds, 2FA secrets). A restore that brings back only `git/` + the DB into an empty
  volume loses them **while reporting success**. This wants one line in a restore
  runbook, not a design change — but decide that the runbook exists.

Output: the persistence spec (engine, image pin, ownership, mount paths) plus a named
consequence for `issues/016`.

---

## Resolution (2026-08-24)

**The persistence spec: SQLite + a host-side `sqlite3 .backup` arm in
`restic-app-backup.sh`, `:15-rootless` floating on the LTS line, `user: "1001:1003"`,
bind-mounted at `/var/lib/gitea`, with the whole `forgejo/` dir excluded from the 016
appdata walk and owned end-to-end by the new arm.**

All four of the ticket's questions resolved, plus a fifth the answer to Q1 forced.
Premise measurements: [`../assets/11-persistence-measurements.md`](../assets/11-persistence-measurements.md).
Two of them changed the option set rather than merely confirming it, and one killed a
question outright.

### 1. Engine — SQLite, with the third option, not the two the ticket listed

**Decision: SQLite + host-side `sqlite3 .backup`, as a `forgejo)` arm in the existing
`restic-app-backup.sh`.** The btrfs-snapshot route is **parked as a follow-up**, not
dropped. Postgres is declined.

The ticket framed this as SQLite-plus-new-machinery versus Postgres-plus-no-new-code.
**There is a third option and it dominates**, because it is docs-aligned *and* needs
no new machinery. Neither of the shapes that would have made it awkward is available:
`forgejo dump` is disqualified by Forgejo's own upgrade docs ("serious long standing
open bugs that may introduce problems when re-injecting the SQL dump", per ticket 01),
and there is **no `sqlite3` binary in the image**, so the literal `docker exec …
pg_dump` shape cannot be copied. Host-side can, and `sqlite3 3.46.1-7+deb13u1` is one
apt away on trixie.

**Proven against the live, running ticket-05 prototype** — which happened to be
carrying a **4.17 MB uncheckpointed WAL against a 2.48 MB main file**, i.e. more than
half its state in the WAL, exactly the condition under which a naked file walk tears:

```
$ sqlite3 /d/forgejo.db 'pragma journal_mode;'   -> wal
$ time sqlite3 /d/forgejo.db ".backup /out/fj-backup.db"
real 0m0.006s
$ sqlite3 /out/fj-backup.db 'pragma integrity_check;'   -> ok
copy: 20 issues / 5 repos / 2 issue_dependency     # the 2 deps lived in the WAL
live: 20 issues / 5 repos
$ ls -la /d/forgejo.db*    # live db + wal mtimes UNCHANGED — non-invasive
```

**6 ms, single file, no sidecars, no checkpoint of the live DB.** `VACUUM INTO` also
works (20 ms, defragmented); `.backup` is the safer default because it does not
rewrite page layout.

Structurally this is the exact analogue of the `pg_dump` arm: consistent online copy →
staging dir → one `restic backup` under a tag → per-tag `forget --prune`, with the
same `trap cleanup EXIT` wipe of the plaintext copy.

**Why not the snapshot (option B), given it is the bigger win.** Ticket 01's cost
estimate for it could not be checked at the time and **it was too pessimistic**.
helium has no top-level btrfs mount — six per-subvol mounts only, and
`storage_ssd/tasks/subvolumes.yml` deliberately unmounts the top level — so the
obvious fear is that snapshotting needs new persistent-mount machinery against that
role's design. **Measured false**, on a loopback btrfs reproducing helium's exact
mount shape: `btrfs subvolume snapshot -r` and `btrfs subvolume delete` both work
from a subvol-only mount, either nested in the source or into a sibling subvol. So B
is a create → restic → delete pipeline and **no `storage_ssd` change at all**.

It is still deferred, on scope rather than cost: B fixes **26 SQLite DBs, 13 with hot
WAL sidecars** (`sonarr.db` 25.6 MB, `jellyfin.db` 20.7 MB, `bazarr.db-wal` 4.25 MB)
— which is a decision about helium's whole backup posture, not about Forgejo.
Folding it in here would ship a fleet-wide change to justify one service. It is
parked as its own item and judged on its own merits. **Shape 2 below makes the two
independent**, so they need no sequencing.

**Why not Postgres.** It goes against Forgejo's docs at this size ("low to moderate
activity … recommended to change this value to sqlite3"), adds a second container, a
role and a DB password in sops, and its "smallest new code" advantage evaporates once
the SQLite arm is measured at one `case` branch plus one apt package.

**The honest framing of the risk, which is not what it first looks like.** The torn-
SQLite failure class is **not new** — the naked appdata walk already covers 26 live
SQLite DBs and has done for months. What changed is the **blast radius, not the
likelihood**: a torn Sonarr DB costs an afternoon with the media library still on disk
as ground truth, whereas [ticket 07](07-tracker-cutover.md) makes Forgejo the **only**
copy of 56 issues plus every wayfinder map. "We already accept this everywhere" is
the tidier argument, not the true one — it is a reason to fix this instance, not to
shrug at it.

### 2. Image pin — `:15-rootless`, floating within the LTS line

**Decision: `codeberg.org/forgejo/forgejo:15-rootless`, floating across minors and
patches, with the upgrade trigger set by date: revisit ~May 2027**, two months before
the 15 Jul 2027 EOL, when 19.0 will be the next LTS.

A confirm, not a live choice. `:16` support ends 29 Oct 2026 and 17.0 lands
~mid-October on the quarterly cadence — deploying stable today buys ~9 weeks before a
forced major upgrade, then one every quarter, on a box explicitly not meant to be
babysat. Forgejo's FAQ says why there is no `latest` tag: a major upgrade "requires a
manual operation and human verification". Knowingly runs a major behind; nothing this
map depends on is a v16 feature (ticket 03 validated the issue model on v15, and the
ticket-05 prototype *is* 15.0.7).

**Floating rather than exact**, deliberately against the `host_vars` house style
(`audiobookshelf_version: "2.36.0"`): patch releases on an LTS line are the security
fixes you want arriving without a ticket, and the thing that actually needs human
verification is the major — which `:15` can never cross.

### 3. The UID 1000 collision — does not exist

**Decision: `user: "1001:1003"`, reusing the stack's service uid/gid, with a
pre-create-and-chown task before first start.**

**The question dissolved under measurement.** The image's baked-in `USER 1000:1000` is
**overridable by the plain compose `user:` directive**, with no `USER_UID`/`USER_GID`
env and no entrypoint complaint:

```
user: "1001:1003"   # host dir chowned 1001:1003 BEFORE first start
$ docker ps --format '{{.Status}}'  -> Up 30 seconds
$ curl -o /dev/null -w '%{http_code}' http://localhost:3211/   -> 200
$ docker exec forgejo-uidtest id   -> uid=1001 gid=1003 groups=1003
```

So there is no collision with `ms` and no dedicated uid to provision. This is the
**exact Audiobookshelf precedent** already recorded in `host_vars/helium/vars.yml`
("Upstream image has no PUID/PGID env support … it runs whatever uid the `user:`
compose directive sets"). Reusing `1001:1003` over a dedicated `forgejo_puid: 1004`
was weighed and taken: a dedicated uid would confine a container escape to one
service's state, but it is a number in `host_vars` either way (neither 1001 nor 1003
has a passwd/group entry), the stack already runs `cap_drop: [ALL]` +
`no-new-privileges`, and inventing a second convention for one service reads later as
an accident nobody remembers the reason for.

**The chown is genuinely load-bearing, not boilerplate.** The same test with the dir
left owned by 1000 dies instantly:

```
mkdir: can't create directory '/var/lib/gitea/git': Permission denied
/var/lib/gitea/git is not writable
docker setup failed          # container Exited (1)
```

Use the pre-create shape `compose_stack/tasks/stack.yml` already documents for
Jellyfin, for exactly this failure mode.

### 4. The two mount-path traps — accepted, plus a third found

- **Bind mount targets `/var/lib/gitea`**, never `/data`. Confirmed.
- **A third trap, measured:** the ticket-05 prototype's compose also mounts
  `./config:/etc/gitea`, and that mount is **vestigial — it stays empty**
  (`GITEA_APP_INI=/var/lib/gitea/custom/conf/app.ini`, and `/etc/gitea/` is empty in
  the running container). **Do not copy it into the ansible template.** Ticket 01's
  "no config bind mount at all" holds.
- **`app.ini` and the `SECRET_KEY`.** It lives at
  `/var/lib/gitea/custom/conf/app.ini`, inside the backed-up dir, and encrypts stored
  credentials and 2FA secrets. Shape 2 below puts it in the same restic snapshot as
  the DB it belongs to, which is the structural fix rather than a documentation one.

**Decision on the runbook: it exists AND is exercised once, as an acceptance
criterion on the execution issue** — restore the previous night's snapshot plus the DB
copy into a throwaway container, confirm it starts and the issue count matches. Minutes
of work, given `.backup` runs in 6 ms and the prototype rebuild is already scripted.

**Why exercised, not merely written.** Option A introduces a **two-step** restore —
restic-restore the dir, *then* drop the `.backup` copy in over `forgejo.db` and delete
stale `-wal`/`-shm` — with two ways to fail silently. And the house standard is already
"verified, not assumed": issue 016's AC is *"A test restore of one application's config
from a snapshot succeeds (verified, not assumed)"* [x], and issue 026 went further,
verifying *"the database backups restore to a consistent, working state"* plus a real
8.2 MB Immich original. **So the mechanism is proven and the Postgres DB path is
proven; what has never been attempted is restoring a live-walked SQLite DB and opening
it.** (An earlier draft of the asset overclaimed here — it said no restore had ever
been tested. Corrected in place.) This is the same trade
[ticket 10](10-forge-sync-contract.md) was shelved on: accepting a belief was right
there, because a repo is recoverable from any working clone, and wrong here, because a
lost issue DB is recoverable from nothing.

### 5. The consequence for `issues/016` — Shape 2, the whole dir moves

The ticket asked for this to be *named*; it turned out to have two shapes with
materially different restores, so it is a decision.

**Decision: `issues/016`'s unit excludes `/data/ssd/appdata/forgejo` entirely, and the
new `forgejo)` arm owns Forgejo's state end to end** — the DB copy **plus**
`/data/ssd/appdata/forgejo` as its `library_paths`, in one `restic backup` call under
one `--tag forgejo`.

This is the exact structural analogue of the Immich arm (dump + libraries, one
snapshot, one tag), and it earns three things over the narrow-exclude alternative
(exclude only `forgejo/forgejo.db*`, leave the rest to the appdata walk):

1. **The restore is single-tag.** Under narrow-exclude, Forgejo's state spans two tags
   written by two units on two timers, and a restore needs both at matching times.
2. **`custom/conf/app.ini` travels with the DB it encrypts**, rather than sitting in a
   different snapshot from a different hour — which is trap 4's real fix.
3. **The DB-to-git-object skew collapses** from hours to the script's own runtime,
   because both go into the same `restic backup` invocation.

Accepted cost: Forgejo stops being covered by the thing that covers everything else on
that subvol, so a silently-stopped forgejo timer is not backstopped by the appdata run.
Mitigated by the same `OnFailure=restic-backup-alert@` hook the other two arms already
use — and narrow-exclude has the identical exposure for the DB half anyway.

Residual, named rather than fixed: `restic` walks `forgejo/git/` while Forgejo is
running, so a repo created mid-run can exist in the DB copy and not the object store
or vice versa. Immich and Paperless already accept the identical skew, git's object
store is write-once, and Shape 2 shrinks the window to seconds.

### Named execution consequences (not decisions — for the build issues)

1. **`restic_backup/tasks/packages.yml`** gains `sqlite3` (3.46.1-7+deb13u1 on trixie).
2. **`restic-app-backup.sh`** gains a `forgejo)` arm: `sqlite3 <db> ".backup <staging>"`
   in place of the `docker exec … pg_dump | gzip` step, `library_paths=(/data/ssd/appdata/forgejo)`,
   tag `forgejo`. Note this arm is the first that does **not** need `docker exec`, so the
   script's `db_container`/`db_user`/`db_name` case variables do not apply — a small
   shape change to a script whose comments currently assume Postgres throughout.
3. **`restic-forgejo.service` + `.timer`**, staggered off 02:00 and off the immich/
   paperless slots, with `OnFailure=restic-backup-alert@`, plus enable/start in
   `app_backups.yml`'s loops.
4. **`restic-backup.service`** gains `--exclude=/data/ssd/appdata/forgejo` (and its
   header comment updated — it currently claims to cover the whole appdata subvol).
5. **Pre-create + chown `/data/ssd/appdata/forgejo` to `1001:1003` before first
   start**, in `stack.yml`'s Jellyfin shape. Ordering matters: it must run before the
   compose service ever starts.
6. **The restore runbook**, in 026's shape, with an AC that it was exercised.
7. `host_vars/helium/vars.yml`: `forgejo_version: "15-rootless"` (floating, contrary to
   the file's exact-pin convention — worth a comment saying why), and no
   `forgejo_puid`/`_pgid` (reuses `jellyfin_puid`/`jellyfin_pgid`).
