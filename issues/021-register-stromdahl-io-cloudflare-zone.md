---
title: Register stromdahl.io and set up its Cloudflare zone + Origin certificate
status: in-progress
priority: high
created: 2026-07-02
closed: null
labels: [epic:public-apps, needs-human]
---

## Description

Establish the public domain that the whole app tier hangs off, and mint the static
TLS material radon will serve. Nothing else can be reached until the zone is live
and the origin certificate exists, so this is the DNS + TLS foundation.

Register `stromdahl.io` at a registrar, delegate it to **Cloudflare as a new zone**
on the existing account (point the registrar's nameservers at Cloudflare), and set
the zone's SSL/TLS mode to **Full (strict)**. Then generate a **Cloudflare Origin
Certificate** covering `stromdahl.io` and `*.stromdahl.io` — a long-lived cert set
once, which is what lets radon serve valid TLS with no ACME machinery. The origin
cert's private key is the single secret radon needs; capture it securely for the
stack slice to consume (`issues/024` stores it sops-encrypted under the existing
admin-key rule — radon holds no per-host key).

The existing `stromdahl.tech` zone and its `home.stromdahl.tech`-scoped token are
left completely untouched — this is a separate zone with no shared credentials.
Deliberately **no** Let's Encrypt, DNS-01, or Cloudflare API token is introduced
for radon; the static origin cert replaces all of that.

## Acceptance criteria

- [ ] `stromdahl.io` is registered and its nameservers point at Cloudflare; the zone shows Active.
- [ ] The zone's SSL/TLS mode is set to Full (strict).
- [ ] A Cloudflare Origin Certificate covering `stromdahl.io` and `*.stromdahl.io` is generated, and its private key is captured securely for the stack slice.
- [ ] `stromdahl.tech` and its existing token are unchanged.
- [ ] No Let's Encrypt / DNS-01 / Cloudflare API token is created for radon.
