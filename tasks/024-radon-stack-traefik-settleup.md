# Task 024 — Stand up the radon `edge_stack` — Traefik + Origin cert + settleup live

**Source issue:** `issues/024-radon-stack-traefik-settleup.md` — the keystone:
**settleup reachable by a stranger at `https://settleup.stromdahl.io`**, end-to-end
through Cloudflare. Deliver a new **`edge_stack`** Ansible role that mirrors helium's
`compose_stack` render-and-up pattern but **drops** the NetBird mesh join and the
DOCKER-USER LAN-drop firewall, and serves a **static Cloudflare Origin certificate**
via Traefik's file provider (no ACME). Then run settleup on it.

> **Depends on `issues/021`, `022` ✓, `023` ✓, `027` ✓.** Do **not** grab until
> `021` is `done` (the `stromdahl.io` zone is Active + SSL Full (strict)). The Origin
> cert + key are **already staged** in `ansible/host_vars/radon/secrets.sops.yml`
> (keys `cloudflare_origin_cert` + `cloudflare_origin_cert_key`, admin-key-only) —
> verify with `grep -aoE '^[a-z_]+:' ansible/host_vars/radon/secrets.sops.yml`.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/024` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors; **never commit a rendered `.env` or
   any decrypted secret** — see boundaries).
3. **Verify** before committing — deploy to radon, run the Verify block, and confirm a
   **second run reports `changed=0`**. Only then commit (atomic). If a check fails and
   you can't fix it in scope, leave it uncommitted, report, stop.
4. **Close:** `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`** — see blockers below.

## Suggested agent

**Sonnet** for the mechanical mirror-and-delete (copy `compose_stack`, strip the
helium-only pieces, swap in one service). **Escalate to Opus** for the Traefik **edge
config** — the file-provider Origin-cert store, the `rateLimit` middleware, and the
Cloudflare `forwardedHeaders.trustedIPs` real-client-IP trust — if it doesn't validate
on first deploy. That's the one part where a subtle mistake is security-relevant on a
public, no-auth box.

## Human steps / blockers (`needs-human`)

- **`issues/021` must be done** — zone Active, SSL/TLS **Full (strict)**. (Origin
  cert/key already staged in sops; no action there.)
- **Create the proxied DNS record** (Cloudflare dashboard/API — external account):
  an **A record `settleup.stromdahl.io` → `2.24.160.184`, orange-cloud (proxied)**.
  This hides radon's IP and puts Cloudflare's shield in front. Nothing serves until it
  exists.
- **Pick a pinned image tag.** `ghcr.io/stromdahl/settleup` publishes `:latest`,
  `:sha-*`, and `type=semver` on `v*` tags (issue 023). **Pin a specific tag — not
  `:latest`.** Prefer a semver `v*` if one is released; else the current `:sha-<commit>`.
  List tags via the GHCR API or `skopeo list-tags docker://ghcr.io/stromdahl/settleup`.
- **Fetch current Cloudflare IP ranges** for `trustedIPs` from
  `https://www.cloudflare.com/ips-v4` + `/ips-v6` (or `https://api.cloudflare.com/client/v4/ips`).
- **Phone test (observational):** an invite link / QR from the live app opens on a
  phone and uses the `https://settleup.stromdahl.io` base.

## Decisions baked in (read before coding)

- **Mirror `compose_stack`'s `tasks/stack.yml`** render-and-up, but the `edge_stack`
  `tasks/main.yml` **drops** three things from compose_stack's `tasks/main.yml`: the
  `jellyfin_render_gid`/`compose_lan_iface` **assert**, the **`netbird.yml`** import
  (mesh join), and the **`firewall.yml`** import (DOCKER-USER + `iptables-persistent`).
  **Do NOT install `iptables-persistent`** — it declares `Breaks: ufw` and would evict
  radon's ufw (see `issues/028`). Keep: dir creation, render `.env` + `docker-compose.yml`,
  copy the Traefik dynamic file, `docker compose up -d`.
- **TLS = static Origin cert via file provider, NO ACME.** In the Traefik service
  `command:` block (it lives in `docker-compose.yml.j2`, not a `traefik.yml`), **remove**
  the three `--certificatesresolvers.letsencrypt.acme.*` flags, the top-level
  `secrets: cf_dns_api_token` + the traefik `CF_DNS_API_TOKEN_FILE` env + `secrets:`
  ref, and the `traefik_certs:/letsencrypt` volume. **Change every router label
  `tls.certresolver=letsencrypt` → `tls=true`** (there are 13 in compose_stack; edge
  has just settleup + maybe the dashboard). In the dynamic file add
  `tls.stores.default.defaultCertificate: { certFile, keyFile }` pointing at the mounted
  Origin cert/key.
- **Render the Origin cert + key to disk** — mirror `roles/restic_backup/tasks/secrets.yml`
  ("Create /etc/restic" 0700 → "Write the restic repository passphrase" `copy` with
  `content:` + `mode: 0600` + `no_log: true`). Two tasks: cert `content: "{{ cloudflare_origin_cert }}"`
  mode **0644**, key `content: "{{ cloudflare_origin_cert_key }}"` mode **0600**,
  `no_log: true`, into a dir bind-mounted read-only into Traefik. Vars already in sops
  (no new `.sops.yaml` rule).
- **rate-limit middleware (net-new):** add `http.middlewares.rate-limit.rateLimit`
  (e.g. `average`/`burst`) to the dynamic file; attach to settleup's router.
- **Real client IP (net-new):** add `--entrypoints.websecure.forwardedHeaders.trustedIPs=<CF ranges>`
  to the Traefik command block so rate-limit keys on / logs show the real client IP
  (`CF-Connecting-IP`/`X-Forwarded-For`), not a Cloudflare edge IP.
- **security-headers:** reuse the shared middleware — copy the `security-headers:` block
  from `compose_stack`'s dynamic file; **drop `jellyfin-headers`**.
- **settleup service** (mirror the **`homepage`** block in compose_stack's
  `docker-compose.yml.j2` — the cleanest one-web-app-behind-Traefik example):
  `image: ghcr.io/stromdahl/settleup:<pinned>`, **`expose`-only (NO `ports:`)**, on the
  Traefik network, env **`SETTLEUP_BASE_URL=https://settleup.stromdahl.io`** (that's the
  only required env — `SETTLEUP_ADDR=0.0.0.0:3000` and `SETTLEUP_DB=/data/settleup.db`
  are baked into the image), a **named volume mounted at `/data`** for the SQLite DB.
  Image is already **non-root (uid 10001)** — do not override `user:`. Router:
  `Host(\`settleup.stromdahl.io\`)`, `entrypoints=websecure`, `tls=true`,
  `middlewares=security-headers@file,rate-limit@file`, `loadbalancer.server.port=3000`.
- **Only Traefik publishes ports** (80/443, already ufw-allowed). No app container gets
  a `ports:` mapping — with the DOCKER-USER safety net gone, a published port *would*
  be internet-exposed. **Do NOT expose the Traefik dashboard** on the public box (drop
  its router, or don't add one).
- **Var naming:** mirror compose_stack's `compose_*` → `edge_*`. radon's
  `host_vars/radon/vars.yml` **does not exist yet** — create it (e.g. `edge_stack_dir:
  /opt/radon`, `settleup_image`, `settleup_base_url`). Keep the `docker compose` bring-up
  as `ansible.builtin.command` (community.docker isn't in the pinned collections).

## Entry points (create/edit — grep-stable)

- **NEW `ansible/roles/edge_stack/`** — mirror `ansible/roles/compose_stack/` minus
  netbird/firewall: `tasks/main.yml`, `templates/docker-compose.yml.j2`,
  `templates/stack.env.j2` (minimal), `files/traefik/dynamic.yml`, `meta/main.yml`
  (copy compose_stack's meta shape; `dependencies: []`). **No `handlers/`** (compose_stack
  has none).
- `ansible/site.yml` — grep **`Bring edge hosts`**; add `- role: edge_stack` after
  `geerlingguy.docker` (mirror how `compose_stack` sits in the `nas` play).
- **NEW `ansible/host_vars/radon/vars.yml`** — the plain edge vars.
- `ansible/host_vars/radon/secrets.sops.yml` — **already has** the cert vars; consume,
  don't edit.
- Cloudflare: the proxied `settleup` A record (external — see blockers).

## Prior art to mirror

- `ansible/roles/compose_stack/tasks/stack.yml` — the render-and-up task sequence.
- `ansible/roles/compose_stack/templates/docker-compose.yml.j2` — Traefik `command:`
  block (strip ACME), docker-socket-proxy + docker-provider label routing, the
  **`homepage`** service block shape for settleup.
- `ansible/roles/compose_stack/files/traefik/dynamic.yml` — `tls.options.default` +
  `security-headers` middleware to copy; add `tls.stores` + `rate-limit` here.
- `ansible/roles/restic_backup/tasks/secrets.yml` — the sops-secret-to-disk-at-0600 pattern.
- `servers/neon/config/traefik/dynamic.yml` — the original middleware source.

## Steps

1. Claim `issues/024` (status in-progress; commit on `main`).
2. Confirm `021` done; verify the cert vars exist in `host_vars/radon/secrets.sops.yml`.
3. Have the user create the proxied `settleup.stromdahl.io` A record; pick the pinned tag.
4. Scaffold `roles/edge_stack/` by copying compose_stack and deleting the mesh/firewall/
   assert pieces; reduce the compose template to Traefik + docker-socket-proxy + settleup.
5. Rework Traefik for the Origin cert (drop ACME/CF-token/certs-volume; `tls=true`;
   `tls.stores.default.defaultCertificate` in the dynamic file); add `rate-limit` +
   `forwardedHeaders.trustedIPs` (CF ranges) + reuse `security-headers`.
6. Add the two cert-to-disk tasks; create `host_vars/radon/vars.yml`; wire `edge_stack`
   into the edge play.
7. `--syntax-check`; deploy `ansible-playbook site.yml --limit radon`; re-run → `changed=0`.
8. Run the Verify block, tick every AC, commit the change, close the issue.

## Verify (exact commands)

- **Syntax + idempotent:** `cd ansible && ansible-playbook site.yml --syntax-check`;
  deploy `--limit radon`; a second `--limit radon` run → PLAY RECAP `changed=0`.
- **Live through Cloudflare:** `curl -sSI https://settleup.stromdahl.io` → `200`, valid
  cert chain; `curl -sv https://settleup.stromdahl.io 2>&1 | grep -i 'issuer\|subject'`
  shows the Cloudflare edge cert (Full (strict) active end-to-end).
- **IP hidden / proxied:** `dig +short settleup.stromdahl.io` → **Cloudflare** IPs, not
  `2.24.160.184`.
- **Only Traefik publishes ports:** `ansible radon -b -a "docker ps --format '{{.Names}} {{.Ports}}'"`
  → only traefik maps 80/443; settleup shows no host ports.
- **DB persists:** create a group in the app; `ansible radon -b -a "docker compose -f /opt/radon/docker-compose.yml restart settleup"`; the group survives (named volume).
- **Real client IP:** `ansible radon -b -a "docker logs traefik --tail 20"` (or access
  logs) show a real client IP, not a Cloudflare edge IP.
- **Cert key on disk 0600:** `ansible radon -b -a "stat -c '%a %n' <cert-dir>/origin.key"` → `600`.
- **Phone (human):** an invite link / QR opens on a phone with the `https://settleup.stromdahl.io` base.

## Acceptance criteria (from issue 024, verbatim)

- [ ] settleup loads at `https://settleup.stromdahl.io` with a valid certificate chain, through Cloudflare in Full (strict) mode.
- [ ] An invite link / QR generated by the deployed app uses the `https://settleup.stromdahl.io` base and opens on a phone.
- [ ] radon's real IP is not exposed in public DNS (the record is proxied); only 22/80/443 are reachable and only Traefik publishes ports.
- [ ] settleup's SQLite data survives a container restart (state lives on the persistent named volume).
- [ ] A rate-limit middleware and the shared security-headers are applied to the app's router; Traefik's logs/rate-limit show the real client IP, not a Cloudflare edge IP.
- [ ] The origin-cert key is sourced from sops (admin-key-only, no new rule; no per-host age key on radon) and rendered to disk for Traefik.
- [ ] A second playbook run reports **no changes** — the `edge_stack` role is idempotent.

## Out of scope / don't touch

- **`iptables-persistent` / DOCKER-USER / any `issues/028` firewall work** — must NOT
  land on radon; it would evict ufw. radon is publicly reachable by design.
- **NetBird / mesh** — excluded.
- **ACME / Let's Encrypt / any Cloudflare API token on radon** — replaced by the static
  Origin cert.
- **settleup's known v1 CSRF gap** — accepted as-is (issue 024 / PRD); not this work.
- **Backups, an apex `stromdahl.io` index page, lunchlund** — deferred / `issues/025`.
- **helium / the `nas` play** — untouched; deploy only `--limit radon`.
