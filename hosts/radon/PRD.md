# radon — public app server (PRD)

> Build plan for `radon`, a small public-facing cloud VPS that hosts the user's
> toy / side-project web apps under `*.stromdahl.io`. Crystallized from a grilling
> session; this is the durable spec the build follows. Decomposition into
> executable tasks is a separate step (`to-issues`).

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
API token on the most-exposed box. The stack is deployed with the existing
**git-push → sparse-checkout → `deploy.sh`** pipeline (the same shape neon used);
each app's container image is built by that app's **own CI and pulled from GHCR**,
so no build toolchain lives on radon.

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
4. As the operator, I want to reuse my existing git-push deploy and sops secret
   conventions, so that radon feels like the rest of the fleet and needs no new
   deploy tooling.
5. As the operator, I want each app to build and publish its own image, so that the
   public box holds no build toolchain and deploys are a fast image pull.
6. As the user, I want all my toy projects to appear under one `stromdahl.io` roof,
   so that they feel like a coherent home even when some (e.g. lunchlund) keep
   running on GitHub Pages.
7. As the operator, I want the cost and the security effort to stay proportional to
   toy-project stakes, so that I am not running enterprise ceremony for a bar-tab
   splitter.

## Implementation Decisions

### Host / provider

- radon is a **Hetzner CX22** shared-vCPU instance (2 vCPU / 4 GB / 40 GB SSD) in
  the **Helsinki** region — lowest latency for the operator and the Nordic
  audience. x86 is chosen over the ARM tier because it is currently cheaper and
  avoids any ARM container-image concerns for the Rust build.
- OS is **Debian 13 (trixie)**, matching the rest of the fleet so every dotfiles
  module and convention applies unchanged.
- The hostname continues the fleet's **noble-gas** naming (helium, neon, argon,
  krypton); `radon` is the unused one and a fitting name for the single box that
  faces the open internet.

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

### Deploy & app packaging

- The **stack config** (Traefik + apps) reaches radon via the existing **Gen-1
  git-push pipeline**: push the dotfiles repo to radon's bare deploy repo; a
  post-receive hook sparse-checks-out this host's `servers/<host>` tree and runs
  its `deploy.sh` (sops-decrypt secrets → `docker compose pull && up -d`). This is
  the same mechanism neon used and is self-contained on the box, with no dependency
  on an external control node.
- Each **app image is built by the app's own CI** (GitHub Actions) and published to
  **GHCR as a public package**; radon only ever pulls it. No language toolchain or
  source build runs on the public box. settleup — currently a local-only repo —
  must first be pushed to GitHub and given a multi-stage Dockerfile (slim/distroless
  runtime) and a build-and-push workflow.
- Updating an app is therefore: push the app → CI publishes a new image → trigger a
  radon deploy to pull it. Auto-pull tooling is intentionally not added.

### settleup (first tenant)

- Runs as a container listening on an internal port only; Traefik routes
  `settleup.stromdahl.io` to it. No container ports are published to the host —
  only Traefik binds 80/443.
- Configured for production via its documented environment: bind on all interfaces
  internally, `SETTLEUP_BASE_URL=https://settleup.stromdahl.io` (required, or the
  QR/invite links are built with the wrong scheme), and its SQLite database path
  pointed at a **Docker named volume on radon's local disk**. Secure cookies switch
  on automatically with the HTTPS base URL.
- A **rate-limit** Traefik middleware is applied in addition to the shared
  security-headers middleware, since the app is unauthenticated.

### Operations, isolation & backups

- radon is **standalone**: it does **not** join the NetBird mesh, so a compromised
  public box has no network path into the home fleet. This preserves the isolation
  that justified using a VPS in the first place.
- Admin access is **key-only SSH over the public internet** using the fleet's
  `stromdahl.keys`, with root login disabled and a fail2ban sshd jail — standard
  VPS hygiene, matching the fleet's hardening posture.
- Backups use **Hetzner's built-in automated daily whole-disk snapshots**. Keeping
  each app's durable state on a local Docker volume (rather than a separate block
  volume) ensures the snapshot covers it. No custom backup tooling and no backups
  to helium — proportional to toy-app stakes, and consistent with keeping radon
  disconnected from home.

### Secrets, DNS & hardening

- Secrets remain **sops + age**, consumed by `deploy.sh` as a decrypted dotenv
  written to disk at deploy time (the neon pattern). The one secret radon needs is
  the **Cloudflare Origin Certificate private key**; a new sops creation-rule and a
  per-host age key are added for this host.
- Cloudflare DNS: `settleup.stromdahl.io` → proxied A record → radon;
  `lunchlund.stromdahl.io` → CNAME → the existing GitHub Pages site, with the custom
  domain configured on the lunchlund repo's Pages settings. lunchlund's build and
  hosting are otherwise untouched.
- Host firewall allows only 22/80/443 inbound. Because Docker inserts its own
  forwarding rules, care is taken that **only Traefik publishes ports** so nothing
  bypasses the intended boundary.
- The host's `modules.conf` mirrors neon's *server* module set (base, hardened
  sshd, ssh keys, ufw, fail2ban, docker, then deploy-user, sops, bare-git-repo) and
  omits all NAS/storage/mesh modules.

## Testing Decisions

No meaningful unit-test surface — this is infrastructure/config. settleup's own
`cargo test` suite runs in its CI as a build gate, but radon's validation is
operational:

- `settleup.stromdahl.io` loads over HTTPS through Cloudflare with a valid
  certificate chain and Full (strict) mode active.
- An invite link / QR generated by the deployed app uses the correct
  `https://settleup.stromdahl.io` base and opens on a phone.
- settleup's SQLite data survives a container restart and a Hetzner snapshot
  restore (state is on the persistent volume).
- Only 22/80/443 are reachable from the internet; the VPS's real IP is not exposed
  in DNS.
- `lunchlund.stromdahl.io` resolves to the GitHub Pages site with a valid
  certificate.

## Out of Scope

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
- **Migrating any other fleet host** onto or off of this pattern — radon is a new,
  standalone box.

## Further Notes

- The security and cost posture is intentionally scaled to **toy-project stakes**.
  settleup auto-expires stale groups hourly, so its data is inherently transient —
  a further reason daily snapshots are sufficient and no elaborate backup regime is
  warranted.
- `stromdahl.tech` (the existing private fleet zone) is left entirely untouched; its
  Cloudflare token is scoped to `home.stromdahl.tech` and does not cover the new
  `stromdahl.io` zone.
- "One place" was explicitly resolved as a **presentation** concern (the shared
  `stromdahl.io` namespace), not a **runtime** one — which is what lets lunchlund
  keep its free GitHub Pages pipeline while still living under the same roof.
- Choosing a dedicated VPS over hosting on helium or a new VM on argon was an
  isolation decision: the public, unauthenticated workload is kept off the home
  network entirely and off known-flaky hardware.
