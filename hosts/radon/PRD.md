# radon — public app server (PRD)

> Build plan for `radon`, a small public-facing cloud VPS that hosts the user's
> toy / side-project web apps under `*.stromdahl.io`. Crystallized from a grilling
> session; this is the durable spec the build follows. Decomposition into
> executable tasks is a separate step (`to-issues`).
>
> **Revised 2026-07-03:** the deploy/provisioning model changed from the neon-style
> git-push pipeline to the fleet's **Ansible** control layer (generalized from the
> helium pilot into a multi-host setup with radon as the first `edge` host), and the
> host moved from a planned Hetzner CX22 to an existing **Hostinger** VPS. ADR-0001
> still governs the tier's isolation and TLS posture, but its "reused git-push
> conventions" and "Hetzner snapshot" bullets are superseded by this revision — a
> new superseding ADR should record the git-push → Ansible decision.

## Problem Statement

The user has small side projects — a live example is **settleup** (a Rust/axum +
SQLite expense-splitter that people join by opening a link or scanning a QR from
their phone) — with no place to run them where others can reach them. The entire
existing fleet is deliberately **private**: helium and everything else are LAN +
NetBird-mesh only, with no router port-forward and nothing exposed to the public
internet by design. settleup, by contrast, is only useful if it is publicly
reachable. The user wants **one place where their toy projects live**, addressed
under a new `stromdahl.io` domain — without breaking the fleet's private-by-design
posture and, critically, without putting a public, no-authentication app next to
helium's NAS and family data (Immich, Paperless).

A second example app, **lunchlund**, muddies the framing but is instructive: it is
not a server at all — it is a build-time scraper whose GitHub Actions already build
a static site on a cron and publish it to GitHub Pages. It needs no host; it only
needs to appear under the same roof.

## Solution

Stand up **radon** as a single small **cloud VPS** — the only public-facing box in
the fleet — kept **entirely off the home network**. It runs dynamic apps in Docker
behind an internal Traefik, fronted by **Cloudflare** (proxied) so the VPS IP is
hidden and a free DDoS shield sits in front of the no-auth apps. TLS uses a static
**Cloudflare Origin Certificate**, so there is no ACME machinery and no Cloudflare
API token on the most-exposed box.

radon is managed by the fleet's **Ansible** control layer, pushed from krypton over
SSH — the same mechanism that provisions helium — now generalized into a small
**multi-host** setup where radon is the first member of a new **`edge`** inventory
group. This is a deliberate departure from the neon-style git-push deploy the fleet
used previously, chosen *because* radon is the most-exposed box: the Ansible model
holds **no age key, no deploy key, no GitHub key, and no cloned repo** on the target
— secrets are decrypted on krypton at run-time and pushed in memory — so radon ends
up holding only what Traefik must read from disk (the origin-cert key). Each app's
container image is built by that app's **own CI and pulled from GHCR**, so no build
toolchain lives on radon.

"One place" is resolved as the **`stromdahl.io` namespace**, not one runtime: every
project is reachable at `<app>.stromdahl.io`, but where each one actually executes
is an implementation detail. Dynamic apps (settleup and future siblings) run on
radon; static generators like lunchlund keep their existing zero-maintenance
pipeline and are simply **CNAME'd** into the namespace. radon deliberately does
**not** join the NetBird mesh — a compromised public box must have no path back into
the home network, which is the entire reason the workload lives on a VPS rather than
on helium.

## User Stories

1. As the user, I want a public URL like `settleup.stromdahl.io` that a stranger
   can open on their phone, so that my link/QR-based apps actually work for the
   people I share them with.
2. As the operator, I want all public app hosting on a dedicated box that is fully
   isolated from my home network, so that a compromise of a no-auth toy app can
   never reach my NAS or family data.
3. As the operator, I want the public box's real IP hidden and a shield in front of
   it, so that an unauthenticated app is not directly exposed to internet noise.
4. As the operator, I want radon managed by the same Ansible control layer and sops
   conventions as the rest of the fleet, so that it feels like the rest of the fleet
   and needs no bespoke deploy tooling — and so this build advances the fleet's
   move off the custom dotfiles modules onto Ansible.
5. As the operator, I want the most-exposed box to hold as little secret material as
   possible — no decrypting key, no deploy key, no repo — with secrets decrypted on
   krypton at run-time, so that a compromise yields the least.
6. As the operator, I want each app to build and publish its own image, so that the
   public box holds no build toolchain and deploys are a fast image pull.
7. As the user, I want all my toy projects to appear under one `stromdahl.io` roof,
   so that they feel like a coherent home even when some (e.g. lunchlund) keep
   running on GitHub Pages.
8. As the operator, I want the cost and the security effort to stay proportional to
   toy-project stakes, so that I am not running enterprise ceremony for a bar-tab
   splitter.

## Implementation Decisions

### Host / provider

- radon is an existing **Hostinger VPS** (KVM, ~1 vCPU / 4 GB RAM / 50 GB SSD)
  running **Debian 13 (trixie)**, matching the rest of the fleet. The Rust build
  runs in CI (GHCR), not on the box, so a single vCPU is sufficient to run Traefik +
  settleup.
- This replaces the originally-planned Hetzner CX22; the change is a provider swap
  only and does not affect the isolation, edge, or app decisions below. Its one
  consequence — backups — is addressed under *Operations* (deferred).
- The hostname continues the fleet's **noble-gas** naming (helium, neon, argon,
  krypton); `radon` is the unused one and a fitting name for the single box that
  faces the open internet. The provider-assigned hostname is renamed to `radon` by
  the `base` role at provision time.

### Edge / TLS

- `stromdahl.io` is a **new Cloudflare zone** on the existing account. Records for
  radon-hosted apps are **proxied (orange-cloud)**, hiding radon's IP and giving
  free DDoS/bot mitigation in front of the no-auth apps.
- TLS terminates twice: browser→Cloudflare on Cloudflare's automatic edge
  certificate, and Cloudflare→radon on a **static Cloudflare Origin Certificate**
  served by Traefik with SSL mode **Full (strict)**. The Origin cert is long-lived
  (set once), so there is **no ACME, no auto-renewal, and no Cloudflare API token
  on radon** — a deliberate reduction of secret footprint on the most-exposed box,
  and a departure from the fleet's Let's-Encrypt DNS-01 pattern (which exists only
  because the private hosts have no inbound path).

### Provisioning & deploy (Ansible)

- radon is brought up and kept in state by the fleet's **Ansible** layer, run from
  krypton over SSH as the box's existing cloud-init **`debian`** admin user (which
  already carries an SSH key and passwordless sudo — so no bootstrap step and no
  lockout risk when SSH is hardened). radon is added to a new **`edge`** inventory
  group; the single `site.yml` gains a second play so `edge` hosts receive their own
  role set while helium's `nas` play is unchanged.
- radon reuses the fleet-consistent **`base`** role (hostname/timezone, key-only SSH
  with root login and password auth disabled, ufw default-deny allowing only
  22/80/443, a fail2ban sshd jail, unattended security upgrades) and the
  **`geerlingguy.docker`** role (docker-ce + compose v2 from the official repo). It
  gets **none** of helium's storage or mesh roles.
- Secrets remain **sops + age**, but — following the helium pilot — are decrypted
  **on krypton at run-time** by the `community.sops` vars plugin and passed to the
  connection in memory. radon holds **no per-host age key**; the sole recipient of
  its encrypted vars is the admin key. This is the concrete mechanism behind the
  "least secret material on the exposed box" goal.
- Updating radon (a config change or a new app image) is a re-run of the playbook
  from krypton, optionally scoped with `--limit radon` / `--tags`. Deploys are
  therefore push-from-krypton rather than self-contained on the box; krypton is a
  soft dependency, accepted for a single toy-app host.

### App packaging (GHCR)

- Each **app image is built by the app's own CI** (GitHub Actions) and published to
  **GHCR as a public package**; radon only ever pulls it. No language toolchain or
  source build runs on the public box. settleup — currently a local-only repo —
  must first be pushed to GitHub and given a multi-stage Dockerfile (slim/distroless
  runtime) and a build-and-push workflow. Its test suite (`cargo test`) gates the
  build in CI.

### The `edge_stack` role & settleup (first tenant)

- A new **`edge_stack`** Ansible role runs radon's public stack. It mirrors the
  helium `compose_stack` render-and-up pattern (render `docker-compose.yml` + env
  from templates, render Traefik dynamic config, `docker compose up -d`) but drops
  the two helium-specific pieces — the NetBird mesh join and the DOCKER-USER LAN-drop
  firewall rules — because radon must be publicly reachable, not mesh-restricted.
- **Traefik** serves the static **Cloudflare Origin certificate** via its file
  provider (no ACME, no cert resolver). It applies the fleet's shared
  **security-headers** middleware plus a **rate-limit** middleware (the apps are
  unauthenticated). Because all traffic arrives from Cloudflare's edge, Traefik is
  configured to **trust Cloudflare's IP ranges** so the rate-limit keys on — and
  logs record — the real client IP (via `CF-Connecting-IP`/`X-Forwarded-For`) rather
  than throttling Cloudflare collectively.
- The origin cert's **private key** is stored **sops-encrypted for radon** in the
  Ansible host vars (admin-key-only; it inherits the pilot's existing
  `ansible/host_vars` creation rule, so **no new sops rule is needed**) and rendered
  to disk at 0600 by the role for Traefik to read. This key is radon's **only**
  secret — settleup itself has no secret env vars (a no-account app whose identity is
  a per-device cookie token).
- **settleup** runs as a container on Traefik's internal network, `expose`-only —
  it publishes **no** host ports. It is configured via its documented environment:
  `SETTLEUP_ADDR=0.0.0.0:3000` (bind all interfaces internally),
  `SETTLEUP_BASE_URL=https://settleup.stromdahl.io` (required, or the QR/invite
  links are built with the wrong scheme; secure cookies switch on automatically from
  the `https` base URL), and `SETTLEUP_DB` pointed at a **Docker named volume** on
  radon's local disk. The image is a **pinned** GHCR tag.
- **Only Traefik publishes ports** (80/443, which ufw already allows). The public-box
  firewall posture is discipline, not extra rules: no container other than Traefik
  gets a `ports:` mapping, so Docker's iptables-bypass cannot inadvertently expose an
  app. No DOCKER-USER rules are added (they exist on helium only to *hide* published
  ports from the LAN — the opposite of radon's need).

## Testing Decisions

No meaningful unit-test surface — this is infrastructure/config. settleup's own
`cargo test` suite runs in its CI as a build gate, but radon's validation is
operational:

- A second `ansible-playbook site.yml --limit radon` run reports **no changes**
  (idempotent), the fleet's standard bar for a role being correct.
- `settleup.stromdahl.io` loads over HTTPS through Cloudflare with a valid
  certificate chain and Full (strict) mode active.
- An invite link / QR generated by the deployed app uses the correct
  `https://settleup.stromdahl.io` base and opens on a phone.
- settleup's SQLite data survives a container restart (state is on the persistent
  named volume).
- Only 22/80/443 are reachable from the internet; the VPS's real IP is not exposed
  in DNS; only Traefik publishes ports.
- Traefik logs and the rate-limit show the **real client IP**, not a Cloudflare edge
  IP (confirms the trusted-ranges config).
- `lunchlund.stromdahl.io` resolves to the GitHub Pages site with a valid
  certificate.

## Out of Scope

- **Backups (deferred).** The originally-planned Hetzner daily snapshots do not
  apply to Hostinger. Nothing critical lives on radon yet and settleup's data is
  inherently transient (groups with no recovery passphrase auto-delete after ~3 days
  of inactivity), so no backup is configured for now. Revisit — Hostinger's built-in
  backups, or restic to an append-only cloud repo — when a tenant lands durable data.
- **Migrating neon or other fleet hosts onto Ansible.** This build generalizes the
  Ansible layer to multi-host and adds radon as the first `edge` host; the structure
  makes later migrations possible, but moving existing hosts is explicitly not part
  of this work.
- **Re-hosting lunchlund.** It stays a GitHub-Pages static site, CNAME'd into the
  namespace — not run on radon.
- **NetBird mesh membership** for radon, and any **backups to helium**. radon is
  deliberately disconnected from the home network.
- **An apex index page at `stromdahl.io`** listing the projects (deferred/optional).
  If wanted later, the recommended form is a tiny static page on Cloudflare Pages,
  keeping radon dedicated to real apps.
- **Fixing settleup's known v1 CSRF gap** — accepted as-is for a no-account,
  low-stakes toy; not part of this hosting work.
- **Heavier web security** — WAF rules, HTTP-layer fail2ban, or web authentication.
  Cloudflare's default shield plus security-headers plus a rate-limit middleware is
  the intended proportional posture.
- **Let's Encrypt / DNS-01 / a Cloudflare API token on radon** — replaced by the
  static Origin certificate.

## Further Notes

- The security and cost posture is intentionally scaled to **toy-project stakes**.
  settleup auto-expires stale groups hourly, so its data is inherently transient —
  a further reason no elaborate backup regime is warranted while stakes stay low.
- **Why Ansible over the git-push pipeline for radon:** the git-push model would
  place a per-host age key, a bare git repo, and a full clone of the dotfiles repo on
  the most-exposed box. The Ansible model puts none of that there — the decrypting
  key stays on krypton and secrets are pushed in memory — which realizes ADR-0001's
  "minimal footprint on the exposed box" goal more completely. This decision warrants
  a new ADR superseding the relevant bullets of ADR-0001.
- `stromdahl.tech` (the existing private fleet zone) is left entirely untouched; its
  Cloudflare token is scoped to `home.stromdahl.tech` and does not cover the new
  `stromdahl.io` zone.
- "One place" was explicitly resolved as a **presentation** concern (the shared
  `stromdahl.io` namespace), not a **runtime** one — which is what lets lunchlund
  keep its free GitHub Pages pipeline while still living under the same roof.
- Choosing a dedicated VPS over hosting on helium or a new VM on argon was an
  isolation decision: the public, unauthenticated workload is kept off the home
  network entirely and off known-flaky hardware.
- **Build order:** the `base` + `docker` roles have no external dependencies and can
  run first — bringing radon under management and immediately disabling password-auth
  on the public box. `edge_stack` waits on its human-gated prerequisites: the
  Cloudflare zone + Origin cert, the settleup GHCR image, and the proxied DNS record.
  lunchlund's CNAME is independent DNS work.
