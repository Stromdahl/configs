# Task 004 — HDD spin-down so idle SAS drives stay quiet and cool

**Source issue:** `issues/004-hdd-spin-down.md` — make the four 12 TB SAS drives
reach **standby** when idle, via **sdparm** standby/idle timers (SAS, *not*
`hdparm`), applied persistently through the existing `storage_hdd` role plus a
boot-time systemd mechanism, while guarding against avoidable wake-ups (SMART
polling). Extends — does not replace — the in-progress HDD-pool role.

> **Depends on `issues/003` (HDD pool), which is still `in-progress`.** Spin-down
> is only meaningful once the pool exists and carries media. **Do not grab this
> until `issues/003` is `done`.** The role you extend (`storage_hdd`) is being
> built under 003 right now — its files may move under you; grep the anchors,
> don't trust any remembered layout.

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/004` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** the acceptance criteria below before committing the code; only then
   commit (atomic). If a check fails and you can't fix it in scope, leave it
   uncommitted, report, stop — issue stays in-progress.
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag it on the **issue** and stop.

Most of this issue's acceptance criteria are **observational on the physical box
over time** and need 003 done first — see **Human steps**. Build the automatable
role parts, then hand the observational checks to the user (the issue already
carries `needs-human`).

## Suggested agent

**Sonnet** — extending an existing Ansible role is mechanical once this brief pins
the entry points and patterns. **Two caveats that need care, not horsepower:**
- The exact **sdparm flag names, mode-page fields, and timer units are UNVERIFIED**
  below — confirm them against `man sdparm` / `sdparm --enumerate` *on helium*
  before writing the task (Step 1). SAS power mode pages vary by firmware.
- `--save` writes to **drive firmware**. It is not destructive (it sets a power
  timer, not data), but verify you are addressing the four SAS drives and never a
  wrong device. Resolve by **wwn-\*** every time (Step 2).

## Human steps / blockers

The issue carries `needs-human` because most ACs can only be confirmed by
observing the live box, and 003 must be done first:
- **AC: drives reach standby after an idle period** — needs a human (or a long
  unattended wait) to leave the pool idle, then read power state. Can't be
  meaningfully verified in a playbook run.
- **AC: starting one stream wakes exactly one data drive; the other data drive +
  both parity stay asleep** — needs a real playback against migrated media
  (depends on `issues/008` library migration too) and observation of all four
  drives' power state. Hardware/manual.
- **AC: nightly SnapRAID sync wakes the drives then they re-sleep** — needs to
  observe across a real `snapraid-sync.timer` firing (003's timer) and the
  following idle window.
- Build the role parts an agent *can* do (apply the timers idempotently, install
  the boot service + smartd guard), then mark the issue and report which ACs are
  left for the user to observe. Don't fabricate "verified" on the observational ACs.

## Decisions baked in (read before coding)

- **SAS, so sdparm — never `hdparm`.** `hdparm -S` is ATA-only; these drives sit
  behind the LSI 9300-8i HBA in IT mode and take SAS Power Condition mode-page
  timers via `sdparm`. The tooling (`sdparm`, `sg3-utils`, `smartmontools`,
  `lsscsi`) is **already installed** by `storage_hdd/tasks/sas_tools.yml` — do
  **not** re-install it; that file's header explicitly defers the *policy* to this
  issue.
- **Device addressing: resolve `wwn-*` → `/dev/sg*` dynamically, every time.**
  `sdparm` operates on the SCSI generic char device (`/dev/sg*`), and sg-numbering
  is **not stable across reboots** — so neither the Ansible task nor the boot
  service may hardcode `/dev/sg0..3`. Resolve from the stable `wwn-*` by-id links
  (the same `hdd_data_drives` + `hdd_parity_drives` ids in `host_vars`) via
  `lsscsi --generic` (or `/sys` walk) at run time. Apply to **all four** drives —
  the two parity drives must sleep too (an AC names them).
- **Two-layer persistence (matches the issue's "role *and* a systemd mechanism").**
  (a) The Ansible task applies the timers with `sdparm --save` (firmware-persistent
  *where the drive honors it*). (b) A boot-time `oneshot` systemd service
  re-applies them on every boot — belt-and-suspenders, since `--save` honoring
  varies by firmware and sg-numbers shift. The service runs a **templated** script
  (it needs the wwn list), the unit file itself is static.
- **smartd is the SMART-polling guard, and it is configured NOWHERE yet.**
  `smartmontools` is installed but no `smartd.conf` / enabled `smartd` exists in
  any role (checked base, storage_hdd, storage_ssd, issue 013). For the AC
  "routine monitoring/SMART polling does not keep the drives spinning," drop a
  `smartd.conf` whose device lines carry **`-n standby`** (poll-skips a drive
  that's asleep). **Scope call to confirm:** *enabling* the smartd daemon belongs
  to the monitoring/alerting track (`issues/013`), which doesn't touch smartd yet.
  Recommended split: 004 owns the spin-down-safe `smartd.conf` content (`-n
  standby`) so monitoring can't regress spin-down; 013 owns turning the daemon on.
  If you enable smartd here, it **must** be with `-n standby`. State which you did
  in the close note.

## Entry points (extend — grep-stable)

Extend the existing role **`ansible/roles/storage_hdd/`**. Add:

```
ansible/roles/storage_hdd/
  tasks/spin_down.yml            # NEW: resolve wwn→sg, apply sdparm timers (--save), install + enable boot service, drop smartd.conf guard
  templates/hdd-spin-down.sh.j2  # NEW: loops hdd_data_drives + hdd_parity_drives, resolves each wwn→/dev/sg*, runs sdparm
  files/systemd/hdd-spin-down.service  # NEW: Type=oneshot calling the script; WantedBy=multi-user.target
  templates/smartd.conf.j2       # NEW (or files/smartd.conf): device lines with `-n standby` (see Decisions)
```

- Wire the new task into the role's import chain: edit
  **`ansible/roles/storage_hdd/tasks/main.yml`** and add an
  `ansible.builtin.import_tasks: spin_down.yml` entry **after** the
  `import_tasks: timers.yml` line (grep `timers.yml`).
- Add tunables to **`ansible/host_vars/helium/vars.yml`** (grep `hdd_mergerfs_opts`
  to find the storage_hdd block; append after it), e.g.:
  ```yaml
  # storage_hdd spin-down (issue 004): SAS Power Condition timers, units = 100 ms.
  # CONFIRM field names/units against `man sdparm` before trusting these.
  hdd_idle_a_timer: 6000       # e.g. IDLE_A → ~10 min  (verify unit!)
  hdd_standby_z_timer: 12000   # e.g. STANDBY_Z → ~20 min (verify unit!)
  ```
- The role is **already wired into `ansible/site.yml`** under
  `tags: [storage, storage_hdd]` (grep `storage_hdd`). **No `site.yml` change and
  no new role** — confirm before adding anything.

## Prior art to mirror

- **`ansible/roles/storage_hdd/tasks/timers.yml`** — the canonical idiom for this
  repo: `ansible.builtin.copy` a static unit from `files/systemd/` →
  `notify: Reload systemd` → `ansible.builtin.meta: flush_handlers` →
  `ansible.builtin.systemd_service` (`enabled: true`). Mirror it exactly for the
  spin-down oneshot service.
- **`ansible/roles/storage_hdd/handlers/main.yml`** — already defines the
  `Reload systemd` handler; reuse it, don't add another.
- **`ansible/roles/storage_hdd/files/systemd/snapraid-sync.service`** — the static
  unit shape (`Type=oneshot`, `[Install] WantedBy=`) to copy for
  `hdd-spin-down.service`.
- **`ansible/roles/storage_hdd/templates/snapraid.conf.j2`** — how this role
  templates a config from host_vars; mirror for `hdd-spin-down.sh.j2` and the
  smartd config.
- **`ansible/roles/storage_hdd/tasks/sas_tools.yml`** — confirms the tooling is
  already present; idiom for `become`/`apt`. Do not duplicate its installs.
- Guard idioms: `ansible.builtin.command`/`shell` with `creates:` / `changed_when`
  / `register` + `failed_when: false` for the resolve+apply steps so a clean second
  run reports `changed=0` (mirror `storage_hdd/tasks/disks.yml`'s guard style).

## Steps

0. **Don't start until `issues/003` is `done`** (the role you extend is mid-build).
1. **Confirm sdparm reality on the box first** (the brief's flag names are
   unverified): `ansible nas -b -m shell -a 'man sdparm | sed -n "1,120p"; sdparm --enumerate | grep -iE "idle|standby|pc "'` — pin the exact field names
   (`IDLE_A` / `STANDBY_Z` / `SCT` …), their **units**, and the read/set/save flags.
   Adjust the var names/values accordingly.
2. **Write `templates/hdd-spin-down.sh.j2`** — loop over
   `hdd_data_drives + hdd_parity_drives`; for each `.id` (a `wwn-*` link under
   `/dev/disk/by-id/`), resolve to `/dev/sg*` (`lsscsi --generic` match on the
   resolved `/dev/sd*`), then run the confirmed `sdparm --set=... --save /dev/sgN`.
   `set -euo pipefail`; skip+log a drive that doesn't resolve rather than failing
   the boot.
3. **Write `files/systemd/hdd-spin-down.service`** — `Type=oneshot`,
   `ExecStart=/usr/local/sbin/hdd-spin-down.sh`, `[Install] WantedBy=multi-user.target`.
4. **Write `tasks/spin_down.yml`** — (a) template the script to
   `/usr/local/sbin/hdd-spin-down.sh` (`mode: 0755`); (b) `copy` the unit →
   `notify: Reload systemd` → `flush_handlers` → `systemd_service enabled: true`,
   then run it once (`state: started` for a oneshot applies immediately); (c) apply
   the timers now via the same script / sdparm so the first run takes effect without
   a reboot; (d) template the spin-down-safe `smartd.conf` (`-n standby`) per the
   Decisions scope call.
5. **Import `spin_down.yml`** in `tasks/main.yml` after `timers.yml`.
6. **Add the tunables** to `host_vars/helium/vars.yml`.
7. Run `cd ansible && ansible-playbook site.yml --tags storage_hdd` from krypton,
   then re-run to prove idempotence.

## Verify

This repo has **no linter/test runner** — verification is re-running the playbook
and observing the box (per `AGENTS.md`). Inventory group is `nas` (helium).

- **timers applied to all four drives:**
  `ansible nas -b -m shell -a '/usr/local/sbin/hdd-spin-down.sh; echo done'` then
  read each drive's Power Condition page with the **confirmed** read command
  (e.g. `sdparm --get=STANDBY_Z,IDLE_A /dev/sg*`) → the timers match the vars on
  all four.
- **idempotent:** `ansible-playbook site.yml --tags storage_hdd` a second time →
  `changed=0` (no re-template, no re-enable). A `--check` run is clean.
- **boot persistence (human / reboot):** after `sudo reboot`,
  `systemctl is-enabled hdd-spin-down.service` is `enabled`, the service ran
  (`systemctl status`), and the timers read back set on all four sg devices.
- **smartd doesn't wake drives:** confirm the `smartd.conf` device lines carry
  `-n standby` (and, if you enabled smartd, that it's running with that config).
- **standby reached when idle (human, over time):** with no streams/sync for the
  idle window, read power state on all four → standby/idle, not active.
- **selective wake (human, hardware):** start one playback → exactly one data
  drive active; the other data drive + both parity remain standby.
- **sync wakes then re-sleeps (human):** observe a `snapraid-sync.timer` firing
  wake the drives, and standby return afterward.

## Acceptance criteria (from issue 004, verbatim)

- [ ] Standby timers are applied to all four SAS drives and persist across reboot.
- [ ] After an idle period with no streams, all four drives report standby.
- [ ] Starting a single stream wakes exactly one data drive; the other data drive
      and both parity drives remain in standby.
- [ ] The nightly SnapRAID sync wakes the drives on schedule and they return to
      standby afterward.
- [ ] Routine monitoring/SMART polling does not keep the drives spinning.

## Out of scope / don't touch

- The SSD tier (`/dev/disk/by-id/ata-KINGSTON_*`, `storage_ssd` role) and the boot
  NVMe — SSDs don't spin down; no power-management there.
- `issues/003`'s pool construction (mergerfs/SnapRAID/mounts) — extend the role,
  don't modify its existing `disks.yml` / `mergerfs.yml` / `snapraid.yml` /
  `mounts.yml` / `timers.yml` logic.
- **Enabling** the smartd *daemon* and failure alerting are `issues/013`'s call —
  004 only guarantees the spin-down-safe config (`-n standby`). Coordinate, don't
  duplicate (see Decisions).
- `category.create=lfs` in `hdd_mergerfs_opts` is the load-bearing reason a second
  data drive can stay asleep — don't change it here.
