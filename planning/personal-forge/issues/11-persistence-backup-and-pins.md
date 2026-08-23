# Forgejo's persistence, backup, and image pins

Type: grilling
Status: open
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
