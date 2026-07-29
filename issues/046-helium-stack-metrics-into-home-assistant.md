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

**Pull vs push is the discriminator, and NetBird decides it.** helium's containers
cannot resolve external names or `*.home.stromdahl.tech` — NetBird owns the host's
`resolv.conf`, which is why in-stack services must address each other by container
name. Any design where a collector on helium *pushes* to HA by hostname walks
straight into that. HA *pulling* from helium avoids container DNS entirely and is
therefore the strongly favoured shape — option 1, with option 2 as fallback if
per-container coverage proves inadequate.

**The read-only Docker socket proxy already in the stack is the asset to reuse.**
It runs with `CONTAINERS=1` / `INFO=1`, a read-only socket mount, and `cap_drop:
ALL`. If per-container stats are reachable through it as configured, container
metrics come free *within* the non-root/least-privilege posture established by
`issues/010`. If they are not, the design needs its own socket grant — a hardening
regression that would change the recommendation above. **The implementation must
answer this first**; it is not settled.

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
- [ ] Whether the existing read-only socket proxy can serve per-container metrics as
      configured is answered explicitly, and the resulting choice is recorded.
