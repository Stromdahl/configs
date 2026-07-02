# 0001 — Public app tier on an isolated VPS (radon)

- **Status:** Accepted (2026-07-02)

## Context

The fleet is **private-by-design**: every host is reachable only over the LAN and
the NetBird mesh, there is no router port-forward anywhere, and nothing is exposed
to the public internet. Fleet TLS is **Let's Encrypt DNS-01 via Cloudflare**, chosen
specifically because private hosts have no inbound path — DNS-01 validates over the
API and needs no open port.

That posture has no answer for an app that is *only useful when publicly reachable*.
The concrete driver is **settleup** (an expense-splitter people join by opening a
link or scanning a QR from a phone); more toy/side projects are expected to follow,
addressed under a new `stromdahl.io` domain. Serving such apps conflicts with the
standing "nothing public" norm, and the obvious cheap option — running them on
helium — would place a no-authentication app next to the NAS and family data
(Immich, Paperless).

## Decision

Introduce a **dedicated public-facing tier as a single small cloud VPS (`radon`,
Hetzner CX22, Helsinki, Debian 13)** — the fleet's first and only internet-facing
host — with these deliberate departures from the fleet norm:

- **Isolated from the home network.** radon does **not** join the NetBird mesh and
  carries no storage/NAS modules. A compromised public box must have no path back
  into the home fleet; that isolation is the entire reason the workload is on a VPS
  rather than on helium.
- **Cloudflare-fronted with a static Origin certificate.** Public records are
  proxied (orange-cloud) so the VPS IP is hidden behind Cloudflare's shield, and
  origin TLS is a long-lived **Cloudflare Origin Certificate** served by Traefik
  (SSL Full (strict)). This **replaces Let's Encrypt DNS-01 for this tier**: no
  ACME, no auto-renewal, and — deliberately — **no Cloudflare API token on the
  most-exposed box**.
- **Reused deploy conventions.** The Gen-1 git-push pipeline and sops secrets carry
  over unchanged; each app's container image is built by the app's **own CI and
  pulled from GHCR**, so no build toolchain lives on radon.

`stromdahl.io` is a **new Cloudflare zone** with its own credentials, separate from
the existing `stromdahl.tech`.

## Consequences

- Public attack surface is fully isolated from the home network; a compromised radon
  has no mesh foothold and cannot reach the NAS.
- The most-exposed box holds neither a Cloudflare API token nor ACME machinery — its
  only secret is the static origin-cert key.
- Cheap (~€4/mo) and consistent with existing deploy/secret tooling.
- **A second TLS mechanism now exists in the fleet** (static origin cert on radon vs
  LE DNS-01 everywhere else). This is intentional: future work must **not**
  "reconcile" radon onto the mesh or onto LE DNS-01 — either would defeat the
  isolation or re-add a token to the exposed box.
- Cloudflare is now in the request path for public apps (a dependency and a trust
  placement) — already accepted for `stromdahl.tech`.

## Alternatives considered

- **Host on helium + Cloudflare Tunnel** — rejected: puts a no-auth public app next
  to NAS and family data.
- **New VM on argon + Cloudflare Tunnel** — rejected: piles public exposure onto
  known-flaky hardware already running Home Assistant, and still creates a
  home-network path.
- **radon on the NetBird mesh** (mesh-only SSH, backups to helium) — rejected:
  drills a path from the most-exposed box back into the home mesh, undoing the
  isolation the VPS was chosen for.
- **OPNsense port-forward + DDNS** — rejected: breaks the fleet-wide no-port-forward
  invariant, exposes the home IP, and is likely blocked by CGNAT on residential
  service.
- **Let's Encrypt (HTTP-01 or DNS-01) on radon** — rejected in favor of the static
  origin cert: HTTP-01 needs port-80 challenge handling; DNS-01 needs a Cloudflare
  token on the exposed box. The origin cert needs neither.

## Links

- Durable spec: `hosts/radon/PRD.md`
- Backlog: `issues/021`–`issues/025` (`epic:public-apps`)
