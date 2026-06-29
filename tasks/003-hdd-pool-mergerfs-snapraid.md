# Task 003 — HDD pool: mergerfs + SnapRAID (2 parity + 2 data) over the HBA

**Source issue:** `issues/003-hdd-pool-mergerfs-snapraid.md` — turn the four 12 TB
SAS drives into the fault-tolerant media pool: each drive an independent ext4
filesystem; **mergerfs** unions the two data drives into one library mount with a
fill-one-drive-at-a-time create policy (small library lands on one disk, others
idle); **SnapRAID** gives 2 parity + 2 data (dual-fault), with `sync`/`scrub` on
systemd timers. Built by an Ansible role; drives referenced by stable ids.

## Pickup protocol

Follow `tasks/README.md` + `issues/README.md`.
1. **Claim:** set `issues/003` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** all acceptance criteria before committing the code; only then commit
   (atomic). If a check fails and you can't fix it in scope, leave it uncommitted,
   report, stop — issue stays in-progress.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag it on the **issue** and stop.

Two acceptance criteria (reboot reassembly, simulated drive-loss recovery) need
the user's hands — see **Human steps**. Build the automatable role + timers first;
flag the issue `blocked` with a note when you reach the manual checks if the user
isn't present.

## Suggested agent

**Sonnet** — mechanical given this brief pins device ids, mount scheme, package
versions, and idempotency guards. **Caveat:** `mkfs.ext4` is destructive — the 4
SAS drives are currently **blank** (no partition table/fs), so first-run formats
them; re-confirm the four `wwn-*` ids in Step 0 and never let mkfs touch the SSDs
(`sde`/`sdf`) or the NVMe boot drive.

## Human steps / blockers

- **AC: pool re-assembles across a reboot** — needs a human to reboot helium (or
  grant explicit permission to `ansible nas -b -m reboot`) and confirm all mounts +
  timers come back. helium is a remote production box.
- **AC: simulated data-drive loss recoverable from parity** — needs a human at the
  console. Do **not** automate a "loss" by `dd`/`wipefs` on a live mounted drive
  (risks real data loss on a mistargeted device). Supervised procedure: write a
  canary into `/srv/media`, `snapraid sync`, simulate loss (unmount + point the
  disk's fstab at a blank path, or physically pull), `snapraid fix -d disk1`, verify
  the canary. Requires explicit human sign-off.
- **Drive role assignment** (which two drives are data vs parity) is a one-time
  decision — the default below (sda/sdb data, sdc/sdd parity) is arbitrary among
  four identical drives; confirm or change before the run.

## Decisions baked in (read before coding)

- **Identifiers — `wwn-*` (valid & unique here, unlike the SSDs).** The 4 SAS HDDs
  expose unique `wwn-0x5000cca2*` symlinks (contrast issue 011, whose Kingston SSDs
  have a poisoned wwn — different tier, different rule). Use these exact ids:
  | role | id | currently |
  |---|---|---|
  | data1  | `wwn-0x5000cca2918cb694` | sda |
  | data2  | `wwn-0x5000cca294541ed4` | sdb |
  | parity1| `wwn-0x5000cca26fc04138` | sdc |
  | parity2| `wwn-0x5000cca2945424c4` | sdd |
- **mergerfs create policy = `lfs` (least free space), NOT `mfs`.** This is the
  load-bearing choice for the "fill one drive, keep others idle" AC and the PRD's
  spin-down goal. `mfs` (most-free-space) *balances* writes across both data drives
  → spins both up → **fails** the AC. `lfs` keeps writing to the most-full drive
  that still has room (respecting `minfreespace`), so disk1 fills before disk2 is
  touched. (`ff` first-found also works; `lfs` additionally honours free space.)
- **Idempotent mkfs via `community.general.filesystem`** (`fstype: ext4`,
  `force: false` default) — it won't reformat a drive that already has a filesystem,
  which is safer than a shell `mkfs` + blkid guard. Add `opts: -m 0 -L disk1` etc.
  (`-m 0` reclaims the ~5% reserved blocks — these are data disks, not system).
- **Format the raw device** (`/dev/disk/by-id/wwn-…`), no partition table — standard
  for snapraid/mergerfs. Drives are 512e (logical 512 / physical 4096); ext4's
  default 4 KiB block size already matches — no special `-b`/stride needed.
- **Don't run the long `snapraid sync` inside the role.** On the empty pool the
  first sync is instant (run it as a verify step); the post-migration full sync
  (~932 GB) is long and belongs to the timer / migration (issue 008), not a
  blocking role task.
- **Packages all in trixie/main** (no backports): `mergerfs 2.40.2-5`,
  `snapraid 12.4-1`, `smartmontools 7.4-3`, `sg3-utils 1.48-2`, `sdparm 1.12-2`,
  `lsscsi 0.32-2`. None installed yet.
- **SAS, not SATA:** `hdparm` does not apply (spin-down = issue 004, uses
  `sdparm`/`sg_start`). smartctl through the LSI 9300-8i (IT-mode) reads natively —
  no `-d` flag, or `-d scsi`; **never `-d sat`**.

## Entry points (create — grep-stable)

New role **`ansible/roles/storage_hdd/`** (sibling to `storage_ssd` from issue 011).
Mirror `roles/base` layout:

```
ansible/roles/storage_hdd/
  meta/main.yml          # copy galaxy_info shape from roles/base/meta/main.yml
  handlers/main.yml      # systemd daemon-reload handler (ansible.builtin.systemd_service)
  tasks/main.yml         # import chain (mirror roles/base/tasks/main.yml)
  tasks/sas_tools.yml    # apt: smartmontools sg3-utils sdparm lsscsi
  tasks/disks.yml        # community.general.filesystem (ext4) on the 4 wwn devices
  tasks/mounts.yml       # ansible.posix.mount data/parity dirs (by-id, nofail)
  tasks/mergerfs.yml     # apt mergerfs + union mount entry (lfs policy)
  tasks/snapraid.yml     # apt snapraid + templated /etc/snapraid.conf
  tasks/timers.yml       # snapraid-sync/scrub .service + .timer units
  templates/snapraid.conf.j2
  files/systemd/         # snapraid-{sync,scrub}.{service,timer}
```

Wire into **`ansible/site.yml`** (`roles:` block, after `geerlingguy.docker` /
`storage_ssd` — grep `tags: [docker]`):
```yaml
    - role: storage_hdd
      tags: [storage, storage_hdd]
```

Add to **`ansible/host_vars/helium/vars.yml`**:
```yaml
hdd_data_drives:
  - { id: "wwn-0x5000cca2918cb694", mount: "/mnt/disk1",   label: "disk1" }
  - { id: "wwn-0x5000cca294541ed4", mount: "/mnt/disk2",   label: "disk2" }
hdd_parity_drives:
  - { id: "wwn-0x5000cca26fc04138", mount: "/mnt/parity1", label: "parity1" }
  - { id: "wwn-0x5000cca2945424c4", mount: "/mnt/parity2", label: "parity2" }
hdd_union_mount: "/srv/media"
hdd_mergerfs_opts: "defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=lfs,moveonenospc=true,minfreespace=50G,fsname=mergerfs"
```

## Mount-point scheme (mergerfs+snapraid convention)

```
/mnt/disk1, /mnt/disk2        ext4 data drives (wwn-* by-id, nofail)
/mnt/parity1, /mnt/parity2    ext4 parity drives (wwn-* by-id, nofail)
/srv/media                    mergerfs union of /mnt/disk1:/mnt/disk2  (Jellyfin library root, issue 008)
/etc/snapraid.conf            snapraid's compiled-in default location
```

fstab data/parity entries use `nofail,x-systemd.device-timeout=5`. The union entry:
`/mnt/disk1:/mnt/disk2  /srv/media  fuse.mergerfs  {{ hdd_mergerfs_opts }}  0 0`.

`snapraid.conf` shape: `parity /mnt/parity1/snapraid.parity`,
`2-parity /mnt/parity2/snapraid.2-parity`; **content files on each data disk plus
the boot drive** (e.g. `/mnt/disk1/.snapraid.content`, `/mnt/disk2/.snapraid.content`,
`/var/snapraid/snapraid.content`) so content survives losing any one disk; `data d1
/mnt/disk1`, `data d2 /mnt/disk2`; sensible `exclude` lines (`*.tmp`, `/lost+found/`,
incomplete-download patterns). snapraid uses the `/mnt/*` paths, not by-id.

## Prior art to mirror

- `ansible/roles/base/tasks/main.yml` — the `ansible.builtin.import_tasks` chain.
- `ansible/roles/base/tasks/sshd.yml` — apt + copy + `notify:` handler idiom.
- `ansible/roles/base/tasks/unattended-upgrades.yml` — multi-file `copy` into `/etc`
  (mirror for dropping the systemd unit files into `/etc/systemd/system/`).
- `ansible/roles/base/handlers/main.yml` — `ansible.builtin.systemd_service` handler
  (use for `daemon_reload` after dropping timer units, and to enable them).
- `ansible/roles/base/meta/main.yml` — meta boilerplate.
- Modules: `ansible.builtin.apt`; **`community.general.filesystem`** (mkfs);
  **`ansible.posix.mount`** (fstab + mount, `state: mounted` — idempotent);
  `ansible.builtin.file` (dirs); `ansible.builtin.template`/`copy`;
  `ansible.builtin.systemd_service`. (mkfs idempotency-guard is a new pattern here —
  `community.general.filesystem` handles it natively, no example to copy.)

## Steps

0. **Re-confirm device ids** (safety): `ansible nas -m shell -a 'ls -l /dev/disk/by-id/ | grep wwn; lsblk -o NAME,SIZE,MODEL,SERIAL'` — the four wwn ids above must map to the four 12 TB HGST/HPE SAS drives, and sde/sdf must remain the Kingston SSDs. Abort if not.
1. `sas_tools.yml` — apt install smartmontools sg3-utils sdparm lsscsi.
2. `disks.yml` — `community.general.filesystem` ext4 on each of the 4 wwn devices (`force: false`, `opts: -m 0 -L <label>`).
3. `mounts.yml` — create the 4 `/mnt/...` dirs; `ansible.posix.mount state: mounted` per drive (by-id, ext4, `nofail,x-systemd.device-timeout=5`).
4. `mergerfs.yml` — apt install mergerfs; `ansible.posix.mount` the union (`fuse.mergerfs`, src `/mnt/disk1:/mnt/disk2`, opts `{{ hdd_mergerfs_opts }}`, `state: mounted`).
5. `snapraid.yml` — apt install snapraid; template `/etc/snapraid.conf` (2 parity, 2 data, content files as above); create `/var/snapraid`.
6. `timers.yml` — drop `snapraid-sync.{service,timer}` (sync `OnCalendar=*-*-* 03:00`) and `snapraid-scrub.{service,timer}` (weekly, e.g. `scrub -p 8 -o 10`); `daemon_reload`; enable both timers (not the services).
7. Wire role into `site.yml`; run `ansible-playbook site.yml --tags storage_hdd`.

## Verify

- **AC1 — smartctl health (all 4):** `ansible nas -b -m shell -a 'for d in sda sdb sdc sdd; do smartctl -H /dev/$d; done'` → each "SMART overall-health … PASSED" (retry `-d scsi` if needed).
- **AC2 — single union, fill-one create policy:** `ansible nas -b -m shell -a 'findmnt /srv/media; cat /proc/mounts | grep mergerfs'` shows the union with `category.create=lfs`. Then `dd if=/dev/zero of=/srv/media/t.bin bs=1M count=200 && ls -la /mnt/disk1/t.bin /mnt/disk2/t.bin 2>&1; rm /srv/media/t.bin` → file is on **disk1 only**, absent on disk2.
- **AC3 — snapraid sync + status clean:** `ansible nas -b -m shell -a 'snapraid sync && snapraid status'` (instant on empty pool) → sync exits 0; status reports no errors / "No sync is needed".
- **AC4 — timers active:** `ansible nas -b -m shell -a 'systemctl list-timers snapraid-sync.timer snapraid-scrub.timer'` → both `active (waiting)` with a next-trigger time.
- **AC5 — parity recovery (human, see Human steps):** canary survives a simulated data-drive loss via `snapraid fix`.
- **AC6 — reboot reassembly (human):** after reboot, `findmnt /mnt/disk1 /mnt/disk2 /mnt/parity1 /mnt/parity2 /srv/media` all mounted; `systemctl is-active snapraid-sync.timer snapraid-scrub.timer` active; `snapraid status` clean.

## Acceptance criteria (from issue 003, verbatim)

- [ ] All four SAS drives are healthy under smartctl through the HBA.
- [ ] mergerfs presents a single library mount unioning the two data drives, with the create policy confirmed to keep writes on one drive until it fills.
- [ ] SnapRAID is configured with 2 parity + 2 data; `snapraid sync` completes and `snapraid status` reports clean.
- [ ] sync (and scrub) run automatically on their systemd timers.
- [ ] A simulated data-drive loss is recoverable from parity (fix/restore verified on test data).
- [ ] The pool re-assembles correctly across a reboot.

## Out of scope / don't touch

- `/dev/sde`, `/dev/sdf` (Kingston SSDs — issue 011) and `/dev/nvme0n1` (boot OS).
  No task may reference them.
- **HDD spin-down — issue 004.** This role installs the SAS *tooling*
  (`sdparm`/`sg3-utils`) but configures **no** spin-down timers/policy.
- Media library migration + Jellyfin pointing at `/srv/media` — issues 008 / 005.
