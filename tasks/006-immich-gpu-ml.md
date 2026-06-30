# Task 006 — Immich with CPU-based ML, mesh-only

**Source issue:** `issues/006-immich-gpu-ml.md` — deploy Immich (server +
machine-learning + Postgres + Redis) as a private Google-Photos replacement, with
**ML on the CPU** (i5-9400 — the RTX 2060 was pulled, so there is NO CUDA path).
Served at `immich.home.stromdahl.tech` behind the internal Traefik, mesh-only;
library + DB on the SSD data-tier mirror.

> **Depends on `issues/005` (the compose-stack role + internal Traefik + NetBird
> mesh) and `issues/011` (the SSD precious subvol the library + DB live on).** Both
> must be `done` first. `issues/005` is `open` (briefed at `tasks/005`) — **do not
> grab until 005 is `done`**; this brief reuses 005's plumbing and does NOT
> re-derive it.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/006` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: the `DB_PASSWORD` secret the agent can't mint, the
phone-app auth + first upload, and the long initial CPU bulk-index all need the user.

## Suggested agent

**Sonnet** — once 005's compose-stack role exists, this is adding Immich's 4-service
group + a Traefik router + one secret, mirroring an established pattern. The only
subtlety (CPU-only ML, the special Postgres image) is pinned below.

## Human steps / blockers (`needs-human`)

- **`DB_PASSWORD` secret** — generate a strong alphanumeric value (Immich docs:
  `[A-Za-z0-9]` only, no special chars), encrypt into
  `host_vars/helium/secrets.sops.yml`. Never echo to stdout. (This is the **only**
  secret — current Immich has no `JWT_SECRET`.)
- **Phone-app auth + first upload (the AC):** with the NetBird client up on the
  phone, add the instance `https://immich.home.stromdahl.tech`, log in, enable
  auto-backup, and confirm a photo lands in `/data/ssd/immich/library`.
- **Initial bulk ML index:** face detection + CLIP smart-search across the imported
  library runs on the CPU — **first run is slow** (hours, library-size dependent).
  The AC ("initial bulk index finishes, incrementals keep up") is confirmed by
  observation over time, not in a deploy run.

## Decisions baked in (read before coding)

- **Immich is NOT on neon** — `servers/neon/docker-compose.yml` has none. Prior art
  is the **official `immich-app/immich` release compose** (4 services: `immich-server`,
  `immich-machine-learning`, `redis`, `database`, plus a `model-cache` named volume).
  **Pin a version** (`IMMICH_VERSION`, e.g. the current `v2.7.5`) per the repo's
  reproducibility convention rather than tracking `release`.
- **CPU-only ML — the knob is "do nothing special."** Use the plain
  `ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION}` image (NOT a
  `-cuda`/`-openvino` variant) and **do not add the `extends: hwaccel.ml.yml` block**
  — the default (no extends) is CPU inference. Leave that `# extends:` commented.
- **The Postgres image is special — don't substitute vanilla postgres.** Immich
  requires its `ghcr.io/immich-app/postgres:...` image (bundles VectorChord/pgvecto
  for embeddings). Redis is `valkey`. Use the exact images from the pinned release.
- **Library AND Postgres both on the `immich` precious subvol** (`/data/ssd/immich`,
  CoW + checksums) — `UPLOAD_LOCATION` → `/data/ssd/immich/library`,
  `DB_DATA_LOCATION` → `/data/ssd/immich/postgres`. This is deliberate (small library;
  checksums > write-amplification). **Do not "helpfully" move Postgres to the
  nodatacow scratch tier.**

## Entry points (create — grep-stable)

- **Add the Immich service group** to the compose-stack `tasks/005` establishes —
  mirror its per-service block + Traefik-label idiom (grep the role/templates 005
  created; don't invent a parallel mechanism).
- **Traefik router** (server only; ML/redis/db stay internal):
  `Host(`immich.home.stromdahl.tech`)`, `entrypoints=websecure`,
  `tls.certresolver=letsencrypt`, `loadbalancer.server.port=2283`, reuse 005's
  security-headers middleware.
- **Plain vars** → `ansible/host_vars/helium/vars.yml` (grep the compose-stack vars
  block 005 added):
  ```yaml
  immich_version: "v2.7.5"
  immich_upload_location: /data/ssd/immich/library
  immich_db_location: /data/ssd/immich/postgres
  ```
- **Secret** → `ansible/host_vars/helium/secrets.sops.yml` (encrypted): `DB_PASSWORD`.
- Create `/data/ssd/immich/{library,postgres}` (`ansible.builtin.file`) and `chown`
  to the container UID/GID before first start.

## Prior art to mirror

- `tasks/005-media-stack-traefik-netbird.md` + the `compose_stack` role it builds —
  **load-bearing**: the role, sops→`.env` templating, the Traefik LE DNS-01
  resolver, the NetBird mesh. Immich plugs into all of it.
- The official Immich release `docker-compose.yml` + `example.env` — the canonical
  service set, image tags, `UPLOAD_LOCATION`/`DB_DATA_LOCATION`/`DB_PASSWORD` env.
- `servers/neon/docker-compose.yml` — the Traefik v3 router-label idiom (grep
  `traefik.http.routers`).
- `tasks/011-data-tier-btrfs-raid1.md` — confirms `/data/ssd/immich` is the
  precious-subvol mount.

## Steps

0. **Don't start until 005 + 011 are `done`.**
1. Create + `chown` `/data/ssd/immich/{library,postgres}` to the container UID/GID.
2. Add the 4-service Immich group to 005's compose template (plain CPU ML image, no
   hwaccel extends; the special Postgres + valkey images; `model-cache` volume);
   wire env from vars + the `DB_PASSWORD` sops secret; point upload/DB at the subvol.
3. Add the Traefik router (server only) for `immich.home.stromdahl.tech`.
4. Deploy via the compose-stack role; re-run for idempotence.

## Verify

- **idempotent:** second `ansible-playbook site.yml --tags compose,services` →
  `changed=0`.
- **reachable over mesh, valid cert, not public (human):**
  `curl -v https://immich.home.stromdahl.tech/api/server/ping` from a mesh peer →
  real LE cert, `{"res":"pong"}`; not reachable publicly.
- **ML on CPU:** `docker logs <ml-container>` shows model load + inference with **no**
  CUDA/GPU references.
- **on SSD precious subvol:** `ansible nas -b -m shell -a 'findmnt -T /data/ssd/immich; ls -ld /data/ssd/immich/{library,postgres}'` → on `/data/ssd`, owned by the container UID/GID.
- **upload + index (human, over time):** a phone-app upload appears in the library;
  faces/CLIP jobs complete; the initial bulk index finishes and incrementals keep up.

## Acceptance criteria (from issue 006, verbatim)

- [ ] Immich is reachable at `immich.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly.
- [ ] Photo/video upload from the phone app succeeds over the mesh.
- [ ] Machine-learning jobs (faces, smart-search) run on the CPU and complete; the
      initial bulk index finishes and incrementals keep up.
- [ ] Immich library and Postgres data reside on the data-tier SSD mirror.
- [ ] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets.

## Out of scope / don't touch

- Backups of the library/DB — deferred (future backup work).
- Any GPU/CUDA ML path — the RTX 2060 is gone; CPU ML is the constraint.
- Non-root/cap hardening — `issues/010`.
- 005's Traefik/NetBird/compose plumbing — reuse, don't re-derive.
- Don't move Immich's Postgres off the precious subvol onto scratch.
