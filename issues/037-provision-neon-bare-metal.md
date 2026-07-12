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
- [x] The RTX 2060 is seated and the 1070 removed; `nvidia-smi` on the installed OS reports the RTX 2060. **Done 2026-07-12** — RTX 2060 seated, GTX 1070 pulled; post-reboot `nvidia-smi` reports "NVIDIA GeForce RTX 2060", driver 550.163.01.
- [x] `nvme0n1` is freshly partitioned ESP / OS / games per `issues/033`; the box boots single-OS Debian 13. **Done 2026-07-12:** GPT with `nvme0n1p1` ESP (`/boot/efi`), `p2` 140 GB ext4 `/`, `p3` 1.7 TB ext4 `/games`; booted Debian 13 trixie at `192.168.1.165`.
- [x] neon's gaming-desktop profile applies cleanly on the box (`./install.sh` succeeds); it boots to a KDE desktop and Steam launches. **Done 2026-07-12:** all 21 modules succeeded (`base apt-sources locale ssh sshd bash git i386-multiarch nvidia pipewire kde flatpak steam gamepad bluetooth unattended-upgrades gtk userdirs xkb fzf nvim syncthing`); `graphical.target` default, SDDM enabled — post-reboot KDE Plasma session confirmed up (plasmashell + sddm running). Note: the gaming profile lived only on krypton's unpushed `main`; had to push before neon (which clones the public repo) could pull it — the first dry-run applied the stale server profile.
- [~] The preserved Steam library is restored on the games partition and Steam lists the games as **installed** (Hogwarts Legacy, Split Fiction, …) without re-downloading. **Restore done + verified 2026-07-12:** rsync-pulled `helium:/mnt/disk1/neon-steam-backup/steam/` → `/games/` (over gigabit LAN; neon given its own ed25519 key authorized on helium since agent-forwarding wouldn't carry the key; `sudo chown ms:ms /games` first). `--exclude='*.tmp'` dropped 76 stray appmanifest temp files (expected). A size+mtime dry-run diff returned **zero** files to transfer → content complete. **helium copy left intact** until Steam confirms the games list as installed post-login (add `/games` as a Steam library folder).
- [x] Display runs native 3440×1440 on the 2060 and wired onboard 1 GbE is up. **Done 2026-07-12:** HDMI-0 connected primary at 3440×1440; wired `enp0s31f6` up (neon at 192.168.1.165).
- [ ] **zram** configured post-install as the swap cushion — **no swap partition** at install time and **no hibernation** (desktop uses S3 sleep; decided 2026-07-12 for the 16 GB box: zram is compressed in-RAM swap, avoids NVMe wear, and hibernation is low-value + nvidia-resume-flaky here).
