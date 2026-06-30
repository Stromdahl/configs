# Task 005 — Media stack over the mesh (Jellyfin + *arr + gluetun, internal Traefik + NetBird)

**Source issue:** `issues/005-media-stack-traefik-netbird.md` — bring neon's media
stack up on helium, **privately only**. This is the **keystone services slice**: it
establishes the reusable **compose-stack Ansible role**, **internal Traefik** (real
certs via **Let's Encrypt DNS-01 / Cloudflare**, no inbound exposure), the
**NetBird** mesh client, **gluetun** VPN egress, and the **Docker-bypasses-ufw**
plumbing every later service (006/007/010) reuses.

> **Depends on `issues/003` (HDD media pool) and `issues/011` (SSD data tier) — both
> still `in-progress` — plus `issues/002` (done).** The stack mounts those tiers
> (`/srv/media`, `/data/ssd/*`). **Do not grab until 003 and 011 are `done`.**

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/005` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop — issue stays in-progress.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

This issue carries **`needs-human`**: the NetBird setup key + Cloudflare token are
secrets the agent can't mint, mesh approval is a dashboard action, and the
"not reachable on LAN / iGPU transcode" ACs need verification from other devices.
Build the role, then hand those checks to the user.

## Suggested agent

**Sonnet** to build the role — it's largely a mechanical translation of the
concrete `servers/neon/docker-compose.yml` into a compose-stack Ansible role with
helium's mount paths. **Escalate to Opus only if** the Docker/ufw `DOCKER-USER`
interaction or the NetBird-interface port binding fights back — that integration
is the one genuinely fiddly part.

## Human steps / blockers (`needs-human`)

- **NetBird setup key** — mint in the NetBird dashboard (free personal tier, cloud
  control plane — *not* self-hosted). Add to `host_vars/helium/secrets.sops.yml` as
  an encrypted var; the agent cannot generate it.
- **Cloudflare API token** — the DNS-01 token already exists (encrypted in
  `servers/neon/secrets.env` as `CF_DNS_API_TOKEN`). User confirms it's still valid
  / re-scopes for `home.stromdahl.tech` and places it in helium's sops secrets.
- **Mesh approval** — after the NetBird client registers, approve the peer in the
  dashboard if required.
- **LAN-exposure AC** — verify from *another LAN host* that no published port is
  reachable on helium's LAN IP (Docker-bypasses-ufw check). Manual, off-box.
- **iGPU transcode AC** — confirm QuickSync in the Jellyfin UI during a real stream.

## Decisions baked in (read before coding)

- **neon already does the hard parts — copy them.** `servers/neon/docker-compose.yml`
  is the concrete prior art: Traefik `v3.6.11` already uses
  `--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare`
  (grep `dnschallenge`), gluetun `v3.41.1` (Mullvad/WireGuard) already fronts
  qBittorrent/prowlarr/flaresolverr via **`network_mode: service:gluetun`**, and
  Jellyfin already passes `/dev/dri`. The **only** deltas for helium: (a) point
  Traefik at `*.home.stromdahl.tech` instead of the public domain, (b) **no
  inbound exposure / no port-forward**, (c) mounts → helium's tiers, (d)
  deploy via Ansible, not `deploy.sh`.
- **`community.docker` is NOT in the pinned collections** (`ansible/requirements.yml`
  pins only `community.sops`, `community.general`, `ansible.posix`, role
  `geerlingguy.docker`). So deploy with **`ansible.builtin.command: docker compose
  up -d`** (mirror neon's `deploy.sh` flow), *or* pin `community.docker` +
  `docker_compose_v2` if you prefer the module — if you add it, pin a version in
  `requirements.yml` (the repo's reproducibility convention).
- **Secrets via sops, never to disk plaintext / never to stdout.** Mirror
  `servers/neon/deploy.sh`: it `sops --decrypt --output-type dotenv` → a `600` temp
  → `docker compose --env-file`. The Ansible-native equivalent: add the stack
  secrets (Cloudflare token, WireGuard key/addresses, Traefik dashboard htpasswd,
  NetBird setup key) to `host_vars/helium/secrets.sops.yml` (auto-decrypted by the
  `community.sops` vars plugin — see `ansible.cfg` `vars_plugins_enabled`, same
  mechanism that loads `ansible_become_password`), then `ansible.builtin.template`
  a `mode: 0600` `.env`. `.sops.yaml` already matches `ansible/host_vars/**.sops.yml`
  — no change needed.
- **Docker bypasses ufw — close it here (reusable plumbing).** `roles/base/tasks/ufw.yml`
  sets default-deny + allows 22/80/443, but Docker inserts its rules *ahead* of ufw,
  so any published port is LAN-reachable regardless. Two acceptable fixes (issue AC
  #3): **(recommended, reusable)** add a `DOCKER-USER` default-deny chain (drop a
  persisted rule so only the mesh/loopback can reach published ports) — this is the
  "plumbing every later service reuses"; **or** bind Traefik's `80/443` to
  `127.0.0.1` + the NetBird interface IP only. Traefik is the *only* service that
  publishes ports (everything else is internal or `network_mode: service:gluetun`),
  so scope the fix to it.
- **iGPU/QuickSync:** keep `devices: [/dev/dri:/dev/dri]` on Jellyfin and ensure the
  container user (`PUID/PGID` from neon's `config.env`, 1001:1003) can reach the
  render device — add it to the host `render` group (`ansible.builtin.user` +
  `append`) or `group_add: [render]` in the compose service.

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
  templates/docker-compose.yml.j2   # adapted from servers/neon/docker-compose.yml
  templates/stack.env.j2   # sops-sourced secrets → 0600 .env
  files/traefik/           # mirror servers/neon/ traefik dynamic config (grep `dynamic.yml`)
```
- **Wire into `ansible/site.yml`** after `geerlingguy.docker` (grep `tags: [docker]`):
  ```yaml
      - role: compose_stack
        tags: [compose, services]
  ```
- **Add vars** to `ansible/host_vars/helium/vars.yml` (grep `ssd_subvolumes_scratch`
  to find the storage block; append after): stack dir (e.g. `/opt/helium`), the
  `home.stromdahl.tech` domain, ACME email, the volume path map.
- **Add secrets** to `ansible/host_vars/helium/secrets.sops.yml` (encrypted):
  Cloudflare token, WireGuard private key + addresses, NetBird setup key, Traefik
  dashboard auth.

## Storage mount anchors (grep-stable — from 003/011)

Grep `ansible/host_vars/helium/vars.yml`:
- **Media library (Jellyfin/*arr read):** `hdd_union_mount` → `/srv/media` (003's
  mergerfs union). Mount **`:ro`** into Jellyfin.
- **Downloads + transcode cache:** `ssd_subvolumes_scratch` → `/data/ssd/downloads`,
  `/data/ssd/transcode` (nodatacow scratch).
- **Container appdata (`/config` volumes):** `ssd_subvolumes_precious` →
  `/data/ssd/appdata` (CoW + checksums).

## Prior art to mirror

- `servers/neon/docker-compose.yml` — the **stack to translate** (services, images,
  gluetun `network_mode`, Traefik labels/resolver, `/dev/dri`). Don't lose the
  `network_mode: service:gluetun` on qBittorrent/prowlarr/flaresolverr.
- `servers/neon/deploy.sh` — the sops-dotenv decrypt → `--env-file` deploy idiom.
- `servers/neon/` traefik dynamic config (grep `dynamic.yml`) — TLS middleware reuse.
- `ansible/roles/base/{meta,tasks}/main.yml` — role layout + import-chain idiom.
- `ansible/roles/storage_hdd/tasks/timers.yml` — copy/notify/systemd idioms if a
  helper unit is needed.
- How `ansible_become_password` is consumed from `secrets.sops.yml` — the sops
  vars-plugin pattern to copy for stack secrets.

## Steps

0. **Don't start until 003 + 011 are `done`** (the mounts must exist).
1. Scaffold `roles/compose_stack/` (meta + import chain), wire into `site.yml`.
2. `templates/docker-compose.yml.j2` — port neon's compose: keep gluetun routing,
   `/dev/dri`, Traefik DNS-01 resolver; repoint domain to `*.home.stromdahl.tech`;
   remap volumes to `/srv/media:ro`, `/data/ssd/{downloads,transcode}`,
   `/data/ssd/appdata/<svc>`; **remove public port-forward exposure**.
3. `templates/stack.env.j2` + secrets in `secrets.sops.yml` → render `0600 .env`.
4. `tasks/firewall.yml` — DOCKER-USER default-deny (or loopback/mesh bind on Traefik).
5. `tasks/netbird.yml` — install the NetBird client, join with the sops setup key,
   confirm service hostnames resolve to the mesh IP.
6. `tasks/stack.yml` — `docker compose up -d` from the rendered files; render-group
   handling for Jellyfin.
7. Run `cd ansible && ansible-playbook site.yml --tags compose,services` from
   krypton; re-run to prove idempotence (`changed=0`).

## Verify

No linter/test runner (per `AGENTS.md`) — verify by re-run + observation. Inventory
group is `nas` (helium).

- **idempotent:** second `ansible-playbook site.yml --tags compose,services` →
  `changed=0`; a `--check` run is clean.
- **services up:** `ansible nas -b -m shell -a 'docker compose -f /opt/helium/docker-compose.yml ps'` → all healthy.
- **valid cert over mesh (human, from a mesh peer):** `curl -v https://jellyfin.home.stromdahl.tech/` → real LE cert, HTTP 200/redirect.
- **not on LAN (human, other LAN host):** hitting helium's LAN IP on the published
  port times out / refused (DOCKER-USER / bind working).
- **gluetun kill-switch:** `docker exec gluetun wget -qO- ifconfig.me` shows the VPN
  egress IP; qBittorrent's external IP matches gluetun's, and stopping gluetun kills
  qBittorrent connectivity.
- **Jellyfin iGPU (human, UI):** a transcoded stream shows QuickSync active in the
  Jellyfin playback dashboard.

## Acceptance criteria (from issue 005, verbatim)

- [ ] Each service is reachable at its `*.home.stromdahl.tech` URL **over the
      NetBird mesh** with a valid (non-self-signed) TLS certificate.
- [ ] Nothing is reachable from the public internet; no router port-forward exists.
- [ ] No container-published port is exposed on the **LAN** by Docker bypassing
      ufw — published ports bind to loopback / the NetBird interface (or
      `DOCKER-USER` rules reinstate the default-deny), verified from another LAN host.
- [ ] gluetun reports the VPN egress IP, and qBittorrent's traffic egresses through
      it (kill-switch verified).
- [ ] Jellyfin transcodes using the iGPU (QuickSync).
- [ ] The stack is brought up by the Ansible compose-stack role from krypton, with
      secrets sourced from sops.

## Out of scope / don't touch

- Migrating real library data + *arr state — that's `issues/008`. Stand the stack
  up with **fresh** config here.
- Immich (`006`) / Paperless (`007`) service definitions — later, reusing this
  role's Traefik+NetBird+compose plumbing.
- Per-service non-root/cap hardening — `issues/010` (post-bring-up, against this
  known-working baseline).
- The storage roles (`003`/`011`) — consume their mounts, don't modify them.
