---
title: Surface helium stack + host metrics as Home Assistant entities
status: open
priority: medium
created: 2026-07-29
closed: null
labels: [epic:services]
---

## Description

Home Assistant is the household's single pane of glass, but it currently knows
**nothing about helium** — the box running the entire self-hosted stack. HA holds
~222 entities and not one of them reports a helium CPU, memory, pool-capacity,
drive-temperature, or container-state value. Meanwhile helium runs **27 declared
services**, and the fleet has **no metrics substrate at all**: no Prometheus, no
Grafana, no InfluxDB, no MQTT broker anywhere. So "is the stack healthy?" is
answerable today only by SSH-ing in and reading `docker ps` / `sensors` /
`snapraid status` by hand.

This slice makes helium's health legible inside HA as first-class entities: host
vitals (CPU, load, memory, uptime), storage (pool + SSD-tier capacity, drive
temperatures — the `sensors` stack already exists on the host), and container
liveness for the stack's services. Once those are entities, they're available to
everything HA already does — history, dashboards, automations, mobile app.

**Deliverable is the entities existing and being trustworthy.** Dashboard cards and
alerting/automation on top of them are deliberately out of scope for this slice —
they're cheap follow-ons once the data lands, and bundling them would stall the
slice on layout bikeshedding.

**Open decision (blocks implementation):** which substrate, at the level of design
shape rather than product:

1. **Host agent polled by HA** — a lightweight metrics agent on helium exposing a
   local HTTP/REST surface that HA reads on an interval. Smallest new surface,
   no broker, no time-series database to back up. Glances is the obvious
   candidate here; whether its Docker plugin gives usable *per-container* state
   through HA needs verifying before committing.
2. **Push to a broker** — a collector on helium publishing to MQTT, with HA
   subscribing. Most flexible and the idiomatic HA path, but it introduces a
   broker as new infrastructure the fleet doesn't have yet.
3. **Full time-series stack** — Prometheus + exporters on helium, with HA reading
   from it. Much the largest footprint; buys real dashboards and retention that
   HA's own recorder won't, but it's a second observability system to own,
   secure, and back up.

**Both directions are on the table; DNS does not constrain the choice.** HA, helium,
and krypton all sit on the same LAN and resolve each other's `*.home.stromdahl.tech`
names through the OPNsense resolver's split-horizon view (internal answers point at
LAN IPs). Containers on helium resolve the same way — Docker's daemon DNS is pinned
to the OPNsense resolver precisely so container name resolution is independent of
NetBird's rewriting of the host `resolv.conf`, and that includes the internal
wildcard. So a collector on helium pushing *to* HA is as viable as HA polling
helium. The one standing caveat is that this only holds while that daemon-DNS pin
stays in place — NetBird re-breaks the host file on every reboot, and the pin is
what absorbs it.

**The real discriminator is how much new infrastructure the slice takes on.** Option
1 adds one agent and no persistent state. Option 2 adds a broker the fleet does not
have. Option 3 adds a second observability system to own, secure, and back up. That
argues for option 1 as the opening move, with option 2 as fallback if per-container
coverage proves inadequate — but this is the decision to make, not a settled call,
and a broker earns its keep if it's wanted for other things later.

**Container metrics come free from the existing read-only socket proxy — verified
2026-07-29, no new socket access needed.** The proxy already in the stack
(`CONTAINERS=1` / `INFO=1`, read-only socket mount, `cap_drop: ALL`) serves
per-container stats in full: a non-streaming stats call returns cumulative CPU time,
memory usage and limit, per-interface network counters, and block-IO figures, plus
the previous-sample CPU block needed to compute a percentage from a single request.
Container inspect, process list, and daemon info are served too. The ACL is genuinely
scoped, not a wide-open socket — image and swarm-node endpoints are refused. So
container metrics are obtainable entirely within the least-privilege posture of
`issues/010`. Homepage already consumes this proxy for container status, so the
pattern is proven in-stack rather than theoretical.

**That does, however, sharpen the collector's shape.** The proxy is deliberately not
published — nothing listens on the host, and it is reachable only on its internal
bridge network (whose current members are the proxy, Traefik, and Homepage). A
collector installed on the *host* therefore cannot address it by name and would have
to fall back to either an unstable container IP or its own raw socket mount — the
hardening regression to avoid. A collector running as a container joined to that
network reaches it by service name, exactly as Homepage does. Conversely, host vitals
(CPU, memory, drive temperatures) are trivial for a host-level agent and need
explicit host mounts / PID namespace access from inside a container. The design must
resolve this tension — one containerized collector granted the host visibility it
needs, or a split where host vitals and container metrics come from different
sources.

Adjacent to `issues/013` (storage-timer failure alerting): if HA becomes the metrics
sink, HA also becomes a plausible notification channel, which partly pre-empts 013's
open decision between ntfy / healthchecks / msmtp. Neither slice closes the other,
but whichever lands first constrains the other's answer — decide them with one eye
on each. No hard dependency either way.

Scoped from a 2026-07-26 session that audited both sides and stopped at the finding
that there was no substrate to integrate against.

## Acceptance criteria

- [ ] helium host vitals (at minimum CPU, memory, uptime) are live HA entities with
      sane units and correct device classes.
- [ ] Storage capacity for the HDD pool and the SSD tier, plus per-drive
      temperatures, are live HA entities.
- [ ] Container liveness for the stack's services is visible in HA — a service
      stopped by hand is reflected in HA within one poll interval.
- [ ] The entities survive a helium reboot and an HA restart without manual
      re-adding, and recover on their own after helium is unreachable for a while.
- [ ] Whatever runs on helium is applied by Ansible from krypton, idempotently, and
      holds the non-root / least-privilege posture of `issues/010` — verified by a
      second run reporting no changes.
- [ ] Any new listening port stays inside the intended LAN + mesh boundary; nothing
      new is published to the internet.
- [ ] Container metrics are sourced through the existing read-only socket proxy; no
      additional or broader Docker socket access is granted to anything.
