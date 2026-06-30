# Task 005 — Jellyfin over the mesh (internal Traefik + NetBird + compose-stack role)

**Source issue:** `issues/005-media-stack-traefik-netbird.md` — stand **Jellyfin**
up on helium, **privately only** ("watch my library again, over the mesh"). This is
the **keystone slice**: it builds the reusable **compose-stack Ansible role**,
**internal Traefik** (real certs via **Let's Encrypt DNS-01 / Cloudflare**, no
inbound exposure), the **NetBird** mesh client, and the **Docker-bypasses-ufw**
plumbing — then runs Jellyfin on top. Download automation (gluetun/qBittorrent/
*arr/Jellyseerr) is **`issues/014`**; this slice is deliberately Jellyfin + plumbing.

> **Depends on `issues/003` (HDD media pool) and `issues/011` (SSD data tier) —
> both built + deployed, awaiting only their `needs-human` resilience sign-offs —
> plus `issues/002` (done).** The pool mount `/srv/media` and the SSD tier `/data/ssd/*`
> are **already live**, so first-playback is not gated on the reboot/drive-loss
> checks; it's gated on the two **secrets** (NetBird key + Cloudflare token).

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/005` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: the NetBird setup key + Cloudflare token are secrets the
agent can't mint, mesh approval is a dashboard action, and the LAN-exposure + iGPU
transcode ACs need verification from other devices.

## Suggested agent

**Sonnet** to build the role — it's largely a mechanical translation of the
Jellyfin + Traefik + NetBird parts of `servers/neon/docker-compose.yml` into a
compose-stack Ansible role with helium's mount paths. **Escalate to Opus only if**
the Docker/ufw `DOCKER-USER` interaction or the NetBird-interface port binding
fights back — that integration is the one genuinely fiddly part.

## Human steps / blockers (`needs-human`)

- **NetBird setup key** — mint in the NetBird dashboard (free personal tier, cloud
  control plane). Add to `host_vars/helium/secrets.sops.yml`; the agent can't make it.
- **Cloudflare API token** — already exists (encrypted in `servers/neon/secrets.env`
  as `CF_DNS_API_TOKEN`). User confirms it's valid / scoped for `home.stromdahl.tech`
  and places it in helium's sops secrets.
- **Mesh approval** — approve the helium peer in the dashboard if required.
- **LAN-exposure AC** — verify from *another LAN host* that no published port is
  reachable on helium's LAN IP (Docker-bypasses-ufw check). Manual, off-box.
- **iGPU transcode AC** — confirm QuickSync in the Jellyfin UI during a real stream.

## Decisions baked in (read before coding)

- **Copy neon's working config, narrowed to Jellyfin.** `servers/neon/docker-compose.yml`
  is the concrete prior art: Traefik `v3.6.11` already does
  `--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare`
  (grep `dnschallenge`); Jellyfin already passes `/dev/dri`. The deltas for helium:
  (a) Traefik points at `*.home.stromdahl.tech`, (b) **no inbound exposure / no
  port-forward**, (c) mounts → helium's tiers, (d) deploy via Ansible.
- **No gluetun container in this slice.** In neon's compose, Jellyfin sits on a
  network *named* `gluetun_network`, but it's a **plain bridge member** — only
  `network_mode: service:gluetun` services (qBittorrent/prowlarr/flaresolverr, all
  `issues/014`) route through the VPN. Put Jellyfin + Traefik on a normal bridge
  (rename it, e.g. `media`); **do not pull in the gluetun container** or you smuggle
  a false dependency into the Jellyfin milestone.
- **`community.docker` is NOT in the pinned collections** (`ansible/requirements.yml`
  pins only `community.sops`, `community.general`, `ansible.posix`, role
  `geerlingguy.docker`). Deploy with **`ansible.builtin.command: docker compose up
  -d`** (mirror neon's `deploy.sh`), or pin `community.docker` + use `docker_compose_v2`
  (if you add it, pin a version — the repo's reproducibility convention).
- **Secrets via sops, never to disk plaintext / never to stdout.** Mirror
  `servers/neon/deploy.sh` (`sops --decrypt --output-type dotenv` → `600` temp →
  `--env-file`). Ansible-native: add stack secrets to `host_vars/helium/secrets.sops.yml`
  (auto-decrypted by the `community.sops` vars plugin — see `ansible.cfg`
  `vars_plugins_enabled`, same path that loads `ansible_become_password`), then
  `ansible.builtin.template` a `mode: 0600` `.env`. `.sops.yaml` already matches
  `ansible/host_vars/**.sops.yml`.
- **Docker bypasses ufw — close it here (reusable plumbing).** `roles/base/tasks/ufw.yml`
  default-denies but Docker inserts rules *ahead* of ufw. Fix (issue AC #3):
  **(recommended, reusable)** a `DOCKER-USER` default-deny chain so only mesh/loopback
  reaches published ports; **or** bind Traefik's `80/443` to `127.0.0.1` + the NetBird
  interface IP only. Traefik is the only service publishing ports in this slice.
- **iGPU/QuickSync:** keep `devices: [/dev/dri:/dev/dri]` on Jellyfin and ensure the
  container user (`PUID/PGID` from neon's `config.env`, 1001:1003) can reach the
  render device — `group_add: [<render_gid>]` (read `getent group render` on helium).

## Entry points (create — grep-stable)

New role **`ansible/roles/compose_stack/`** (first compose-deploy role; mirror
`roles/base` layout):
```
ansible/roles/compose_stack/
  meta/main.yml            # galaxy_info — copy shape from roles/base/meta/main.yml
  tasks/main.yml           # import chain (mirror roles/base/tasks/main.yml)
  tasks/stack.yml          # template .env from sops, then `docker compose up -d`
  tasks/firewall.yml       # DOCKER-USER default-deny (or loopback/mesh port binding)
  tasks/netbird.yml        # install + join NetBird client (setup key from sops)
  templates/docker-compose.yml.j2   # Jellyfin + Traefik (from servers/neon/, narrowed)
  templates/stack.env.j2   # sops-sourced secrets → 0600 .env
  files/traefik/           # mirror servers/neon/ traefik dynamic config (grep `dynamic.yml`)
```
- **Wire into `ansible/site.yml`** after `geerlingguy.docker` (grep `tags: [docker]`):
  ```yaml
      - role: compose_stack
        tags: [compose, services]
  ```
- **Add vars** to `ansible/host_vars/helium/vars.yml` (grep `ssd_subvolumes_scratch`,
  append after): stack dir (e.g. `/opt/helium`), the `home.stromdahl.tech` domain,
  ACME email, `render_gid`.
- **Add secrets** to `ansible/host_vars/helium/secrets.sops.yml` (encrypted):
  Cloudflare token, NetBird setup key, Traefik dashboard auth.

## Storage mount anchors (grep-stable — from 003/011)

Grep `ansible/host_vars/helium/vars.yml`:
- **Media library (Jellyfin read):** `hdd_union_mount` → `/srv/media` — mount **`:ro`**.
- **Transcode cache:** `ssd_subvolumes_scratch` → `/data/ssd/transcode` (nodatacow).
- **Jellyfin config (`/config`):** `ssd_subvolumes_precious` → `/data/ssd/appdata`.

## Prior art to mirror

- `servers/neon/docker-compose.yml` — the **Jellyfin + Traefik blocks to translate**
  (grep `jellyfin:`, `traefik:`, `dnschallenge`, `/dev/dri`). Leave the gluetun/*arr
  blocks for `tasks/014`.
- `servers/neon/deploy.sh` — the sops-dotenv decrypt → `--env-file` deploy idiom.
- `servers/neon/` traefik dynamic config (grep `dynamic.yml`) — TLS middleware reuse.
- `ansible/roles/base/{meta,tasks}/main.yml` — role layout + import-chain idiom.
- How `ansible_become_password` is consumed from `secrets.sops.yml` — the sops
  vars-plugin pattern to copy for stack secrets.

## Steps

1. Scaffold `roles/compose_stack/` (meta + import chain), wire into `site.yml`.
2. `templates/docker-compose.yml.j2` — Jellyfin + Traefik only: keep `/dev/dri` +
   the DNS-01 resolver; repoint domain to `*.home.stromdahl.tech`; Jellyfin on a
   plain bridge (no gluetun); volumes `/srv/media:ro`, `/data/ssd/transcode`,
   `/data/ssd/appdata/jellyfin`; **no public port exposure**.
3. `templates/stack.env.j2` + secrets in `secrets.sops.yml` → render `0600 .env`.
4. `tasks/firewall.yml` — DOCKER-USER default-deny (or loopback/mesh bind on Traefik).
5. `tasks/netbird.yml` — install NetBird, join with the sops setup key, confirm
   `jellyfin.home.stromdahl.tech` resolves to the mesh IP.
6. `tasks/stack.yml` — `docker compose up -d`; render-group handling for Jellyfin.
7. Run `cd ansible && ansible-playbook site.yml --tags compose,services`; re-run for
   idempotence (`changed=0`).

## Verify

No linter/test runner (`AGENTS.md`) — verify by re-run + observation. Group `nas`.

- **idempotent:** second run → `changed=0`; `--check` clean.
- **services up:** `ansible nas -b -m shell -a 'docker compose -f /opt/helium/docker-compose.yml ps'` → Jellyfin + Traefik healthy.
- **valid cert over mesh (human, mesh peer):** `curl -v https://jellyfin.home.stromdahl.tech/` → real LE cert, 200/redirect.
- **not on LAN (human, other LAN host):** hitting helium's LAN IP on the published
  port times out / refused.
- **iGPU (human, UI):** a transcoded stream shows QuickSync active in Jellyfin's
  playback dashboard.
- **mounts correct:** `docker inspect jellyfin` → `/media` is `:ro` from `/srv/media`;
  `/config` on `/data/ssd/appdata`; transcode on `/data/ssd/transcode`.

## Acceptance criteria (from issue 005, verbatim)

- [ ] Jellyfin is reachable at `jellyfin.home.stromdahl.tech` **over the NetBird
      mesh** with a valid (non-self-signed) TLS certificate.
- [ ] Nothing is reachable from the public internet; no router port-forward exists.
- [ ] No container-published port is exposed on the **LAN** by Docker bypassing
      ufw — published ports bind to loopback / the NetBird interface (or
      `DOCKER-USER` rules reinstate the default-deny), verified from another LAN host.
- [ ] Jellyfin transcodes using the iGPU (QuickSync).
- [ ] Jellyfin reads the library from the HDD pool mount; its config (appdata) and
      transcode cache live on the SSD tier.
- [ ] The stack is brought up by the Ansible compose-stack role from krypton, with
      secrets sourced from sops.

## Out of scope / don't touch

- gluetun / qBittorrent / *arr / Jellyseerr — `issues/014` (reuses this role's
  Traefik+NetBird+compose plumbing).
- Migrating the real library — `issues/008` (this stands Jellyfin up with fresh
  config; the rsync feeds it).
- Immich (`006`) / Paperless (`007`); per-service non-root hardening (`010`).
- The storage roles (`003`/`011`) — consume their mounts, don't modify them.
