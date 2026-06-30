---
title: HDD pool — mergerfs + SnapRAID (2 parity + 2 data) over the HBA
status: done
priority: high
created: 2026-06-27
closed: 2026-06-30
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

- [x] All four SAS drives are healthy under smartctl through the HBA.
- [x] mergerfs presents a single library mount unioning the two data drives, with
      the create policy confirmed to keep writes on one drive until it fills.
- [x] SnapRAID is configured with 2 parity + 2 data; `snapraid sync` completes and
      `snapraid status` reports clean.
- [x] sync (and scrub) run automatically on their systemd timers.
- [x] A simulated data-drive loss is recoverable from parity (fix/restore verified
      on test data).
- [x] The pool re-assembles correctly across a reboot.

## Status (2026-06-29)

`needs-human` — the automatable pool is **built, deployed to helium, and verified**
by the `storage_hdd` Ansible role (commit `a231e25`). ACs 1–4 pass; the playbook is
idempotent (clean re-run = `changed=0`).

- **Done:** ext4 on the 4 `wwn-*` SAS drives, `/mnt/{disk1,disk2,parity1,parity2}`,
  mergerfs union at `/srv/media` (`category.create=lfs`; 200 MB test write landed on
  one drive only), `/etc/snapraid.conf` (2 parity + 2 data, content on both data
  disks + `/var/snapraid`), `snapraid sync` clean, sync/scrub timers `active`.
  The union fstab entry carries `x-systemd.requires=/mnt/disk1,/mnt/disk2` so it
  cannot mount before the data drives at boot (guards AC6).
**Done 2026-06-30 — both manual ACs verified (drills run while the pool was empty,
zero real data at risk):**
- **AC6 reboot reassembly:** rebooted helium; all four `/mnt/{disk1,disk2,parity1,parity2}`
  ext4 mounts + the `/srv/media` mergerfs union returned, both snapraid timers
  `active`, `snapraid status` clean.
- **AC5 parity recovery:** wrote a 50 MB random canary to `disk1`, `snapraid sync`,
  removed it (simulated loss — **no sync between loss and fix**), `snapraid fix -d disk1`
  → 200 errors / 200 recovered / **0 unrecoverable**, restored canary's sha256 matched
  the original byte-for-byte. Cleaned up (`--force-empty sync`); array back to empty +
  `check` clean.
