# Forgejo's deployment shape on helium — research findings

Resolves `planning/personal-forge/issues/01-forgejo-deployment-shape.md`.
Researched 2026-08-23. Primary sources are `forgejo.org/docs`, `forgejo.org/releases`,
the `codeberg.org/forgejo/forgejo` source tree, and the official container registry.
Local claims are cited to files in this repo. Two claims were verified
**empirically** against a live Forgejo instance (marked as such).

Reading order note: **§2 (database), §4 (fit), §5 (SSH) and §6 (registry) are the
load-bearing ones.** §6 contains a premise collision that ticket 08 must resolve.

---

## 1. Image + version

**Verdict.** Current stable is **v16.0.3** (2026-08-20); current LTS is **v15.0.7**
(2026-08-20). The official image is `codeberg.org/forgejo/forgejo`, mirrored at
`data.forgejo.org/forgejo/forgejo`. **Recommendation: pin the LTS line
(`:15-rootless`), not `:16`.**

**Evidence.**

- Releases and support windows: <https://forgejo.org/releases/> — v16.0.3 support
  **ends 29 October 2026**; v15.0.7 is "supported until 15 July 2027".
- Cadence: <https://forgejo.org/docs/latest/admin/release-schedule/> — quarterly
  majors, three months of support for non-LTS, one LTS per year with ~15 months.
  LTS line: 11.0 → 16 Jul 2026, **15.0 → 15 Jul 2027**, 19.0 → 13 Jul 2028.
- Image + tag scheme: <https://forgejo.org/docs/latest/admin/installation/docker/>
  (compose examples use `codeberg.org/forgejo/forgejo:16`) and
  <https://forgejo.org/faq/>. `:16` floats across minors within major 16; `:16.0`
  floats across patches; `:16.0.3` is pinned. Every tag has a `-rootless` variant.
  **There is deliberately no `latest` tag** — the FAQ's reason is that a major
  upgrade "requires a manual operation and human verification".

**Why LTS.** Deploying `:16` today buys ~9 weeks before EOL, and 17.0 is due
~mid-October on the quarterly cadence — a forced major upgrade almost immediately,
then one every quarter. This is a forge nobody wants to babysit; the map already
lists "Forgejo maintenance — upgrade cadence" as unresolved fog. LTS turns that
from quarterly to annual.

**Verified empirically (the LTS tags actually exist).** The web package listing at
<https://codeberg.org/forgejo/-/packages/container/forgejo> only renders the newest
tags, so the `15` tags were confirmed against the mirror's registry API:

```
$ curl -s 'https://data.forgejo.org/v2/forgejo/forgejo/tags/list?n=10000'
444 tags, including: 15, 15-rootless, 15.0, 15.0-rootless, 15.0.7, 15.0.7-rootless
```

**Rootful vs rootless is not cosmetic — decide it here, because §2 and §5 depend
on it.** Confirmed from the shipped Dockerfiles:

| | rootful | rootless |
|---|---|---|
| data path | `/data` | `/var/lib/gitea` (`GITEA_WORK_DIR`) |
| image user | root | **`USER 1000:1000`** |
| SSH | **OpenSSH under s6** (`EXPOSE 22 3000`) | **builtin Go server**, `START_SSH_SERVER = true`, `EXPOSE 2222 3000` |
| `app.ini` | `/data/gitea/conf/app.ini` | `/var/lib/gitea/custom/conf/app.ini` (`GITEA_APP_INI`) |

Sources: <https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/Dockerfile>,
<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/Dockerfile.rootless>
(`ENV GITEA_WORK_DIR=/var/lib/gitea`, `ENV GITEA_APP_INI=${GITEA_CUSTOM}/conf/app.ini`,
`USER 1000:1000`, `EXPOSE 2222 3000`),
<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/docker/rootless/etc/templates/app.ini>
(which contains, verbatim: `; In rootless gitea container only internal ssh server
is supported`).

**Recommendation: rootless.** It matches helium's house style —
`ansible/roles/compose_stack/templates/docker-compose.yml.j2` gives every service
`cap_drop: [ALL]` + `no-new-privileges:true`, with Traefik as the single
*documented* root exception. Port 2222 needs no bind capability, where 22 would.

**Two concrete requirements rootless imposes on the ansible work — both are the
kind of thing that fails on first start, not at review time:**

1. **The bind mount must target `/var/lib/gitea`**, not `/data`
   (`/data/ssd/appdata/forgejo:/var/lib/gitea`). Get this wrong and §2's backup
   coverage silently misses.
2. **The host dir must be owned `1000:1000` before first start.** The docs are
   explicit — `sudo chown -R 1000:1000 ./forgejo`, and "the volume should be owned
   by the user/group with the UID/GID specified in the config file. If you don't set
   the volume correct permissions, the container may not start."
   <https://forgejo.org/docs/latest/admin/installation/docker/> (whose rootless
   compose example uses `user: 1000:1000`). **This repo already documents the exact
   same failure mode**, for Jellyfin, in
   `ansible/roles/compose_stack/tasks/stack.yml`: dirs "must be owned by
   `jellyfin_puid:jellyfin_pgid` before first start, otherwise docker creates them
   root-owned and Jellyfin cannot write to them." So a pre-create task is required,
   in that established shape.

   **But unlike Jellyfin's, these IDs are baked into the image, not host_vars-driven**
   — and on Debian **UID/GID 1000 is normally the first human user** (`ms`). So the
   Forgejo data dir would end up owned by `ms:ms` rather than a service identity.
   That is a collision worth a deliberate decision rather than a shrug: either accept
   it, or override with `user:` + `USER_UID`/`USER_GID` to a dedicated id. Flagging,
   not deciding.

**Thin evidence:** none — the version, tag scheme and image internals are all
directly sourced. Note one **correction to a figure in circulation**: the rootless
user is `1000:1000` per the Dockerfile and the current docs, **not** `1024:100`
(which is Gitea's older rootless value and appears in stale write-ups).

---

## 2. Database — SQLite vs PostgreSQL

**Verdict.** Forgejo's docs recommend **SQLite** for this profile, unambiguously.
But **the docs' recommendation and helium's existing backup machinery point in
opposite directions**, and that tension is the real finding — not the DB choice.

### What the docs say

> "If your instance sees a low to moderate amount of activity, it is recommended to
> change this value to **sqlite3**. SQLite3 is a simple, non-maintenance requirement
> and one file on disk database."
> — <https://forgejo.org/docs/latest/admin/setup/recommendations/>

PostgreSQL/MySQL are recommended only "If your instances see a high amount of
activity", and the docs say the choice between *those two* comes down to admin
familiarity, not technical merit. One user / ~20 repos is squarely the SQLite case.
The binary-install page adds a hedged aside — "apparently sqlite is good enough for
at least 10 users, but might even suffice for more"
(<https://forgejo.org/docs/latest/admin/installation/binary/>) — quoted with its
hedging intact, because that *is* the docs' confidence level.

Caveats the docs actually attach: `VACUUM` "might be needed … if the database size
grows too big"; build with `TAGS="sqlite sqlite_unlock_notify"` if compiling
(irrelevant for the container).
<https://forgejo.org/docs/latest/admin/installation/database-preparation/>

**Thin evidence, stated plainly:** the primary docs contain **no quantified
concurrency limit and no size limit** for SQLite. The recommendations page only says
performance degrades under high concurrent load, without numbers. Do not import a
generic SQLite claim and dress it as a Forgejo one.

### The migration escape hatch is weaker than assumed

**The ticket's premise about `forgejo doctor convert` is wrong.** The CLI reference
defines it as "A command to convert an existing MySQL database from utf8 to
utf8mb4" — a MySQL charset repair, **not** a cross-engine converter.
<https://forgejo.org/docs/latest/admin/command-line/>

There is **no documented first-party SQLite→Postgres conversion command.** The only
route is `forgejo dump --database postgres` plus manual re-injection, and the docs
warn: "transitioning to another database with an existing database is not a trivial
task and must be done carefully." So "start on SQLite, migrate if I outgrow it" is
a real undocumented-path cost, not a freebie.

### Backup — where the docs and this repo collide

The upgrade guide is the closest thing Forgejo has to a backup doc
(<https://forgejo.org/docs/latest/admin/upgrade/>), and it says three things that
matter here:

1. `forgejo dump` "has serious long standing open bugs that may introduce problems
   when re-injecting the SQL dump" — which undercuts dump-as-primary-backup for
   *both* engines.
2. SQLite needs no separate dump step "because the database itself is included in
   the zip file already."
3. The **most reliable** method is "a synchronized point-in-time snapshot of all the
   storage used by Forgejo", exemplified by a QCOW2 disk snapshot taken live.
   Stopping the instance is only demanded for distributed storage (S3, Redis, remote
   FS); "if everything is on a single file system and if the instance is not busy
   (no mirrors, no users), the backup can be done" live.

**The trap: restic is not a point-in-time snapshot.** helium's existing unit
(`ansible/roles/restic_backup/files/systemd/restic-backup.service`) is a naked
filesystem walk:

```
ExecStart=/usr/bin/restic backup /data/ssd/appdata --repo /mnt/disk1/backups/restic-appdata \
  --password-file /etc/restic/appdata.pass --tag appdata --exclude-caches \
  --exclude=**/cache --exclude=**/log --exclude=**/logs
```

No pre-hook, no stop window, and none of those excludes protect a live SQLite file
plus its `-wal`/`-shm` sidecars. A Forgejo instance at
`/data/ssd/appdata/forgejo` **would be picked up automatically** by this unit
(good — the path requirement in the ticket is satisfied by default), but the DB
inside it could be captured torn. Note the asymmetry: the **git object store
survives a torn walk far better than the DB does** — loose objects and packfiles are
write-once — so it is specifically the database that is unsafe, not the repos.

**This repo already contains the fix pattern, and it exists for exactly this
reason.** `ansible/roles/restic_backup/files/restic-app-backup.sh` was written
because a "file-level copy of the live PGDATA … can be torn and unrestorable"; it
does `docker exec … pg_dump | gzip` into a staging dir, restic-backs-up the dump
plus the file libraries under a per-app tag, then per-tag `forget --prune`.

So the honest trade — and it is the reverse of what the docs alone would suggest:

| | SQLite | PostgreSQL |
|---|---|---|
| Forgejo docs | **recommended** for this size | recommended only for high activity |
| new backup machinery needed | **yes** — a `sqlite3 .backup` pre-step, a stop-the-container window (seconds, single user), or a btrfs snapshot | **no** — slots into `restic-app-backup.sh`'s existing `case` arm |
| covered by today's `restic-backup.service` as-is | picked up, but **not safely** | must be excluded from the appdata walk and backed up by the app script |
| ops surface | one file, no daemon, `VACUUM` occasionally | a second container, a role, a DB password in sops |
| escape hatch if wrong | undocumented migration path | n/a (already the endpoint) |

**A point in SQLite's favour that the docs don't know about:** `appdata` is a
**precious btrfs subvolume on a raid1 mirror**
(`ansible/host_vars/helium/vars.yml`: `ssd_subvolumes_precious: [appdata, immich,
paperless, vault]`). A `btrfs subvolume snapshot -r` is *exactly* the
"synchronized point-in-time snapshot" the docs bless, and taking one before restic
walks would fix the tear for **every** app on that subvol, not just Forgejo. That
is a genuinely attractive third option, and it is a change to issue 016's unit
rather than to Forgejo.

### A second backup axis the DB question hides: `SECRET_KEY`

Backup complexity is not only about torn files. Forgejo generates `SECRET_KEY` and
`INTERNAL_TOKEN` on first run and uses them to **encrypt stored credentials —
including push-mirror credentials (§7) and 2FA secrets**. Restore the data dir into
a container that generates a *fresh* key and those fields are unrecoverable even
though the backup "worked" and reported success.

Whether this bites depends on the §4 finding, and the answer is reassuring:
`app.ini` lives at `/var/lib/gitea/custom/conf/app.ini` — **inside** the
bind-mounted, restic-covered data dir — and the rootless entrypoint only runs
`envsubst < /etc/templates/app.ini` when the file does **not** already exist. So a
restore of the data dir brings the original `SECRET_KEY` back with it, and this is a
non-issue **provided the restore restores `custom/conf/` too and not just the repo
and DB paths.** Worth one line in the restore runbook rather than a design change.
The one shape that *would* lose it: declaring `SECRET_KEY` nowhere and restoring
only `git/` + the DB into an empty volume.

**Recommendation for the grilling ticket to weigh, not a decision:** SQLite +
snapshot-then-restic is the smallest-total-machinery answer *and* follows the docs;
Postgres is the smallest-*new*-code answer because the pipeline already exists.
Either way, **issue 016's unit has to change** — that is the fact that escapes this
ticket.

---

## 3. Resource footprint

**Verdict.** **Forgejo publishes no resource requirements at all.** Any sizing claim
for helium is inference, not documentation. The Forgejo *server* is not the concern;
**the Actions runner is.**

**The absence is the finding.** Checked the installation index, the binary install
page, the Docker install page, the recommendations page and the FAQ — none carries a
requirements section. No minimum RAM, no recommended RAM, no CPU count, no idle
footprint. The only first-party claim is homepage marketing: "With a rich feature
set, Forgejo still has a low server profile and requires an order of magnitude less
resources than other forges" (<https://forgejo.org/>) — an unquantified
comparative, not a spec.

- **Closest documented number, from the adjacent lineage — label it as Gitea's, not
  Forgejo's:** "2 CPU cores and 1GB RAM is typically sufficient for small
  teams/projects", plus Git ≥ 2.0.0 — <https://docs.gitea.com/>. Forgejo is a fork
  of Gitea, so this is a defensible order-of-magnitude proxy and nothing more.
- **No idle-RSS figure is given here on purpose.** No primary source for one was
  found. Community write-ups circulate figures in the low hundreds of MB;
  that is **unverified** and should not be quoted as fact in the spec.
- **Do not anchor on the project's own infra.** `code.forgejo.org`'s
  `forgejo01` is a 16-thread / 64 GB KVM guest
  (<https://code.forgejo.org/infrastructure/documentation>) — that is a public
  multi-tenant instance for the whole project and says nothing about 20 repos.

**Actions runner — documented facts, and this is the part that matters:**

- The runner "is installed and configured separately from Forgejo" and can live on a
  different host; "Multiple Forgejo Runner installations can be connected to a
  single Forgejo instance to distribute jobs over a cluster".
  <https://forgejo.org/docs/latest/admin/actions/runner-installation/>
- Same page, verbatim: **"Forgejo Runner performs remote code execution. That poses
  significant security threats for the host and network that it operates upon."**
- The official Docker install path uses **docker-in-docker** — `docker:dind`,
  `DOCKER_HOST=tcp://docker-in-docker:2375`, i.e. a **privileged Docker daemon**.
  <https://forgejo.org/docs/latest/admin/actions/installation/docker/>
- The only documented knob bounding runner resource use is **`capacity`, default
  `1`** ("Execute how many tasks concurrently at the same time"), with job
  `timeout: 3h`. The runner-configuration doc page defers to the example config
  rather than listing values:
  <https://code.forgejo.org/forgejo/runner/src/branch/main/internal/pkg/config/config.example.yaml>
- **No documented RAM/CPU figure for the runner either.**

**Read for helium (16 GB, i5-9400 6C/6T, no SMT).** The forge itself is small by
every available indication and will not be what hurts. CI jobs are bursty and
CPU-hungry and would contend, on six threads, with three workloads that are already
bursty and CPU-hungry (Jellyfin transcode, Immich ML, Paperless OCR) plus nightly
snapraid. The map has already accepted that contention ("helium being loaded
sometimes is explicitly acceptable — including contending with Jellyfin"), so this
is not a re-litigation. The documented mitigations are: keep `capacity: 1` (already
the default), and place the runner on a different host if wanted. The `dind`
privilege surface deserves separate weight — see §"What this means for the map".

**Thin evidence:** everything quantitative in this section. Stated as such.

---

## 4. Fit with helium's existing pattern

**Verdict. Yes — it drops in cleanly, and it is a better fit than the ticket's
hazard list implies: two of the three named hazards do not apply to Forgejo at
all.** The genuine deltas are a new published SSH port and (per §2) a change to
issue 016's backup unit.

### It fits the established shape exactly

A service in `ansible/roles/compose_stack/templates/docker-compose.yml.j2` gets:
appdata under `{{ ssd_pool_mount }}/appdata/<name>` declared in `stack.env.j2`, a
`cap_drop: [ALL]` + `no-new-privileges:true` block, a healthcheck, and five Traefik
labels. Forgejo's would read:

```
traefik.enable=true
traefik.http.routers.forgejo.rule=Host(`git.${DOMAIN}`)
traefik.http.routers.forgejo.entrypoints=websecure
traefik.http.routers.forgejo.tls.certresolver=letsencrypt
traefik.http.services.forgejo.loadbalancer.server.port=3000
traefik.http.routers.forgejo.middlewares=security-headers@file
```

That is the `audiobookshelf` shape verbatim with the port changed. Exposure model:
`compose_restrict_to_mesh: false` (LAN + mesh, never public), with the public
boundary being OPNsense having no port-forward —
`ansible/roles/compose_stack/tasks/firewall.yml`.

### Config comes from env vars — so Forgejo brings NO config bind mount

This was checked specifically, because it is what decides whether the single-file
inode hazard applies. It does not: **Forgejo needs no templated `app.ini` bind
mount.** The container entrypoint runs an `environment-to-ini` step on **every
start** (not just first run):

```sh
# docker/rootless/usr/local/bin/docker-setup.sh
envsubst < /etc/templates/app.ini > ${GITEA_APP_INI}      # first run only
# Replace app.ini settings with env variables in the form GITEA__SECTION_NAME__KEY_NAME
environment-to-ini --config ${GITEA_APP_INI}              # every start
```

<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/docker/rootless/usr/local/bin/docker-setup.sh>

So Forgejo's config slots into `stack.env.j2` exactly like every other service on
this box. Details verified in source:

- **Both prefixes are accepted.** `modules/setting/config_env.go` has
  `EnvConfigKeyPrefixGitea = "^(FORGEJO|GITEA)__"` — so `FORGEJO__server__SSH_PORT=222`
  is the canonical form and `GITEA__…` still works.
  <https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/modules/setting/config_env.go>
- **There is a `__FILE` suffix variant** (`EnvConfigKeySuffixFile = "__FILE"`) that
  reads a value from a file instead of the environment. That is a direct match for
  the pattern the Traefik service already uses for its Cloudflare token
  (`CF_DNS_API_TOKEN_FILE` via a compose `secrets:` tmpfs mount, chosen because
  "plain env vars are visible via `docker inspect`"). Any Forgejo secret should use
  it.
- **Documented limitation:** "It is not possible to use environment variables to
  remove an existing value, it must be done by editing the `app.ini` file."
  <https://forgejo.org/docs/latest/admin/installation/docker/>
- **`app.ini` is mutable state that Forgejo writes back to** — the installer, some
  admin settings, and generated secrets. For rootless it lives at
  `/var/lib/gitea/custom/conf/app.ini`, i.e. **inside** the bind-mounted data dir, so
  restic covers it (§2). The interaction to be aware of: `environment-to-ini` rewrites
  a file Forgejo also owns, on every container start. Env-declared keys win; keys
  Forgejo wrote and env does not mention survive.

### Two named hazards are retired, not mitigated

- **`project_helium_traefik_acme_restart`, the single-file-inode trap: does not
  apply — for two independent reasons.** First, that trap is about
  `./config/traefik/dynamic.yml` being a single-file bind mount whose inode gets
  pinned; Forgejo would be a **label-based docker provider** router, so no
  `dynamic.yml` edit is involved (HA is the file-provider case; Forgejo is not).
  Second, and more importantly, **Forgejo brings no single-file bind mount of its
  own** — its config is env-var-driven (above), so it cannot reintroduce the same
  trap by a different route. That second point was the one worth checking.
- **`project_helium_traefik_acme_restart`, the first-cert DNS-01 stall: already
  fixed in the compose template.** The Traefik command carries
  `--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53`
  with an inline comment naming issue 044 — that was the actual fix for new-subdomain
  issuance failing against the split-horizon LAN resolver. A new `git.` subdomain
  should therefore issue without intervention. Worth verifying on first deploy, but
  it is no longer an expected failure.

### The ufw hazard is status quo, not aggravated

`firewall.yml` installs `iptables-persistent` **unconditionally on every
`--tags compose` run**, and the `ufw Breaks iptables-persistent` conflict is why the
full nas play is non-idempotent (`project_ufw_breaks_iptables_persistent`). Forgejo
adds no *new* exposure to that hazard — but it does mean the deploy must be the
scoped `ansible-playbook site.yml --limit helium --tags compose`, never a full play.
One line in the spec, no design consequence.

### The genuine deltas

1. **A new published port — and it would be the stack's only one besides Traefik's.**
   Verified against the template: **`traefik` is the sole service with a `ports:`
   block** (`80:80`, `443:443`); everything else reaches the world through Traefik or
   through gluetun's shared netns. Forgejo's SSH needs a published host port
   (`222:2222`) — see §5 — so it would be the second service ever to publish one on
   this box. With `compose_restrict_to_mesh: false` that port is LAN + mesh reachable,
   consistent with the chosen model. Not a hazard, but a genuine first for the stack,
   and it does not pass through Traefik at all — so nothing in the Traefik posture
   constrains it.
2. **Issue 016's backup unit changes** either way — §2.
3. **A pre-create + `chown 1000:1000` task**, in the Jellyfin shape — §1.
4. **SSD capacity.** The precious tier is a 480 GB btrfs raid1 mirror shared with
   Immich and Paperless. ~20 mostly-small personal repos is negligible; CI artifacts
   and Actions logs are not necessarily. Worth a retention thought, not a blocker.

---

## 5. SSH access for git

**Verdict.** helium keeps sshd on 22 and **does not have to give it up**. The
officially documented Docker shape is to publish Forgejo's SSH on an **alternate
host port** (the docs use 222) and set `SSH_PORT` so the UI and API advertise it.
The "host sshd + `AuthorizedKeysCommand` shim" alternative is official **only for a
bare-metal install** — for a container it is a community pattern with a closed WIP
docs PR and a live bug, and should be rejected.

### Config keys — all in `[server]`

Verified in source (`modules/setting/ssh.go` reads `rootCfg.Section("server")`) and
the cheat sheet. <https://forgejo.org/docs/latest/admin/config-cheat-sheet/> ·
<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/modules/setting/ssh.go>

| Key | Default | Meaning (verbatim from `app.example.ini` / cheat sheet) |
|---|---|---|
| `DISABLE_SSH` | `false` | "Disable SSH feature when not available" |
| `START_SSH_SERVER` | `false` | "Whether to use the builtin SSH server or not." |
| `SSH_USER` | `%(BUILTIN_SSH_SERVER_USER)s` | "SSH username displayed in clone URLs." |
| `SSH_DOMAIN` | `%(DOMAIN)s` | "Domain name to be exposed in clone URL" |
| `SSH_PORT` | `22` | "Port number to be exposed in clone URL" |
| `SSH_LISTEN_PORT` | `%(SSH_PORT)s` | "The port number the builtin SSH server should listen on" |
| `SSH_CREATE_AUTHORIZED_KEYS_FILE` | `true` | "Forgejo will create a authorized_keys file by default when it is not using the internal ssh server. If you intend to use the AuthorizedKeysCommand functionality then you should turn this off." |
| `SSH_ROOT_PATH` | `~/.ssh` | root of the SSH dir |

**The key semantics, which is the direct answer to the ticket's clone-URL
question:** `SSH_DOMAIN` + `SSH_PORT` + `SSH_USER` are **display-only** — they are
what the web UI renders in the clone box and what the API returns as `ssh_url`.
`SSH_LISTEN_PORT` is what the server actually binds. They are deliberately
decoupled so a container published on host port 222 can advertise `SSH_PORT = 222`
while listening on 2222 inside.

### The three options

**(a) Alternate host port — official, recommended.**
<https://forgejo.org/docs/latest/admin/installation/docker/> — rootful
`ports: - '222:22'`; rootless `ports: - "222:2222"`. Docs verify with
`ssh -F /dev/null git@<address> -p 222`. Host sshd on 22 is untouched. Users get a
`~/.ssh/config` `Host` block with `Port 222`. **Zero conflict.** Combined with the
§1 rootless recommendation, this is `ports: - "222:2222"` plus
`SSH_PORT = 222`, `SSH_LISTEN_PORT = 2222`, `SSH_DOMAIN = git.home.stromdahl.tech`.

**(b) Builtin Go server vs OpenSSH-in-container.** Determined by the image variant,
not by choice — rootful runs OpenSSH under s6, rootless forces
`START_SSH_SERVER = true` (§1). The docs note the builtin server also sidesteps the
SSH key file-permission problem on network storage: it "embeds the `ssh` server,
circumventing the problem entirely." The recommendations page's OpenSSH hardening
advice explicitly does not apply when the builtin server is used.
<https://forgejo.org/docs/latest/admin/setup/recommendations/>

**(c) Host sshd + `AuthorizedKeysCommand` shim.** The **bare-metal** form is
official (recommendations page):

```
Match User git
  AuthorizedKeysCommandUser git
  AuthorizedKeysCommand /usr/bin/forgejo --config /etc/forgejo/conf/app.ini keys -u %u -t %t -k %k
```

with documented warnings: the binary must be root-owned and not group/world-writable
(an sshd requirement), the full path is required, "the whole config is parsed on each
execution … this might take a few seconds", and `SSH_CREATE_AUTHORIZED_KEYS_FILE`
must be set `false`.

**Thin/negative evidence — say it loudly.** The `docker exec` variant of (c) is
**not in official docs**. The only Forgejo-project source is docs PR #666
("WIP: Adds `SSH Container Passthrough`"), which is **closed** — WIP since
2024-09-11, closed 2025-05-05 for inactivity (<https://codeberg.org/forgejo/docs/pulls/666>).
And it only ever covered *half* the problem: container SSH passthrough needs both the
key **lookup** (`forgejo keys`) and the forced-command **execution** (`forgejo serv`)
to cross the container boundary. Forgejo issue #6889 ("git SSH commands don't work
when running inside docker container", <https://codeberg.org/forgejo/forgejo/issues/6889>)
is the tracker evidence that this path is rough. **Recommendation: do not build
this.** The alternate-port option costs one `~/.ssh/config` block.

A third shape the docs don't discuss — a second sshd on a different IP/interface
with `SSH_PORT = 22` and a dedicated hostname — is implied by the key semantics but
has **no doc backing**; treat as untested.

### The coupling that bites ticket 10

`ssh_url` in the API response (§8) is rendered from `SSH_DOMAIN`/`SSH_PORT`/`SSH_USER`.
**If the port is published as 222 and `SSH_PORT` is left at its default 22,
`forge sync` will read a clone URL that does not work.** This is the concrete
Q5↔Q8 dependency and belongs in ticket 10's acceptance criteria.

**Also thin:** the *exact* rendered string form (scp-style `git@host:owner/repo.git`
vs `ssh://git@host:222/owner/repo.git`) was not verified. The semantics were; the
template output was not. Confirm on first deploy — it changes how `forge sync`
parses.

---

## 6. Container registry — and a premise collision

**Verdict, two parts.**

1. **Anonymous `docker pull` from Forgejo does work** — for a *public owner*, with
   `service.REQUIRE_SIGNIN_VIEW = false`. Confirmed in source **and verified
   empirically against a live instance.**
2. **But "helium is never publicly exposed" and "radon anonymously pulls from
   helium's registry" cannot both be true.** This is a **contradiction the map does
   not yet acknowledge**, and resolving it is ticket 08's job.

### The registry works, and anonymous pull works

**Package types (23 named; docs say "24"):** Alpine, ALT, Arch, Cargo, Chef,
Composer, Conan, Conda, **Container**, CRAN, Debian, Generic, Go, Helm, Maven, npm,
NuGet, Pub, PyPI, RPM, RubyGems, Swift, Vagrant.
<https://forgejo.org/docs/latest/user/packages/>

Container registry: "any OCI compliant client"; naming `{registry}/{owner}/{image}`;
tags case-insensitive; auth required "to push an image or if the image is in a
private registry".
<https://forgejo.org/docs/latest/user/packages/container/>

Documented access control (<https://forgejo.org/docs/latest/user/packages/>):
user-owned read = "public, if user is public"; org-owned read = "public, if org is
public"; and "public access can be restricted instance-wide by the setting of
`service.REQUIRE_SIGNIN_VIEW`." The docs carry their own caveat: "N.B.: These access
restrictions are subject to change…"

**Source confirmation.** `routers/api/packages/container/container.go` — the
`/v2/token` endpoint hands an anonymous caller a **ghost user** rather than a 401:

```go
u := ctx.Doer
if u == nil {
    if setting.Service.RequireSignInView {
        APIUnauthorizedError(ctx)
        return
    }
    u = user_model.NewGhostUser()
}
```

`services/packages/perm.go` → `DeterminePackageAccessMode` returns
`perm.AccessModeRead` for a nil/ghost doer when the owner is public, bailing out
early only under `RequireSignInView && (doer == nil || doer.IsGhost())`. And
`verifyContainerAuth` maps `AuthenticationNotAttempted` to
`&auth.UnauthenticatedResult{}` rather than an error — anonymous is a first-class
outcome, not a failure.

**Verified empirically, 2026-08-23, against `codeberg.org` (itself Forgejo):**

```
$ curl -o /dev/null -w '%{http_code}' https://codeberg.org/v2/forgejo/forgejo/manifests/16
401
$ curl -D - https://codeberg.org/v2/
www-authenticate: Bearer realm="https://codeberg.org/v2/token",service="container_registry",scope="*"
$ T=$(curl -s 'https://codeberg.org/v2/token?scope=repository:forgejo/forgejo:pull&service=codeberg.org' | jq -r .token)   # no credentials
$ curl -H "Authorization: Bearer $T" -o /dev/null -w '%{http_code}' https://codeberg.org/v2/forgejo/forgejo/manifests/16
200
```

The bare 401 is the **normal registry challenge** that `docker pull` handles
automatically; the token endpoint issues a usable token with **no credentials
supplied**, and the manifest then returns 200. So the doc statement, the source, and
live behaviour all agree. Good news for the mechanism.

### The collision (load-bearing for ticket 08)

The problem is not whether anonymous pull works — it does. It is **where the
registry lives**:

- The registry is **same-origin with the web UI** (`{registry}/{owner}/{image}` under
  `ROOT_URL`). Forgejo offers **no way to expose only `/v2/`**.
- helium's chosen exposure model is LAN + mesh, never public — DNS points
  `*.home.stromdahl.tech` at helium's LAN IP via OPNsense Unbound, and "the public
  boundary is OPNsense having no port-forward"
  (`ansible/roles/compose_stack/tasks/firewall.yml`).
- radon is **standalone, not on the mesh** (map, hardware table;
  `project_radon_public_apps`), and currently pulls
  `ghcr.io/stromdahl/settleup:sha-153c7e3` anonymously
  (`ansible/host_vars/radon/vars.yml:14`).

Therefore: **radon cannot pull from helium's registry without publicly exposing
helium's Forgejo** — the whole instance, not just the registry. That contradicts both
the PRD's private-only posture and the map's stated motive.

**Exits, enumerated rather than chosen** (this is ticket 08's decision):

1. **radon joins the mesh.** Cleanest technically; breaks radon's "standalone"
   premise and its ADR-0002 edge-host posture.
2. **Images stay on GHCR.** A deliberate carve-out from "GitHub goes dark" — GHCR is
   a *registry*, not a repo host, so this may cost less against the motive than it
   first sounds.
3. **Push images to radon from krypton** (`docker save`/`skopeo copy` into radon's
   local daemon). No registry pull at all; radon stops needing to reach anything.
4. **A reverse proxy publicly scoping `/v2/` only.** Your own work, not a Forgejo
   feature, and it still puts a Forgejo surface on the public internet.

**Two sharp sub-facts to carry into that decision:**

- **Read access follows the *owner's* visibility, not the linked repo's.** A publicly
  pullable image therefore forces a **public owner**, and everything under that owner
  becomes publicly readable. There is no per-repository OCI privacy — open feature
  request <https://codeberg.org/forgejo/forgejo/issues/2699>.
- **Prefer a user-owned package over org-owned.** Org-owned public packages have had
  access-control bugs — <https://codeberg.org/forgejo/forgejo/issues/972>. And verify
  any chosen shape empirically with `docker logout` first.

`REQUIRE_SIGNIN_VIEW = true` kills anonymous pulls outright ("User must sign in to
view anything") — relevant because a privacy-motivated instance is exactly the kind
that would want it on.

---

## 7. Push-mirroring

**Verdict.** Native, **per-repository**, and adequate for the deferred
GitHub-mirror follow-up. Configured in the repo's own settings, not globally.

<https://forgejo.org/docs/latest/user/repo-mirror/>

- **Per-repo:** Settings → Repository → Mirror Settings → target URL, optional
  comma-separated branch filter, credentials, "Add Push Mirror". "The repository now
  gets mirrored periodically to the remote repository." There is a manual
  "Synchronize Now" button and an optional trigger-on-new-commits.
- **Auth to GitHub:** a **fine-grained PAT with repository *contents* permission**,
  URL `https://github.com/<user>/<project>.git`, GitHub username + token as password.
  SSH keypair auth is also supported (Forgejo generates an Ed25519 key to add as a
  deploy key).
- **Documented warning:** "This will force push to the remote repository. This will
  overwrite any changes in the remote repository!"
- **Asymmetry worth knowing:** *pull* mirroring can only be set at repo-creation
  time. Push mirroring can be added later. Since the follow-up would be
  Forgejo→GitHub push, this is fine — but it means a future "GitHub as upstream"
  reversal is not a settings change.

**What actually gets pushed — from source**
(<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/services/mirror/mirror_push.go>):

- `Force: true, Mirror: true`.
- Refspecs: `+refs/heads/*:refs/heads/*` (all branches, or only filtered ones) **plus
  always** `+refs/tags/*:refs/tags/*`.
- **LFS is synced only `if setting.LFS.StartServer && !useSSHAuthentication`** — i.e.
  **no LFS sync when the mirror authenticates over SSH.** Concrete and quotable;
  matters for `diy-speekers` / `freecad-prints` / `custom-keyboard` if any use LFS.
- SSRF hardening: `recheckPushPermitted` against allowlists,
  `ProhibitHTTPRedirect: true`.

**Global toggles:** `[mirror]` — `ENABLED`, `DISABLE_NEW_PULL`, `DISABLE_NEW_PUSH`,
`DEFAULT_INTERVAL` (8h), `MIN_INTERVAL` (10m, with a 1-minute floor enforced).
`[repository] DISABLE_MIRRORS` exists but is **deprecated** in favour of
`[mirror] ENABLED`.

**Contested evidence — a real docs/source discrepancy.** The config cheat sheet
renders `[mirror] ENABLED` default as **false**, but
`modules/setting/mirror.go` initializes `Enabled: true`. **Source wins — the default
is `true`.** Set it explicitly in `app.ini` rather than relying on either.
<https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/modules/setting/mirror.go>
vs <https://forgejo.org/docs/latest/admin/config-cheat-sheet/>

**Thin evidence:** wiki, releases and issues fall outside those two refspecs, so they
are presumably **not** mirrored — but that is an inference from the refspecs, not a
doc statement. "Mirror of a mirror" has no evidence either way. If the follow-up
effort ever cares about mirroring *issues* to GitHub, treat it as unanswered.

---

## 8. API surface for repo listing

**Verdict.** Fully sufficient for `forge sync`. Read-only token scoping exists
(`read:repository`), the response carries both `clone_url` and `ssh_url`, and the
instance serves its own OpenAPI spec.

**Endpoints** (swagger comments quoted from source):

- `GET /api/v1/user/repos` — "List the repos that the authenticated user owns";
  params `page`, `limit`, `order_by`; returns a bare `RepositoryList` array.
  <https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/routers/api/v1/user/repo.go>
- `GET /api/v1/users/{username}/repos`, `GET /api/v1/orgs/{org}/repos` — same shape.
- `GET /api/v1/repos/search` — full query surface (`q`, `topic`, `uid`, `private`,
  `archived`, `mode`, `sort`, `order`, `page`, `limit`). **Note the different return
  shape:** an envelope `{"ok": true, "data": [...]}` (`SearchResults`), *not* the
  bare array the other three return. A `forge sync` implementation must not assume
  one shape for both.
  <https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/routers/api/v1/repo/repo.go>

**Pagination:** `page` + `limit`; responses carry a `Link` header and
`x-total-count`; server-side limits are discoverable at `/api/v1/settings/api`.
<https://forgejo.org/docs/latest/user/api-usage/>

**Response shape** (`modules/structs/repo.go`): `clone_url` (HTTP(S)), `ssh_url`,
`html_url`, `original_url`, `wiki_clone_url`, `wiki_ssh_url`, `full_name`, `name`,
`id`, `private`, `mirror`. **`ssh_url` is rendered from
`SSH_DOMAIN`/`SSH_PORT`/`SSH_USER`** — see the §5 coupling; getting those right is
what makes this output usable for automation. For a curation/archival flow the
`archived` field and `private` flag map neatly onto the map's alive/parked/dead
curation axis.

**Auth model:** HTTP basic auth, `Authorization: Bearer <token>`, or
`Authorization: token <token>`. Tokens mintable via `POST /users/:name/tokens` with
basic auth; "The `sha1` (the token) is only returned once and is not stored in
plain-text." 2FA adds an `X-Forgejo-OTP: 123456` header.

**Scopes** (<https://forgejo.org/docs/latest/user/token-scope/>): nine families —
`activitypub`, `admin`, `issue`, `misc`, `notification`, `organization`, `package`,
`repository`, `user` — each available as `read:{scope}` / `write:{scope}`, where
`read` = GET only and `write` = mutating verbs + GET (write implies read).

- **For read-only repo listing: `read:repository`.** Yes, tokens can be strictly
  read-only. There is additionally a **"Public only"** token restriction limiting a
  token to public resources.

**OpenAPI:** yes — interactive docs at `https://<instance>/api/swagger`, spec at
`https://<instance>/swagger.v1.json`. That means `forge sync` can be written against
a machine-readable contract on the actual deployed version.

**Thin evidence — Gitea API compatibility is de-facto, not documented.** The docs
page states only Forgejo's *own* promise: compatibility within a major version, with
breaking changes noted in release notes for major upgrades. **No official statement
of Gitea API parity was found.** Observable: same `/api/v1` shape,
`modules/structs/repo.go` still Gogs/MIT-copyrighted and structurally identical, and
`Basic realm="Gitea Package API"` still emitted in `reqPackageAccess`. But renames
exist — the OTP header is `X-Forgejo-OTP`, not `X-Gitea-OTP`. Practically: Gitea
clients mostly work; that is not a guarantee. **Consequence for the map's
`issue-tracker-forgejo.md` adapter idea: write it against Forgejo's own swagger, not
against a Gitea client library.**

---

## 9. Anything that would make Gitea the better pick

**Verdict. The evidence does not overturn the presumption. Forgejo stays.** There is
exactly **one** honest counterweight, and it lands on the CI requirement.

### The one real point for Gitea: GitHub Actions compatibility *intent*

Each project's own docs:

- **Forgejo:** "Forgejo Actions strives for **familiarity** instead of
  **compatibility**. We want users of GitHub actions to feel familiar using Forgejo
  Actions, even if there are some small changes here and there." It is "not designed
  to be compatible", and "If you wish to migrate a workflow from GitHub Actions to
  Forgejo Actions, some minimal tweaking will most likely be necessary." Documented
  gaps: default runner image is Debian bookworm + Node.js (thinner than GitHub's
  Ubuntu image); "Some keys in the `github` context are missing"; "Certain subkeys on
  the `job` key in workflow files are ignored, like `permissions`, and
  `continue-on-error`"; OIDC uses `enable-openid-connect` rather than
  `permissions: id-token: write`. The page says the list may be incomplete.
  <https://forgejo.org/docs/latest/user/actions/github-actions/>
- **Gitea:** Actions "is designed to be compatible with GitHub Actions, there are
  some differences between them", then enumerates a bounded list.
  <https://docs.gitea.com/usage/actions/comparison>

Both diverge from GitHub. The difference is **stated intent**: Gitea targets
compatibility and lists exceptions; Forgejo explicitly disclaims it.

**How much this matters here: little.** lumin has **no GitHub Actions workflow to
port** — its QA pipeline is a `justfile` plus a spec
(`~/projects/lumin/.scratch/qa-pipeline/spec.md`), so the CI workflow will be
hand-written for this instance either way. If the map's deferred
"reusable workflow in `rust-template`" ever wanted to lift a published third-party
GitHub workflow verbatim, this would sting. Today it does not.

**Forgejo-specific operational details worth recording now:** workflows live in
`.forgejo/workflows`, falling back to `.github/workflows` if absent; and
`DEFAULT_ACTIONS_URL` defaults to `https://data.forgejo.org/`, so third-party
actions need **fully qualified URLs** — the docs "strongly recommend" them. Both
affect how lumin's workflow gets written (ticket 04/09).

### Everything else favours Forgejo or is a wash

- **Hard fork: confirmed, and one-way.** "a decision was made in early 2024 to
  become a hard fork. By doing so, Forgejo is no longer bound to Gitea" … "As of
  Forgejo v1.21, Forgejo contains all of Gitea, and that has the benefit of allowing
  Forgejo to be a drop-in replacement. With the decision to become a hard fork, this
  will no longer be guaranteed."
  <https://forgejo.org/2024-02-forking-forward/>; governance record
  <https://codeberg.org/forgejo/governance/issues/58>. Gitea→Forgejo migration is
  documented and gets harder over time; **Forgejo→Gitea is not offered as a
  supported path.** Worth naming explicitly: choosing Forgejo is a door that closes
  behind you.
- **Licensing.** Forgejo v9.0+ is **GPLv3-or-later** (<https://forgejo.org/faq/>,
  which also notes it is deliberately not AGPL/EUPL despite requests). Gitea remains
  **MIT** (<https://about.gitea.com/products/gitea/>). For a private single-user
  forge **neither license constrains you at all.** GPLv3 matters if you fear a future
  proprietary relicensing upstream; MIT matters if you ever want to embed
  commercially. A values question, not a technical one — and the map's motive
  ("less dependent on bigtech") points at copyleft.
- **Correcting the ticket's premise:** it says "Gitea Ltd". Gitea's own site now
  attributes leadership and commercial support to **CommitGo, Inc.**, holding the
  2026 copyright and selling Gitea Cloud (managed) and Gitea Enterprise (self-hosted:
  SSO, audit logs, SLA) alongside the MIT core. That is open-core by Gitea's own
  description — though note the paid tier is SSO/audit/SLA, i.e. nothing a single
  user wants.
- **Feature divergence on the three requirements (private forge, package registry,
  issue tracker): none found.** Both inherit the same feature set and neither
  project's docs advertise an advantage. That empty result *is* the answer; the
  decision does not turn on features.
- **Governance — read Forgejo's own comparison with care.**
  <https://forgejo.org/compare-to-gitea/> is advocacy by an interested party.
  Verifiable/structural: Forgejo is under Codeberg e.V. (non-profit); Gitea's
  trademark and domains sit with a for-profit; Gitea requires copyright assignment
  even for MIT code; Forgejo self-hosts development on Forgejo + Weblate while Gitea
  develops on GitHub + Crowdin. **Not repeated as fact:** the claims that "Gitea does
  not have end-to-end or upgrade tests", that security advance notice is "for
  customers only", and that Gitea deprioritizes timely security releases. Its
  federation claim ("there is no work in Gitea regarding forge federation") is dated
  **December 2024** — ~20 months stale.
- **Federation (ActivityPub)** is Forgejo's genuine differentiator and is
  **irrelevant** to a single-user private forge. Do not count it as a reason.

**Net:** Forgejo wins on governance structure (non-profit stewardship, copyleft, no
copyright assignment, no open-core tier) — which is precisely the axis the map's
motive names — and matches on every required feature. Gitea's only edge is stated
Actions-compatibility intent, which is near-irrelevant given hand-written workflows.
There is also a mild irony worth noting: Gitea develops **on GitHub**, which cuts
against the motive.

---

## What this means for the map

Six facts change downstream decisions.

1. **Ticket 08 is a contradiction, not an open question (§6).** "helium never
   public" and "radon anonymously pulls from helium's registry" cannot both hold —
   the registry is same-origin with the web UI and Forgejo offers no way to expose
   only `/v2/`. Four exits are enumerated in §6; 08 must pick one. Anonymous pull
   itself is **not** the blocker — that works (verified live). Two sub-facts
   constrain any answer: read access follows the **owner's** visibility (so a public
   image forces a public owner and everything under it becomes readable), and
   user-owned packages are safer than org-owned.

2. **The DB choice is really a backup-machinery choice, and issue 016's unit changes
   either way (§2).** The docs recommend SQLite; helium's existing
   `restic-backup.service` is a naked filesystem walk that would capture a live
   SQLite DB torn. `restic-app-backup.sh` already exists precisely because
   file-level copies of live databases are unrestorable. So: SQLite + a btrfs
   snapshot (or a stop window) follows the docs and fixes tearing for *every* app on
   the precious subvol; Postgres slots into the existing script with near-zero new
   code but goes against the docs for this size. And "start SQLite, migrate later"
   is an **undocumented path** — `forgejo doctor convert` is a MySQL charset repair,
   not a converter.

3. **`SSH_PORT` → `ssh_url` is a hard coupling for ticket 10 (§5, §8).** Publishing
   Forgejo's SSH on host port 222 without setting `SSH_PORT = 222` makes the API
   hand `forge sync` a clone URL that does not work. This belongs in 10's acceptance
   criteria. Related unverified detail: the exact rendered URL form (scp-style vs
   `ssh://`) — confirm on first deploy, since it changes how `forge sync` parses.

4. **New to the map, and it deserves a place in the CI fog: the runner's documented
   default shape is a privileged docker-in-docker daemon (§3)** — on the box holding
   the family photo archive (Immich) and every scanned document (Paperless), with
   Forgejo's own docs warning that the runner "performs remote code execution. That
   poses significant security threats for the host and network that it operates
   upon." `capacity: 1` is the only documented bound. Given the map's motive is
   privacy and independence, "where does the runner live, and how is it confined" is
   a real open question, not a deployment detail. It sits alongside the already-fog
   question of how lumin's `cage`+`grim` headless-Wayland gate behaves inside a
   container — also unresolved, and possibly the harder of the two.

5. **Pin the LTS, and pin rootless (§1).** `:15-rootless` (verified to exist) gives
   ~11 months of support versus ~9 weeks for `:16`, turning "Forgejo maintenance"
   from a quarterly chore into an annual one. Rootless also matches the stack's
   `cap_drop: ALL` house style — **but it carries two easy-to-miss requirements**:
   the bind mount must target `/var/lib/gitea` (not `/data`) or §2's backup coverage
   silently misses, and the host dir must be `chown 1000:1000` **before first start**
   or the container may not start at all. On Debian, UID 1000 is normally `ms` — a
   collision worth deciding on rather than absorbing.

6. **Config is env-var-driven, which is better than assumed (§4).** Forgejo needs no
   templated `app.ini` bind mount: `environment-to-ini` runs on every container start
   and accepts `^(FORGEJO|GITEA)__SECTION__KEY`, with a `__FILE` suffix variant that
   matches the compose-`secrets:` pattern Traefik already uses for its Cloudflare
   token. So Forgejo drops into `stack.env.j2` like any other service, and it cannot
   reintroduce the single-file-inode trap by a side door. The caveat: env vars can
   set a value but **cannot remove one**, and `app.ini` is a file Forgejo also writes
   to.

**Two hazards the map lists can be struck for this service (§4):** the
`dynamic.yml` single-file-inode trap does not apply (Forgejo is a label-based docker
router with no config bind mount of its own), and the first-cert DNS-01 stall was
already fixed
in the compose template by issue 044's public-resolver flags. The ufw /
iptables-persistent hazard is unchanged — it only means the deploy must be
`ansible-playbook site.yml --limit helium --tags compose`, never a full play.
