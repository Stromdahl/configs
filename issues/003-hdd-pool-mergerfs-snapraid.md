---
title: HDD pool — mergerfs + SnapRAID (2 parity + 2 data) over the HBA
status: in-progress
priority: high
created: 2026-06-27
closed: null
labels: [epic:storage]
---

## Description

Turn the four 12 TB SAS drives into the fault-tolerant media pool. Each drive is
an independent filesystem; **mergerfs** unions the two data drives into a single
library mount using a fill-one-drive-at-a-time create policy (so a small library
lands on one disk, which keeps the others idle). **SnapRAID** provides
**2 parity + 2 data** (dual-fault tolerance — the right call for used enterprise
drives of mixed age), with scheduled `sync` and periodic `scrub` via systemd
timers (e.g. nightly sync ~03:00).

Includes an Ansible role for the SAS tooling (sdparm/sg3utils/smartctl/lsscsi),
the mergerfs install + mount, and the snapraid config + timers. Drives should be
referenced by stable identifiers so pool membership survives reboots and
re-cabling.

Depends on `issues/002` (Ansible foundation + a configured host).

**Manual verification (human hands):** two acceptance criteria can't be completed
by the Ansible run alone — *reboot reassembly* (a human reboots helium and confirms
all mounts + timers return) and *simulated data-drive loss recovery* (a human
simulates the loss at the console and verifies `snapraid fix` restores a canary
from parity). Building the pool + timers is fully automatable from krypton. Briefed
in `tasks/003`.

## Acceptance criteria

- [ ] All four SAS drives are healthy under smartctl through the HBA.
- [ ] mergerfs presents a single library mount unioning the two data drives, with
      the create policy confirmed to keep writes on one drive until it fills.
- [ ] SnapRAID is configured with 2 parity + 2 data; `snapraid sync` completes and
      `snapraid status` reports clean.
- [ ] sync (and scrub) run automatically on their systemd timers.
- [ ] A simulated data-drive loss is recoverable from parity (fix/restore verified
      on test data).
- [ ] The pool re-assembles correctly across a reboot.
