---
title: Surface helium stack + host metrics as Home Assistant entities
status: in-progress
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

There are **two open decisions** below, and they are independent: the transport
substrate, and where the host-vitals collector runs. Both block implementation.

**Open decision 1 — which substrate**, at the level of design shape rather than
product:

1. **Host agent polled by HA** — a lightweight metrics agent on helium exposing a
   local HTTP/REST surface that HA reads on an interval. Smallest new surface,
   no broker, no time-series database to back up. Glances is the obvious
   candidate here, and its own Docker plugin does read per-container data — but
   HA's Glances integration does not surface any of it as entities. Verified
   below; it means this option cannot reach container liveness on its own.
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
argued for option 1 as the opening move, with option 2 as fallback if per-container
coverage proved inadequate — and the verification below is what settles that fallback
question: per-container coverage *is* inadequate, so footprint alone no longer decides
it.

**Verified against upstream source on 2026-07-29, not recalled:**

- **HA's Glances integration exposes no per-container entity.** It creates one entity
  per labelled instance only for filesystems, disk-IO, sensors, RAID, GPU and network;
  Docker falls into the unlabelled branch and yields exactly three aggregates — an
  active-container count, total CPU percent, and total memory. A service stopped by
  hand therefore shows up only as a counter moving from 27 to 26, with no indication of
  *which* service died. That does not satisfy the container-liveness criterion.
- **Anything that speaks Docker's API can be pointed at the socket proxy.** Glances
  builds its Docker client from the environment rather than a hardcoded socket path, so
  it honours a `DOCKER_HOST` naming a TCP endpoint. This finding outlives the Glances
  question: it is the general reason a containerized consumer on the proxy's network
  needs no socket mount, and it holds for the Docker CLI too.
- **Glances cannot see the pool drives' temperatures at all.** Its HDD temperatures come
  from the `hddtemp` daemon, not from SMART — so SAS drives behind the HBA are invisible
  to it regardless of transport. Its core-temperature and fan readings do come from the
  same kernel hwmon path the host's `sensors` stack uses, so board/CPU coverage is real.
- **Option 3 has a direction problem worth noting:** HA's Prometheus integration is an
  *exporter* — it publishes HA's own state for Prometheus to scrape. It is not a reader,
  so pulling metrics the other way would still mean hand-written per-metric queries and
  no automatic entity creation. Option 3's footprint cost buys nothing toward this
  slice's deliverable.

The consequence for the shape of the answer: 27 services' worth of entities should not
be hand-declared, so a transport with an **entity-discovery mechanism** is worth real
weight in this decision — that is the property option 1 lacks and option 2 has natively.

**The read-only Docker socket proxy already in the stack is the asset to reuse, and
it is sufficient — this is settled.** It runs with `CONTAINERS=1` / `INFO=1`, a
read-only socket mount, and `cap_drop: ALL`. Its ACL gates the container endpoints on
a *prefix* match of `/containers`, so per-container stats and inspect are both
permitted under `CONTAINERS=1`; there is no separate stats gate. The mutating
endpoints (stop / restart / kill / pause) sit behind their own switches, which this
stack does not enable, so they stay denied. Its generous 10-minute client/server
timeouts accommodate the streaming form of the stats endpoint as well as one-shot
polls.

**Confirmed against the live host on 2026-07-29**, not just read off upstream's
config: stats, inspect, process-list, daemon-info, and container-list all answer,
while image and swarm-node endpoints are refused — the ACL is genuinely scoped rather
than an open socket. A single non-streaming stats call returns cumulative CPU time,
memory usage and limit, per-interface network counters, and block-IO figures, and it
includes the previous-sample CPU block, so **CPU percentage is computable from one
one-shot poll** — no streaming connection required. (`num_procs` is a Windows-only
field and reads 0 here; don't use it for a process count.)

The consequence is that **container metrics come free inside the non-root /
least-privilege posture of `issues/010`** — the collector joins the existing
`socket_proxy` network (as Traefik and the homepage dashboard already do) and needs
no socket mount and no new capability of its own. Any design that instead mounts the
raw Docker socket is a hardening regression and should be rejected. Note that *host*
vitals are a separate privilege question from container metrics: reading CPU / memory
/ temperatures needs host-level visibility, which the socket proxy neither provides
nor covers.

**Open decision 2 — where the host-vitals collector runs.** This is the genuinely
awkward half, and unlike the socket path it is a real tension with `issues/010`:

- **As a container.** Keeps the stack uniformly compose-managed, but reading host
  CPU / memory / uptime wants `pid: host` plus `/proc` and `/sys` mounts, and pool
  and SSD-tier capacity wants visibility of the host mount points. That is a
  markedly wider grant than anything else in the stack holds, in a stack whose
  whole posture is non-root and `cap_drop: ALL`.
- **As a host service.** A systemd unit reading the host directly needs no container
  escape hatches at all and sidesteps `issues/010` entirely — but it introduces a
  non-container component to a stack that is otherwise wholly compose-managed, with
  its own packaging, upgrade, and Ansible-role story.

A constraint that bears directly on this choice: the socket proxy publishes **no
port** — nothing listens on the host, and it answers only on its internal bridge
network. A host-level collector therefore cannot address it by service name and would
be left with an unstable container IP or its own socket mount. So choosing the host
service for vitals implies container metrics come from a *separate* containerized
consumer on that network — i.e. the two open decisions are less independent than they
look, and "one collector for everything" is only reachable via the container option.

Note also that the drive temperatures and the board/CPU temperatures come from
**different sources** — the SAS drives behind the HBA report temperature via SMART,
while the board and CPU sensors come from the `nct6775`-backed `sensors` stack
already installed on the host. A collector that reads one does not necessarily read
the other, so "temperatures" is not a single integration.

**That asymmetry decides decision 2, rather than leaving it a matter of taste.** Reading
SMART attributes off the pool drives means issuing SCSI commands to the raw block
devices as root — a materially wider grant than `pid: host` plus `/proc` and `/sys`, and
one that cannot be reconciled with `cap_drop: ALL` at all. The host already carries the
SMART tooling and runs a SMART daemon for the spin-down work, so the capability exists
there and needs no new grant anywhere. The per-drive-temperature criterion therefore
**forces a host-side component whichever substrate wins.**

Which inverts the earlier reading of this decision: "one collector for everything" is
not merely hard to reach via the host option, it is unreachable via *either* option. The
container option cannot cover drive temperatures, and the host option cannot address the
socket proxy. So the slice takes **two publishers by construction** — a host-side one for
vitals, capacity and temperatures, and a containerized one on the proxy's network for
container state. The remaining question is not *where the collector runs* but only how
narrowly each of the two can be scoped, and both scope down cleanly: the host side needs
no container escape hatches, and the container side needs no socket mount and no
capability.

## How both decisions resolved

**Decision 1 went to MQTT**, not on flexibility grounds but because the verification
above removed the alternative: the polled-agent option cannot produce a per-container
entity at all, and 28 services' worth of entities are not worth hand-declaring. The
deciding property was automatic entity discovery.

**The broker is the Mosquitto add-on on the HA box, not a service in this stack.** That
placement is what makes "adds a broker the fleet doesn't have" an acceptable cost: it is
supervisor-managed and inside HA's own backups, so it is close to free to own. It also
behaves better on failure — helium dying leaves the broker alive to carry a last-will,
whereas a broker hosted on helium would die with the thing it is meant to report on. The
trade accepted knowingly: the add-on, its dedicated MQTT login, and the HA-side config
entry are the one part of this slice Ansible does not manage.

**Decision 2 resolved to "both, because it was never a choice"** — see the reasoning
above. The host publisher is a one-shot systemd timer rather than a daemon, so there is
no long-lived process to supervise; availability comes from an expiry window on each
entity instead of a last-will, which a one-shot process could never fire.

One consequence worth recording for whoever builds on this: the container publisher
registers ten per-container metric sensors whether or not it is collecting them, so the
entity count is set by the tool, not by this slice's scope. They are collecting real
data rather than sitting empty, and the high-churn counters are kept out of HA's
database rather than out of HA.

Adjacent to `issues/013` (storage-timer failure alerting): if HA becomes the metrics
sink, HA also becomes a plausible notification channel, which partly pre-empts 013's
open decision between ntfy / healthchecks / msmtp. Neither slice closes the other,
but whichever lands first constrains the other's answer — decide them with one eye
on each. No hard dependency either way.

Scoped from a 2026-07-26 session that audited both sides and stopped at the finding
that there was no substrate to integrate against.

## Acceptance criteria

- [x] helium host vitals (at minimum CPU, memory, uptime) are live HA entities with
      sane units and correct device classes.
- [x] Storage capacity for the HDD pool and the SSD tier are live HA entities,
      reporting figures that match what the host itself reports. Verified against
      `df` on all three filesystems: every figure agrees to the published decimal.
- [x] Per-drive temperatures for the pool drives are live HA entities, and board/CPU
      temperatures are too — whether that takes one collector or two. All seven
      drives report, plus SMART pass/fail per drive, which came free in the same call.
- [x] Container liveness for the stack's services is visible in HA — a service
      stopped by hand is reflected in HA within one poll interval. Measured: a
      stopped container flipped its state entity inside 12 s, and back on restart.
      Caveat worth knowing: the separate *health* entity does not clear when a
      container stops, so **state** is the liveness signal, not health.
- [~] The entities survive a helium reboot and an HA restart without manual
      re-adding, and recover on their own after helium is unreachable for a while.
      **Two of three halves verified; the reboot is not.** HA was restarted for real
      (its log stream begins at the restart) and every entity came back on its own
      with no re-adding. Recovery was measured by stopping the host publisher: the
      host entities flipped to `unavailable` exactly 300 s after the last publish —
      to the second — and repopulated on the next tick. The helium reboot itself was
      deliberately NOT triggered, since rebooting the box that runs the whole stack
      is the user's call, not a test to run unasked; the mechanism is in place
      (publisher timer enabled at boot, container on `restart: unless-stopped`).
- [x] Whatever runs on helium is applied by Ansible from krypton, idempotently, and
      holds the non-root / least-privilege posture of `issues/010` — verified by a
      second run reporting no changes. Second run: `changed=0`.
- [x] Any new listening port stays inside the intended LAN + mesh boundary; nothing
      new is published to the internet. Stronger than required, as it turned out:
      the slice adds **no listening port at all**. Both publishers are outbound-only
      MQTT clients, and the host's listening set is byte-for-byte what it was before.
- [x] Container metrics are sourced through the existing read-only socket proxy on
      the `socket_proxy` network — nothing in the slice mounts the raw Docker socket
      or adds a capability to reach it. Verified on the running container: zero
      mounts, `cap_drop:[ALL]` with nothing added, non-root uid, no port bindings,
      and the proxy still refuses the image endpoints.
