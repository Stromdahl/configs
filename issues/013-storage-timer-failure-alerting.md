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

## Rider from the personal-forge map (2026-08-23)

`planning/personal-forge/issues/12-adopt-runner-shape.md` needed a CI-failure channel
and **deferred it here whole** (owner: *"we don't need this now"*). So this issue now
owns the notification channel for **two** consumers: storage maintenance timers and
Forgejo CI. Nothing in the forge's runner spec blocks on it — per-job commit statuses
on push are free in the Forgejo UI, and CI's use is one additive `if: failure()` step
publishing to whatever channel is picked here.

Facts established while investigating, so they need not be re-derived:

- **HA-MQTT already exists and is the zero-new-service option** — Mosquitto on argon at
  `192.168.1.99:1883`, shipped in `issues/046`, already carrying helium's container and
  SMART metrics into Home Assistant. Its weakness for helium alerts: the verdict travels
  through a second box, so if argon is what is down, you get silence.
- **Forgejo has a first-party opt-in failure email**, but helium has **no SMTP path** —
  taking it means standing up a mailer or handing credentials to an external provider.
- **Forgejo's per-job commit statuses fire only on push.** For scheduled and
  `workflow_dispatch` runs the code path is `default: return nil`, so a nightly run
  would have no in-UI signal at all.
- Open sub-question inherited from the forge map, deliberately unasked so far: **is a
  success heartbeat wanted?** A pipeline broken for a week looks identical to a green
  one if only failures are ever announced — but a heartbeat you learn to ignore is
  worse than nothing.
