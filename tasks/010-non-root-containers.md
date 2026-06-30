# Task 010 — Run service containers as non-root where the image supports it

**Source issue:** `issues/010-non-root-containers.md` — make non-root the
deliberate, audited default across the whole compose stack, drop unnecessary
capabilities + privileged flags, and make read-only bind mounts where a service
only reads. Per-service hardening only — **explicitly NOT** host-wide
`userns-remap` (it breaks Jellyfin's `/dev/dri` and gluetun's net caps).

> **Depends on the service stack being up: `issues/005` (Jellyfin), `issues/014`
> (download automation — gluetun/qBittorrent/*arr/Jellyseerr), `issues/006`
> (Immich), `issues/007` (Paperless).** This is post-bring-up hardening against a
> known-working baseline. **Do not grab until 005 (at least) is `done`;** harden the
> 014/006/007 services as those land. The frontmatter omits a `Depends on` line, but
> the issue body is explicit — treat 005/014/006/007 as prerequisites.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/010` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** before committing — both the structural `docker inspect` checks *and*
   that every service still functions. Only then commit (atomic). If hardening
   breaks a service you can't fix in scope, revert that service's change, report,
   stop.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: the functional re-test (Jellyfin iGPU transcode,
gluetun tunnel, *arr read/write, Immich ML, Paperless OCR) is observational and
needs a human, and the host `render` GID must be read off helium.

## Suggested agent

**Sonnet** — a mechanical per-service edit pass guided by the matrix below; the
images and their non-root posture are already known. The judgment is "don't break
the three load-bearing exceptions," not hard reasoning.

## Human steps / blockers (`needs-human`)

- **Discover the host `render` GID** on helium (`getent group render | cut -d: -f3`,
  typically 104–107 on Debian) and set it as a var — Jellyfin's non-root user must
  be `group_add`'d to it for iGPU access.
- **Functional re-test after hardening** (observational, can't be scripted): Jellyfin
  transcodes on the iGPU; gluetun tunnel up + qBittorrent egresses through it; *arr
  read/write their volumes; Immich ingests + ML runs; Paperless OCRs an ingest.
- **Upstream non-root confirmation** for three third-party images whose support is
  unconfirmed — `flaresolverr`, `jellyseerr`, `tecnativa/docker-socket-proxy`: if a
  given image genuinely needs root, **document that exception** rather than forcing it.

## Decisions baked in (read before coding)

- **Three load-bearing exceptions — do not "harden" these into breakage:**
  - **gluetun** must keep `cap_add: [NET_ADMIN]` + `devices: [/dev/net/tun]` — the
    VPN can't work without them. Add `cap_drop: [ALL]` + `no-new-privileges` around
    them, but NET_ADMIN stays.
  - **jellyfin** runs non-root via `PUID/PGID` but must be `group_add`'d to the host
    `render` GID and keep `devices: [/dev/dri:/dev/dri]` for QuickSync.
  - **official postgres / redis** (Immich/Paperless) already run non-root (uid 999)
    by default — **do not add a `user:` override**; just add `cap_drop: [ALL]` +
    `no-new-privileges`.
- **linuxserver / *arr images are already PUID/PGID-remapped** — no `user:` field
  needed; just layer `cap_drop: [ALL]` + `security_opt: [no-new-privileges:true]`.
- **`network_mode: service:gluetun` services** (qBittorrent, prowlarr, flaresolverr)
  inherit gluetun's network/caps — don't add caps to them; they harden as normal
  non-root apps.
- **Read-only where read-only:** media library mounts → `:ro` (Jellyfin `/media`,
  *arr `/data/media`); `/config` + state volumes stay writable; bind-mounted
  configs (e.g. Traefik `dynamic.yml`) already `:ro`, keep it.
- **`userns-remap` stays OFF** — confirm `/etc/docker/daemon.json` has none.

## Per-service hardening matrix (the core deliverable — grep service name)

Grep each `<service>:` block in the helium compose (the file `tasks/005`
establishes; mirror it for 006/007). Apply:

| Service | User posture | caps | mounts |
|---|---|---|---|
| traefik | `user: "65534:65534"` | `cap_drop:[ALL]` + nnp | certs rw, `dynamic.yml:ro` |
| jellyfin | PUID/PGID + `group_add:[<render_gid>]`, keep `/dev/dri` | `cap_drop:[ALL]` + nnp | `/media:ro`, `/config` rw |
| gluetun | (root) | `cap_drop:[ALL]` + `cap_add:[NET_ADMIN]` + `/dev/net/tun` + nnp | — |
| qbittorrent | PUID/PGID | `cap_drop:[ALL]` + nnp | `/downloads` rw, `/data/media:ro` |
| radarr/sonarr/bazarr/prowlarr/profilarr | PUID/PGID | `cap_drop:[ALL]` + nnp | `/config` rw, `/data/media:ro` (bazarr/radarr/sonarr) |
| jellyseerr | verify non-root upstream | `cap_drop:[ALL]` + nnp | `/app/config` rw |
| flaresolverr | verify non-root upstream | `cap_drop:[ALL]` + nnp | — |
| docker-socket-proxy | verify non-root upstream | `cap_drop:[ALL]` + nnp | `docker.sock:ro` |
| homer | already `user: ${UID}:${GID}` | `cap_drop:[ALL]` + nnp | `config.yml:ro` |
| postgres / redis (006/007) | **leave default uid 999** | `cap_drop:[ALL]` + nnp | data vol rw |
| immich-server / -machine-learning (006) | per image | `cap_drop:[ALL]` + nnp | library rw |
| paperless / gotenberg / tika (007) | `USERMAP_UID/GID` (paperless) | `cap_drop:[ALL]` + nnp | data/consume rw |

`nnp` = `security_opt: [no-new-privileges:true]`.

## Entry points (edit — grep-stable)

- The helium compose template(s) created by `tasks/005` (Jellyfin/Traefik) and
  extended by `tasks/014` (gluetun/qBittorrent/*arr/Jellyseerr), plus the
  Immich/Paperless definitions from `tasks/006`/`tasks/007` — grep each `<service>:`
  block by name and add the keys above. **This is an edit-each-service pass, not a
  new role.**
- Add **`render_gid: <gid>`** to `ansible/host_vars/helium/vars.yml` (grep the
  compose-stack vars block 005 added) and template it into Jellyfin's `group_add`.

## Prior art to mirror

- `servers/neon/docker-compose.yml` — shows which services already set PUID/PGID,
  which set `user:`/`group_add`, and gluetun's existing `NET_ADMIN`/`/dev/net/tun`
  + Jellyfin's `/dev/dri` (grep `gluetun:`, `jellyfin:`, `cap_add`, `devices`).
- `tasks/005`'s compose template — the per-service block shape to extend.

## Steps

0. **Don't start until 005 is `done`** (006/007 too, to harden those services).
1. Read the host `render` GID off helium; add `render_gid` var.
2. For each service block, apply the matrix (cap_drop/nnp everywhere; user/group as
   noted; `:ro` on read-only mounts). Preserve the three exceptions exactly.
3. For `flaresolverr` / `jellyseerr` / `docker-socket-proxy`, confirm non-root works;
   if an image needs root, document it inline + in the issue close note.
4. Re-deploy via the compose-stack role; re-run for idempotence.

## Verify

- **non-root:** `docker exec <svc> id` → non-zero uid for every service except
  documented exceptions.
- **caps + nnp:** `docker inspect <svc> | jq '.HostConfig.CapAdd, .HostConfig.SecurityOpt'`
  → `CapAdd` is `null`/`[]` everywhere except gluetun (`["NET_ADMIN"]`); `SecurityOpt`
  contains `no-new-privileges`.
- **read-only mounts:** `docker inspect jellyfin | jq '.Mounts[]|select(.Destination=="/media")|.RW'` → `false`.
- **no userns-remap:** `grep -q userns-remap /etc/docker/daemon.json && echo FOUND || echo OK` → `OK`.
- **still functional (human):** Jellyfin iGPU transcode; gluetun tunnel +
  qBittorrent egress; *arr volume read/write; Immich ML; Paperless OCR.

## Acceptance criteria (from issue 010, verbatim)

- [ ] Every service in the compose stack runs as a non-root user, or its need for
      root is explicitly documented (e.g. a sidecar that legitimately requires it).
- [ ] Containers that don't need extra Linux capabilities run with them dropped and
      `no-new-privileges` set.
- [ ] Bind mounts are read-only wherever the service only reads (e.g. media for
      Jellyfin), and writable mounts are scoped to the minimum path.
- [ ] All services still function after hardening: Jellyfin transcodes on the iGPU,
      gluetun's tunnel is up, the *arr stack reads/writes its volumes, Immich and
      Paperless ingest normally.
- [ ] No use of host-wide `userns-remap` (the per-service approach is preserved).

## Out of scope / don't touch

- Building the stacks (`005`/`014`/`006`/`007`) — this only hardens their existing
  service definitions.
- Host-wide `userns-remap` — explicitly excluded.
- gluetun's `NET_ADMIN`/`/dev/net/tun` and Jellyfin's `/dev/dri` — required, not
  "unnecessary privileges."
