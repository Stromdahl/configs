# Task 014 — Download automation (gluetun + qBittorrent + *arr + Jellyseerr)

**Source issue:** `issues/014-download-automation-gluetun-arr.md` — add the
download-automation half of the media stack on top of `issues/005`'s plumbing:
**gluetun** (VPN egress), **qBittorrent** behind it (kill-switch), the **\*arr
stack** (radarr/sonarr/prowlarr/bazarr/profilarr), and **Jellyseerr** — all behind
the existing internal Traefik, mesh-only. Carved out of the original media-stack
issue so Jellyfin could ship first.

> **Depends on `issues/005`** (the `compose_stack` role + internal Traefik + NetBird
> mesh this all plugs into). **Do not grab until 005 is `done`** — this extends 005's
> compose stack; it does not rebuild the plumbing.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/014` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`**: the gluetun WireGuard credentials are secrets the agent
can't mint, and the kill-switch + per-service reachability checks need observation.

## Suggested agent

**Sonnet** — once 005's `compose_stack` role exists, this is adding the remaining
neon services (which are concrete in `servers/neon/docker-compose.yml`) into the
established role pattern. The one subtlety is the gluetun network/kill-switch wiring,
pinned below.

## Human steps / blockers (`needs-human`)

- **gluetun VPN secrets** — `WIREGUARD_PRIVATE_KEY` + `WIREGUARD_ADDRESSES` (Mullvad,
  per neon's `secrets.env`). Encrypt into `host_vars/helium/secrets.sops.yml`; never
  to stdout.
- **Kill-switch verification** — confirm qBittorrent egresses via the VPN IP and
  loses connectivity when gluetun stops (observational).
- **Mesh reachability** — confirm each `*.home.stromdahl.tech` resolves over the mesh.

## Decisions baked in (read before coding)

- **neon's compose is the concrete source — copy the blocks 005 left behind.** From
  `servers/neon/docker-compose.yml` (grep each service): **gluetun** `qmcgaw/gluetun:v3.41.1`
  (Mullvad/WireGuard), **qbittorrent** `lscr.io/linuxserver/qbittorrent:5.1.4`,
  **radarr** `6.1.1`, **sonarr** `4.0.17`, **bazarr** `1.5.6`, **prowlarr** `2.3.5`,
  **profilarr** `santiagosayshey/profilarr:v1.1.4`, **flaresolverr** `v3.4.6`,
  **jellyseerr** `fallenbagel/jellyseerr:2.7.3`. Pin these tags.
- **VPN routing — the load-bearing wiring, do not lose it.** **qBittorrent,
  prowlarr, and flaresolverr** use **`network_mode: "service:gluetun"`** (they share
  gluetun's network stack → egress via the VPN). gluetun needs `cap_add: [NET_ADMIN]`
  + `devices: [/dev/net/tun]`. The other *arr (radarr/sonarr/bazarr) + jellyseerr sit
  on the **plain bridge** alongside Traefik (the same network 005 created), reachable
  by Traefik but **not** routed through the VPN.
- **Traefik routers attach to each web service** (mirror 005's label idiom): radarr,
  sonarr, prowlarr, bazarr, profilarr, jellyseerr, and qBittorrent's WebUI — each at
  its `*.home.stromdahl.tech` host. Services behind gluetun expose their WebUI port
  **on the gluetun container** (neon publishes qBittorrent `8080`, prowlarr `9696`,
  flaresolverr `8191` via gluetun); Traefik targets those.
- **Storage placement (grep `host_vars/helium/vars.yml`):** *arr config (`/config`)
  → `ssd_subvolumes_precious` `appdata` (`/data/ssd/appdata/<app>`); downloads →
  `ssd_subvolumes_scratch` `downloads` (`/data/ssd/downloads`); media → `hdd_union_mount`
  `/srv/media` (`:ro` for bazarr; rw where *arr move/import).
- **No published port leaks on LAN** — 005's `DOCKER-USER` / loopback-bind fix
  already covers this; don't add raw `ports:` that bypass it.

## Entry points (extend — grep-stable)

- **Add these services** to the compose stack `tasks/005` established — extend its
  `templates/docker-compose.yml.j2` (grep the Jellyfin/Traefik blocks 005 wrote;
  add the gluetun + qBittorrent + *arr + jellyseerr blocks alongside).
- **Add the gluetun + per-app vars** to `host_vars/helium/vars.yml`; **secrets**
  (`WIREGUARD_*`) to `host_vars/helium/secrets.sops.yml`.
- Create `/data/ssd/appdata/<app>` + `/data/ssd/downloads` dirs; `chown` to the
  container UID/GID (1001:1003) before first start.

## Prior art to mirror

- `servers/neon/docker-compose.yml` — the exact gluetun/qBittorrent/*arr/jellyseerr
  blocks, the `network_mode: service:gluetun` wiring, gluetun's `NET_ADMIN`/`/dev/net/tun`,
  and the published-via-gluetun ports (grep `gluetun:`, `network_mode`, `cap_add`).
- `tasks/005-media-stack-traefik-netbird.md` + the `compose_stack` role it builds —
  the role, sops→`.env` templating, Traefik label idiom, mesh.
- `servers/neon/config.env` / `secrets.env` — the env/secret split + WireGuard vars.

## Steps

0. **Don't start until 005 is `done`.**
1. Add gluetun (NET_ADMIN + tun, WireGuard from sops) to 005's compose template.
2. Add qBittorrent + prowlarr + flaresolverr with `network_mode: service:gluetun`;
   publish their WebUI ports on the gluetun container.
3. Add radarr/sonarr/bazarr/profilarr + jellyseerr on the plain bridge; wire Traefik
   routers for each `*.home.stromdahl.tech`.
4. Point config → `/data/ssd/appdata/<app>`, downloads → `/data/ssd/downloads`,
   media → `/srv/media`; `chown` dirs.
5. Deploy via the compose-stack role; re-run for idempotence.

## Verify

- **idempotent:** second `ansible-playbook site.yml --tags compose,services` →
  `changed=0`.
- **kill-switch (human):** `docker exec gluetun wget -qO- ifconfig.me` shows the VPN
  IP; qBittorrent's external IP matches; stopping gluetun kills qBittorrent's net.
- **each service over mesh (human):** `curl -v https://radarr.home.stromdahl.tech/`
  (and sonarr/prowlarr/bazarr/profilarr/jellyseerr/qbittorrent) → real cert, reachable;
  nothing public; no LAN port leak (recheck from another LAN host).
- **storage:** `docker inspect` → config on `/data/ssd/appdata/*`, downloads on
  `/data/ssd/downloads`, media mount present.

## Acceptance criteria (from issue 014, verbatim)

- [ ] gluetun reports the VPN egress IP, and qBittorrent's traffic egresses through
      it (kill-switch verified: stopping gluetun kills qBittorrent connectivity).
- [ ] Each *arr service and Jellyseerr is reachable at its `*.home.stromdahl.tech`
      URL over the mesh with a valid cert; nothing is publicly reachable, and no
      published port leaks on the LAN (the `issues/005` Docker/ufw fix holds).
- [ ] The *arr stack reads the media pool and writes downloads to the SSD scratch
      tier; config (appdata) lives on the SSD precious tier.
- [ ] The services are brought up by the Ansible compose-stack role from krypton,
      with secrets sourced from sops.

## Out of scope / don't touch

- Jellyfin + the Traefik/NetBird/ufw plumbing — `issues/005` (reuse, don't rebuild).
- Migrating real *arr state + active downloads — `issues/015` (fresh config here).
- Per-service non-root hardening — `issues/010`.
- Don't break the `network_mode: service:gluetun` routing or drop gluetun's NET_ADMIN.
