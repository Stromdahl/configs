---
title: Provision neon bare-metal as the Debian gaming desktop (GPU swap, install, library restore)
status: open
priority: high
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:task, needs-human]
---

## Description

The physical, on-the-metal step that turns the decided plan into a running rig. This
is the human-hands ticket — GPU swap, OS install, and library restore — done at the
desk where the box now lives.

Order of operations, drawn from the resolved decisions:

1. **Preserve first.** Back up the **203 GB Steam library** from the NVMe to helium
   over the gigabit LAN (the drive is a raw-ext4 data volume — see `issues/033`).
   Verify the copy is complete and restorable **before** touching the disk. The 1.5 TB
   of old Jellyfin/*arr media on the same drive is disposable (confirmed).
2. **Swap the GPU.** Pull the GTX 1070, seat the RTX 2060 (ASUS TUF, 6 GB — the
   ex-titan-100 card, per `issues/032`).
3. **Wipe + partition + install.** Fresh GPT on `nvme0n1` per `issues/033`: ESP /
   ~150 GB OS (ext4) / ~1.85 TB games (ext4). Install Debian 13, single-boot.
4. **Apply the profile.** Bootstrap dotfiles and apply neon's gaming-desktop profile
   from `issues/035` (KDE, `nvidia`, `steam`, …).
5. **Restore the library.** Copy the Steam library back onto the games partition and
   register it as a Steam library folder so the games show installed without a
   re-download.

Depends on `issues/035` (the gaming profile must exist to apply) and `issues/038`
(the `steam` module `die`s on a couch-less host — must be fixed before step 4 runs it
on the real box), plus the physical RTX 2060 being on hand (`issues/032`; the user has
it). The preservation/partition procedure is specified in `issues/033`; `issues/036`
(repo cleanup) is independent and not a prerequisite.

## Acceptance criteria

- [x] The 203 GB Steam library is backed up to helium and verified restorable **before** the wipe — nothing is lost. **Done 2026-07-11:** `steam/` (126,856 entries, 216,893,659,834 B) rsync'd from the RO-mounted NVMe to `helium:/mnt/disk1/neon-steam-backup/steam`; byte + entry counts match exactly and a `--checksum` content verify returned zero diffs. NVMe is safe to wipe. Restore this copy in the step below (chown to neon's new user; original uid/gid intentionally not preserved). Do **not** delete the helium copy until the restore is verified on the rebuilt box.
- [ ] The RTX 2060 is seated and the 1070 removed; `nvidia-smi` on the installed OS reports the RTX 2060.
- [ ] `nvme0n1` is freshly partitioned ESP / OS / games per `issues/033`; the box boots single-OS Debian 13.
- [ ] neon's gaming-desktop profile applies cleanly on the box (`./install.sh` succeeds); it boots to a KDE desktop and Steam launches.
- [ ] The preserved Steam library is restored on the games partition and Steam lists the games as **installed** (Hogwarts Legacy, Split Fiction, …) without re-downloading.
- [ ] Display runs native 3440×1440 on the 2060 and wired onboard 1 GbE is up.
