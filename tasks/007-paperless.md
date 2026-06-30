# Task 007 — Paperless document ingest, mesh-only

**Source issue:** `issues/007-paperless.md` — deploy Paperless-ngx (web + Postgres +
Redis + Gotenberg + Tika) on the SSD tier, served at `paperless.home.stromdahl.tech`
behind the internal Traefik, reachable only over the NetBird mesh. OCR on CPU. An
ingest path (consume folder + upload) makes added documents full-text searchable.

> **Depends on `issues/005` (the compose-stack role + internal Traefik + NetBird
> mesh) and `issues/011` (the SSD precious subvol the docs + DB live on).** Both
> must be `done` first. `issues/005` is `open` (briefed at `tasks/005`) — **do not
> grab until 005 is `done`**; this brief deliberately does NOT re-derive 005's
> Traefik/NetBird/compose plumbing — it reuses it.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/007` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: secrets the agent can't mint (Django secret key, admin
password, DB password), first-run admin login, and the manual ingest→OCR→search test.

## Suggested agent

**Sonnet** — once 005's compose-stack role exists, this is adding one service group
(webserver + redis + postgres + gotenberg + tika) + a Traefik router + sops secrets,
mirroring an established pattern. No hard reasoning.

## Human steps / blockers (`needs-human`)

- **Secrets (pre-deploy), into `host_vars/helium/secrets.sops.yml`, never to stdout:**
  `PAPERLESS_SECRET_KEY` (`openssl rand -base64 32 > file`, encrypt — don't echo),
  `PAPERLESS_ADMIN_USER`/`PAPERLESS_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`.
- **First-run admin:** confirm the admin auto-creates from env, or
  `docker exec paperless-webserver document_create_superuser`; verify UI login.
- **Ingest test (the AC):** drop a PDF into the consume folder, watch
  `docker logs`, confirm it appears, OCR completes, and a word from the text is
  full-text searchable.
- **Mesh:** approve the helium peer / confirm `paperless.home.stromdahl.tech`
  resolves to the mesh IP (per 005's NetBird setup).

## Decisions baked in (read before coding)

- **Paperless is NOT on neon** — `servers/neon/docker-compose.yml` has no
  paperless/gotenberg/tika. Prior art is the **official paperless-ngx compose**
  (canonical set: `webserver`, `broker` = redis, `db` = postgres, `gotenberg`,
  `tika`), adapted into 005's compose-stack role pattern.
- **All data on the SSD precious subvol** (`/data/ssd/paperless`, CoW + checksums) —
  documents/media, the consume folder, and the **Postgres data dir** all land here.
  Paperless never touches `/srv/media` or the HDD pool.
- **The subvol exists but is unowned.** `tasks/011` creates `/data/ssd/paperless`
  but sets no ownership. This task must `chown` the data dirs to Paperless's
  `USERMAP_UID:USERMAP_GID` (use the stack's container UID/GID — neon's precedent is
  `1001:1003`) before first start, or the container can't write.
- **OCR on CPU, English + Swedish:** set `PAPERLESS_OCR_LANGUAGE=eng+swe` — confirm
  the `swe` tesseract data ships in the paperless-ngx image (it bundles common
  langs; if not, add it). Enable Gotenberg + Tika (`PAPERLESS_TIKA_ENABLED=1` +
  the gotenberg/tika endpoint env) for office-doc + richer parsing.
- **redis/postgres/gotenberg/tika publish NO ports** — only the webserver gets a
  Traefik router; the rest are internal to the compose network. (005's
  Docker-bypasses-ufw plumbing already prevents LAN leakage — don't add `ports:`.)

## Entry points (create — grep-stable)

- **Add the Paperless service group** to the compose-stack the `tasks/005` role
  establishes — mirror its per-service block shape and Traefik-label idiom (grep the
  role/templates 005 created; do not invent a parallel mechanism).
- **Traefik router** for the webserver only:
  `Host(`paperless.home.stromdahl.tech`)`, `entrypoints=websecure`,
  `tls.certresolver=letsencrypt` (the LE DNS-01 resolver 005 sets up),
  `loadbalancer.server.port=8000` (Paperless web port — verify upstream). Reuse
  005's security-headers middleware.
- **Plain vars** → `ansible/host_vars/helium/vars.yml` (grep the compose-stack vars
  block 005 added):
  ```yaml
  paperless_data_root: /data/ssd/paperless        # media, consume, export, pgdata under here
  paperless_ocr_language: eng+swe
  paperless_usermap_uid: 1001
  paperless_usermap_gid: 1003
  ```
- **Secrets** → `ansible/host_vars/helium/secrets.sops.yml` (encrypted): the three
  secrets above.

## Prior art to mirror

- `tasks/005-media-stack-traefik-netbird.md` + the `compose_stack` role it builds —
  **load-bearing**: the role, the sops→`.env` templating, the Traefik resolver, the
  NetBird mesh. Paperless plugs into all of it.
- `servers/neon/docker-compose.yml` — the Traefik v3 label idiom + how a webserver-only
  router is attached while backing services stay internal (grep `traefik.http.routers`).
- Official paperless-ngx `docker-compose.yml` + `docker-compose.env` — the canonical
  service set + env keys (`PAPERLESS_REDIS`, `PAPERLESS_DBHOST`, `PAPERLESS_CONSUMPTION_DIR`,
  `USERMAP_UID/GID`).
- `tasks/011-data-tier-btrfs-raid1.md` — confirms `/data/ssd/paperless` is the
  precious-subvol mount.

## Steps

0. **Don't start until 005 + 011 are `done`.**
1. `chown` `/data/ssd/paperless/{media,consume,export,pgdata}` to the container
   UID/GID (create the subdirs via `ansible.builtin.file`).
2. Add the 5-service Paperless group to 005's compose template; wire env from plain
   vars + sops secrets; point media/consume/export/pgdata at the SSD subdirs.
3. Add the Traefik router (webserver only) for `paperless.home.stromdahl.tech`.
4. Deploy via the compose-stack role; re-run for idempotence.

## Verify

- **idempotent:** second `ansible-playbook site.yml --tags compose,services` →
  `changed=0`.
- **reachable over mesh, valid cert, not public (human):**
  `curl -v https://paperless.home.stromdahl.tech/` from a mesh peer → real LE cert,
  login page; not reachable from the public internet.
- **on SSD tier:** `ansible nas -b -m shell -a 'findmnt -T /data/ssd/paperless; ls -ld /data/ssd/paperless/{media,pgdata}'` → on `/data/ssd`, owned by the container UID/GID.
- **ingest → OCR → search (human, the core AC):** drop a PDF into the consume folder,
  confirm it ingests, OCRs, and a word from its text is searchable in the UI.
- **backing services internal:** `docker inspect` shows no published `ports` on
  redis/postgres/gotenberg/tika.

## Acceptance criteria (from issue 007, verbatim)

- [ ] Paperless is reachable at `paperless.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly.
- [ ] A document added via the ingest path is OCR'd and becomes full-text
      searchable.
- [ ] Documents and Postgres data reside on the SSD tier.
- [ ] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets.

## Out of scope / don't touch

- Backups / versioning of the irreplaceable docs — deferred (future backup work).
- Non-root/cap hardening — `issues/010`.
- The HDD pool / media tier — Paperless lives only on the SSD tier.
- 005's Traefik/NetBird/compose plumbing — reuse, don't re-derive.
