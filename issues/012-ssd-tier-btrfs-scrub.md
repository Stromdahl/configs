---
title: SSD tier — scheduled btrfs scrub for bit-rot detection/repair
status: in-progress
priority: medium
created: 2026-06-30
closed: null
labels: [epic:storage]
---

## Description

The SSD data tier (`issues/011`) is a btrfs raid1 mirror chosen specifically for
data checksumming — the board is non-ECC, so btrfs checksums are the line of
defence against silent bit-rot on the precious tier (Docker appdata, Immich,
Paperless). But checksums are only verified when a block is *read*. Without a
periodic `btrfs scrub`, a bit-flip in cold data goes undetected, and raid1 never
proactively rewrites the bad copy from its good mirror — so the protection that
justified choosing btrfs is never exercised in the background.

The HDD pool already runs a periodic SnapRAID scrub on a systemd timer; the SSD
tier — the more precious of the two — has no equivalent. Add a scheduled
`btrfs scrub` over the whole `helium-ssd` filesystem (read-only verify; auto-repairs
the bad copy from the good mirror on a raid1 mismatch), on a systemd timer, at low
IO priority, scheduled off the SnapRAID windows.

Built by the `storage_ssd` Ansible role, idempotent like the rest of the tier.

Surfacing a *failed* or error-reporting scrub run out of band (rather than just a
journal entry) is tracked separately in `issues/013`.

Depends on `issues/011` (the btrfs raid1 mirror this scrubs).

## Acceptance criteria

- [ ] A `btrfs scrub` runs the whole `helium-ssd` filesystem on a recurring systemd
      timer (monthly), at low IO priority, and does not run if the pool is unmounted.
- [ ] The scrub timer is enabled and survives a reboot.
- [ ] A scrub on the healthy pool completes with 0 uncorrectable errors.
- [ ] Built by the idempotent `storage_ssd` role from krypton (clean re-run =
      `changed=0`).
