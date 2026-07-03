---
title: Resolve the nas ufw vs iptables-persistent conflict — keep ufw fleet-wide
status: open
priority: high
created: 2026-07-03
closed: null
labels: [epic:ansible]
---

## Description

The `nas` playbook is **non-idempotent by construction** and currently leaves helium
with **no host firewall**. The `base` role installs **ufw** (default-deny incoming,
allow 22/80/443) as the fleet-wide hardening baseline; the `compose_stack` role
installs **iptables-persistent** so its `DOCKER-USER` LAN-drop rules (the "Docker
bypasses ufw" fix from `issues/005`) survive a reboot. But the `ufw` package declares
`Breaks: iptables-persistent, netfilter-persistent`, so the two cannot co-exist —
whichever role runs last evicts the other's package.

On helium this already happened: ufw was installed (base), then removed the next day
in the same apt transaction that installed iptables-persistent (compose_stack). Today
helium's firewall is iptables-persistent + Docker's own nft chains, and the
host-level default-deny the design intends is **absent**. Every full playbook run
would thrash both packages back and forth.

Keep **ufw as the single fleet-wide base firewall** — it is also what the `edge`/radon
hosts rely on for their 22/80/443 default-deny — and persist the `DOCKER-USER`
default-deny reinstatement **without iptables-persistent** (e.g. via ufw's own
`after.rules` injection — the standard ufw-docker technique — or a boot-time systemd
oneshot that re-applies the rules). That removes the package `Breaks` conflict, so ufw
and the Docker LAN-drop coexist, a full `nas` run is idempotent again, and helium
regains its host-level default-deny. Restore ufw on helium as part of the change.

This is **nas-only**: the `edge` group runs base + docker with no `compose_stack`, and
the radon `edge_stack` (`issues/024`) adds no `DOCKER-USER` rules, so it needs no
iptables-persistent and keeps ufw. When `issues/024` is built, it must **not** copy
compose_stack's iptables-persistent step, or radon replays this conflict.

Discovered while verifying `issues/027`. Independent of other open work.

## Acceptance criteria

- [ ] ufw is installed, enabled, and default-deny (incoming) allowing only 22/80/443 on helium, coexisting with Docker.
- [ ] The `compose_stack` LAN-drop behaviour from `issues/005` is preserved (published ports stay within the intended LAN+mesh boundary per `compose_restrict_to_mesh`) and its `DOCKER-USER` reinstatement survives a reboot **without** iptables-persistent.
- [ ] iptables-persistent / netfilter-persistent is no longer installed or required on helium.
- [ ] A full `ansible-playbook site.yml` run against helium is idempotent — a second run reports **no changes**, with no package thrash between ufw and iptables-persistent.
- [ ] The fix lives in the shared roles (not helium-only hacks), so any future `nas` host reproduces the same posture.
