---
title: HDD spin-down so idle drives stay quiet and cool
status: open
priority: medium
created: 2026-06-27
closed: null
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

- [ ] Standby timers are applied to all four SAS drives and persist across reboot.
- [ ] After an idle period with no streams, all four drives report standby.
- [ ] Starting a single stream wakes exactly one data drive; the other data drive
      and both parity drives remain in standby.
- [ ] The nightly SnapRAID sync wakes the drives on schedule and they return to
      standby afterward.
- [ ] Routine monitoring/SMART polling does not keep the drives spinning.
