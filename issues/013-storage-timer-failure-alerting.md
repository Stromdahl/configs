---
title: Storage health alerting — surface maintenance-timer failures out of band
status: open
priority: medium
created: 2026-06-30
closed: null
labels: [epic:storage]
---

## Description

The unattended storage maintenance timers — the SnapRAID sync + scrub (`issues/003`)
and the btrfs scrub (`issues/012`) — run as `Type=oneshot` units with no failure
surface. If a nightly `snapraid sync` starts failing, parity silently goes stale;
if a `btrfs scrub` finds uncorrectable corruption, nothing announces it. The failure
is discovered only when a recovery you were counting on doesn't work — i.e. at the
worst possible moment.

There is currently **no notification mechanism on the fleet** (no mail / ntfy /
healthchecks). This slice establishes one and wires the storage timers to it via
systemd `OnFailure=`, so a failed or error-reporting maintenance run actively
notifies rather than failing silently. Scope is helium's storage timers first; the
mechanism should be reusable by later services.

**Open decision (blocks implementation):** which channel — a self-hostable
`ntfy` topic, a `healthchecks.io`-style dead-man's-switch (also catches a timer that
*stops firing*, not just one that fails), or plain email via `msmtp`. A
healthchecks-style ping is the strongest fit for periodic maintenance because it
alerts on silence as well as on error.

Depends on `issues/003` and `issues/012` (the timers being monitored).

## Acceptance criteria

- [ ] A failed SnapRAID sync/scrub or btrfs scrub run actively notifies out of band
      (not just a journal entry).
- [ ] The notification fires on a deliberately-induced failure (verified by test).
- [ ] Wired via systemd `OnFailure=` (or equivalent) and applied by the Ansible
      storage roles from krypton, idempotently.
