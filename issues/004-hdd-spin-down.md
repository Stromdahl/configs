---
title: HDD spin-down so idle drives stay quiet and cool
status: done
priority: medium
created: 2026-06-27
closed: 2026-07-03
labels: [epic:storage, needs-human]
---

## Description

Make the spinners sleep when nothing needs them. These are SAS drives, so
spin-down is driven by **sdparm/sg3utils standby timers** (not `hdparm`), applied
persistently via the SAS-tools role and a systemd mechanism. Treat actual
spin-down as a best-effort bonus on top of the architecture that already keeps the
disks idle (hot data lives on the SSD tier; the pool is touched only by library
reads and the nightly SnapRAID sync) — kernel/SMART polling can wake SAS drives,
so guard against avoidable wake-ups.

The verifiable outcome: with no active stream, the drives reach standby; starting a
single playback wakes only the one disk holding that title, leaving the other data
drive and both parity drives asleep.

Depends on `issues/003` (pool must exist before spin-down behavior is meaningful).

## Acceptance criteria

- [x] Standby timers are applied to all four SAS drives and persist across reboot.
- [ ] After an idle period with no streams, all four drives report standby.
- [ ] Starting a single stream wakes exactly one data drive; the other data drive
      and both parity drives remain in standby.
- [ ] The nightly SnapRAID sync wakes the drives on schedule and they return to
      standby afterward.
- [x] Routine monitoring/SMART polling does not keep the drives spinning.

<!-- AC2/AC3/AC4 (drives actually reaching standby) are NOT met — hardware limitation, see Resolution. -->

## Resolution (2026-07-03) — spin-down not achievable on this HBA; closed best-effort

Standby config is deployed + persistent (**AC1 ✓**): `STANDBY_Z=1`, `SZCT=12000` (20 min)
saved to firmware on all 4 drives, re-applied each boot; smartd pinned to `-n standby` with
no other poller (**AC5 ✓**). **But the drives never reach standby (AC2/AC3/AC4 not met) — a
hardware limitation, not a config or poller problem.** The Broadcom/LSI **SAS3008** HBA +
these HPE MB012000JWDFD enterprise SAS drives accept every spin-down command (`rc=0`) yet keep
the platters spinning — verified across 24 min of genuine idle (zero block I/O), `sdparm
--command=stop`, `sg_start --pc=3`, `sg_start --stop`, and under `PM_BG=1`. No userspace poller
exists (smartd polls every 30 min with `-n standby`; multipathd off; no metrics agents).

Closed under the issue's own "best-effort bonus" framing: the deliverable (correct, persistent
config) shipped; the outcome is hardware-blocked. Config kept — harmless, documents intent, and
the firmware-default `IDLE_A` (2 s head-unload) still trims noise/wear. Quiet/cool (PRD goal #2)
therefore rests on the architecture (hot data on SSD; HDD pool touched only by reads + the
nightly sync) + HBA cooling, not platter spin-down. Full probe in `hosts/helium/BUILD-LOG.md`.
