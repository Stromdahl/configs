# Task 011 — Data tier: btrfs raid1 SSD mirror with nodatacow scratch subvolumes

**Source issue:** `issues/011-data-tier-btrfs-raid1.md` — build the hot/precious
data tier: the two 480 GB Kingston SATA SSDs as a **btrfs raid1** mirror, with
precious subvolumes (appdata, Immich, Paperless) keeping CoW + checksums and
scratch subvolumes (downloads, transcode) set nodatacow. Built by an idempotent
Ansible storage role run from krypton.

## Pickup protocol

The repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/011` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** all acceptance criteria below before committing the code; only then
   commit (atomic). If a check fails and you can't fix it in scope, leave it
   uncommitted, report, stop — issue stays in-progress.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag it on the **issue** and stop.

Two acceptance criteria (reboot survival, simulated drive-loss) need the user's
hands — see **Human steps**. Do the automatable role first; mark the issue
`blocked` with a note when you reach the manual checks if the user isn't present.

## Suggested agent

**Sonnet** — the role is mechanical now that this brief pins the device ids,
mount scheme, and idempotency guards. **Caveat:** the wipe + `mkfs.btrfs` steps
are *destructive*. Before the first real run, re-confirm the two `ata-*` symlinks
still resolve to the Kingston SSDs (Step 0) — never let mkfs touch the NVMe boot
drive or the 4 SAS HDDs.

## Human steps / blockers

- **AC: reboot survival** — needs a human to `sudo reboot` helium and confirm the
  pool re-mounts. (Trivial, but a deliberate action; helium is a remote box.)
- **AC: simulated single-drive loss** — needs a human at the console: either pull
  one SSD physically, or `echo 1 > /sys/block/sdX/device/delete` to offline it,
  then mount `-o degraded` and confirm data is intact. If degraded mount fails,
  recovery needs console access — don't attempt this remotely-unattended. Note
  `btrfs device delete` is **not** a failure simulation (it only works while the
  device is present).
- Physical install of both SSDs is **already done** (per the issue, 2026-06-29).

## Decisions baked in (read before coding)

- **Identifiers — `ata-*`, never `wwn-*`.** Both SSDs share an identical malformed
  WWN (NAA=0, Kingston UV400 firmware bug); `ls -l /dev/disk/by-id/ | grep -i kingston`
  confirms **no `wwn-*` link exists for them** (the `wwn-0x5000cca2…` links are the
  SAS HDDs). Use these exact symlinks for `mkfs`, smartd, and the replacement
  runbook:
  - `ata-KINGSTON_SUV400S37480G_50026B767400167E` (currently `sde`)
  - `ata-KINGSTON_SUV400S37480G_50026B776705BF4D` (currently `sdf`)
- **fstab mount source = `UUID=<btrfs-fs-uuid>`, not a device id.** A multi-device
  raid1 mounted by one member's path can't mount if *that* member is the dead one —
  which defeats AC "survives single-drive loss". The filesystem UUID is
  device-agnostic and is the correct multi-device-btrfs mount source. This does
  **not** violate the issue's "use ata-*" rule: that rule is about *disk identity*
  (mkfs / smartd / runbook), where ata-* is still used. Capture the fs UUID from
  `blkid` after mkfs and template it into fstab.
- **Both SSDs currently hold old ext4 OS partitions** (sde = an old helium attempt,
  sdf = neon's old root) — they are **not blank**. First run must `sgdisk --zap-all`
  both before mkfs. The wipe/mkfs guard keys on "no btrfs present yet", so existing
  ext4 must not block the wipe on first run (but must prevent re-wipe afterward).
- **`btrfs-progs` is not installed** — candidate `6.14-1` (trixie/main). Install it
  first.
- **`chattr +C` ordering:** it only takes effect on an **empty** directory (not
  retroactive). Create subvolume → mount it (with `nodatacow` opt) → `chattr +C`
  while empty → only then is any data written. Belt-and-suspenders: the `nodatacow`
  mount option covers new allocations; `chattr +C` sets the NODATASUM inode flag.

## Entry points (create — grep-stable)

New role **`ansible/roles/storage_ssd/`** (establishes the `storage_<tier>`
namespace; issue 003 adds the sibling `storage_hdd`). Mirror `roles/base` layout:

```
ansible/roles/storage_ssd/
  meta/main.yml          # copy the galaxy_info block shape from roles/base/meta/main.yml
  tasks/main.yml         # ansible.builtin.import_tasks chain (mirror roles/base/tasks/main.yml)
  tasks/packages.yml     # install btrfs-progs (ansible.builtin.apt, state: present)
  tasks/filesystem.yml   # zap + mkfs.btrfs raid1, guarded by existing-fs detection
  tasks/subvolumes.yml   # create subvols; chattr +C on scratch (correct ordering)
  tasks/mounts.yml       # ansible.posix.mount per subvol, by UUID=, with per-subvol opts
```

Wire into **`ansible/site.yml`** — add to the `roles:` block after
`geerlingguy.docker` (grep `tags: [docker]`):
```yaml
    - role: storage_ssd
      tags: [storage, storage_ssd]
```

Add variables to **`ansible/host_vars/helium/vars.yml`**:
```yaml
ssd_pool_mount: /data/ssd
ssd_pool_label: helium-ssd
ssd_devices:
  - /dev/disk/by-id/ata-KINGSTON_SUV400S37480G_50026B767400167E
  - /dev/disk/by-id/ata-KINGSTON_SUV400S37480G_50026B776705BF4D
ssd_subvolumes_precious: [appdata, immich, paperless]
ssd_subvolumes_scratch:  [downloads, transcode]
```

## Mount / subvolume scheme

- Pool mount root: **`/data/ssd`** (leaves `/data/hdd` for issue 003's mergerfs union).
- Subvolumes (btrfs `@`-prefix convention), each mounted at `/data/ssd/<name>`:
  - **Precious** (default CoW + checksums): `@appdata`, `@immich`, `@paperless`
  - **Scratch** (`nodatacow` mount opt + `chattr +C`): `@downloads`, `@transcode`
- fstab: one entry per subvolume, source `UUID=<fs-uuid>`, options
  `subvol=@<name>,noatime,nofail` (+ `,nodatacow` for scratch). `nofail` so a
  missing pool doesn't wedge boot; degraded recovery is manual (see Human steps).

## Prior art to mirror

- `ansible/roles/base/tasks/main.yml` — the `ansible.builtin.import_tasks` chain +
  `become: true` per block style.
- `ansible/roles/base/tasks/unattended-upgrades.yml` — `ansible.builtin.apt` /
  `systemd_service` / `copy` idioms.
- `ansible/roles/base/meta/main.yml` — galaxy_info block (Debian/trixie, deps []).
- Module choices: `ansible.builtin.apt`; `ansible.builtin.command`/`shell` with
  `creates:`/`when:` guards for the btrfs/sgdisk/chattr ops; **`ansible.posix.mount`**
  (fully-qualified) for fstab+mount; `ansible.builtin.file` for dirs.

## Steps

0. **Re-confirm device ids** (safety): `ansible nas -m shell -a 'ls -l /dev/disk/by-id/ | grep -i kingston; lsblk -o NAME,SIZE,MODEL,SERIAL'` — the two serials above must still map to the two Kingston SSDs. Abort if not.
1. `packages.yml` — install `btrfs-progs`.
2. `filesystem.yml` — detect existing pool: `btrfs filesystem show <dev0>` (register, `failed_when: false`, `changed_when: false`). When **not** already btrfs: `sgdisk --zap-all` each device, then `mkfs.btrfs -L {{ ssd_pool_label }} -m raid1 -d raid1 {{ ssd_devices | join(' ') }}`. Then capture the fs UUID (`blkid -s UUID -o value <dev0>`) into a fact for fstab.
3. `subvolumes.yml` — mount pool top-level (`subvolid=5`) at a temp mount; create each subvolume (`btrfs subvolume create`, guarded by `btrfs subvolume list`); unmount temp.
4. `mounts.yml` — create `/data/ssd/<name>` dirs; `ansible.posix.mount state: mounted` per subvol by `UUID=`, with the per-subvol options above. For each scratch dir, `chattr +C` **after** mount while empty (guard: `lsattr -d` shows no `C` yet, else `changed_when: false`).
5. Wire role into `site.yml`; run `ansible-playbook site.yml --tags storage_ssd` from krypton.

## Verify

(AC #1 — SSDs healthy/enumerate — already done per the issue.)

- **raid1 spans both:** `ansible nas -b -m shell -a 'btrfs filesystem show /data/ssd; btrfs fi df /data/ssd'` → label `helium-ssd`, **two** devices, `Data: RAID1` + `Metadata: RAID1`.
- **nodatacow correct:** `ansible nas -b -m shell -a 'lsattr -d /data/ssd/downloads /data/ssd/transcode /data/ssd/appdata /data/ssd/immich /data/ssd/paperless'` → scratch dirs show `C`, precious dirs do **not**. And `findmnt -o TARGET,OPTIONS /data/ssd/downloads` shows `nodatacow`.
- **idempotent:** `ansible-playbook site.yml --tags storage_ssd` a second time → `changed=0` (no re-wipe, no re-mkfs, no re-create).
- **reboot survival (human):** after `sudo reboot`, `findmnt /data/ssd/appdata` mounted; `btrfs filesystem show /data/ssd` still two devices.
- **single-drive loss (human, console):** offline one SSD, `mount -o degraded` → pool mounts, files intact; re-add + `btrfs balance start -dconvert=raid1 -mconvert=raid1`.

## Acceptance criteria (from issue 011, verbatim)

- [x] Both SSDs are healthy under smartctl and enumerate. **Done 2026-06-29.**
- [ ] A btrfs raid1 filesystem spans both SSDs and survives a reboot, mounted at a stable location.
- [ ] Precious subvolumes (appdata, Immich, Paperless) carry full CoW + checksums; the scratch subvolumes (downloads, transcode cache) are nodatacow (`chattr +C` confirmed) and excluded from checksumming.
- [ ] A simulated single-drive loss is survived with data intact (mirror degrades, not fails).
- [ ] The tier is built by an idempotent Ansible storage role run from krypton.

## Out of scope / don't touch

- `/dev/sda`–`/dev/sdd` (4 SAS HDDs — issue 003) and `/dev/nvme0n1` (boot OS, `/` + `/boot/efi`). No task may reference them.
- Service stacks / data migration onto the tier (later issues).
- Do not put `degraded` permanently in fstab (masks faults / risks degraded writes) — degraded mount is a manual recovery action.
