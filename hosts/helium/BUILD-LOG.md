# helium build log

Chronological record of the physical build / bring-up. The forward-looking work
units live in `issues/` (epic:bootstrap …); this file is "what actually happened
and where we left off". Newest entry at the bottom.

---

## 2026-06-28 — first boot on the rescue OS: hardware verification + SMART burn-in

**State at end of session:** helium is powered on, booted into the Ventoy
`debian-rescue` OS (Debian 13, kernel 6.12). Drive burn-in (SMART long self-tests)
is **in progress** — see the "do not reboot" note below. No installer has run; no
disk has been written.

### Access
- **IP:** `192.168.1.174` — it reclaimed titan's old DHCP lease (same hardware).
- **MAC (active NIC):** `ac:1f:6b:e4:5c:d1` = `eno2`, the Intel **I210** port.
  `eno1` (I219-LM) is down / no-carrier — fine, I210 is the preferred port per
  `hosts/titan/HARDWARE.md` (avoids the e1000e/I219 hang seen on argon).
- **SSH:** `ssh ms@192.168.1.174`, key-only (the `stromdahl.keys` ed25519).
  Needs the key loaded in your agent: `ssh-add ~/.ssh/id_ed25519`.
- **sudo:** temporary rescue password `rescue` (change/irrelevant — rescue OS is
  throwaway). `smartmontools` was apt-installed into the live rescue session.

### Hardware verified against the PRD
| Component | PRD | Found | OK? |
|---|---|---|---|
| CPU | i5-9400 | i5-9400, 6C/6T, VT-x | ✅ |
| RAM | 16 GB | 15 GiB (=16 GB) | ✅ |
| HBA | LSI 9300-8i, SAS3 IT-mode | Broadcom/LSI **SAS3008** Fusion-MPT SAS-3 | ✅ |
| HDD tier | 4× 12 TB SAS HGST He12 `MB012000JWDFD` | sda–sdd, 10.9 TiB, exact model, blank | ✅ |
| Boot | 970 EVO Plus 250 GB NVMe | nvme0n1 Samsung 970 EVO Plus 250 GB | ✅ (see ⚠️) |
| Data tier | **2× 500 GB SATA SSD → btrfs raid1** | **NONE present** | ❌ |

### ❗ Blockers / things needing your hands
1. **The two 500 GB SATA SSDs are not connected yet** — confirmed by user, *not*
   a fault: they simply haven't been physically installed. The probe matched (SATA
   AHCI controller present, but no SATA drive enumerates — only the 4 SAS disks,
   the NVMe, and the Ventoy USB stick). `issues/001` (btrfs raid1 root) and the
   whole hot-data tier are blocked until they're cabled/powered in. **Pending
   build step: install + cable both SSDs before the OS install.**
2. **The NVMe still holds titan's old Proxmox install** — full LVM stack
   (`pve-root`, `pve-data` thin pool, `pve-swap`) intact on `nvme0n1p3`. Must be
   wiped during the Debian install. Untouched so far.

### SMART results (read 2026-06-28 ~05:56 UTC)
All four SAS drives: **Health OK, 0 grown-defect-list entries, 0 uncorrected
read/write errors, 30–32 °C.** Mixed age confirms the PRD's dual-parity rationale:

| Drive | Serial | Mfg | Power-on hours |
|---|---|---|---|
| sda | 5PJHD06E | wk33 2020 | 43,907 (~5.0 y) |
| sdb | D5HH850F | wk10 2022 | 25,841 (~2.9 y) |
| sdc | 8CKDRRSE | wk42 2019 | 44,698 (~5.1 y) |
| sdd | D5HH8K8F | wk10 2022 | 25,841 (~2.9 y) |

- **Watch item:** non-medium error counts are elevated on all four (2,559–3,327).
  These are interface/bus-level events (resets/aborts), **not** platter defects —
  benign given 0 grown defects + 0 uncorrected. If they climb fast under load,
  suspect a SAS cable / HBA seating.
- **NVMe:** PASSED, 0 % wear, 100 % spare, 0 media errors, 40 °C, 1,486 POH.
  Healthy as the single non-redundant boot drive.

### HBA cooling & temperature monitoring
- **Active cooling confirmed:** a small **Noctua fan** is mounted on the SAS3008
  heatsink. This satisfies the "HBA has active airflow" half of `issues/001`'s
  acceptance criteria. (Essential — these cards thermally throttle/shut down when
  passively cooled.)
- **HBA temp is NOT software-readable in IT-mode.** The chip has an internal
  thermal sensor + hardware shutdown threshold, but `mpt3sas` exposes no temp
  (only `ioc_reset_count` on the scsi_host), there's no hwmon device for it, and
  storcli/sas3ircu don't apply/aren't installed. So there's no temperature number
  to alarm on.
- **Monitor proxies instead:** `ioc_reset_count` (cat
  `/sys/class/scsi_host/host0/ioc_reset_count`, should stay 0) and the drives'
  non-medium error counts. The Noctua + visual "is it spinning" check is the
  primary safeguard.
- Drive temps (which *are* readable) under self-test read load: SAS 32–34 °C
  (trip 60 °C), NVMe 40 °C (warn/crit 85 °C) — all cool.

### ⏳ Burn-in launched — DO NOT REBOOT until done *(resolved 2026-06-29, see below)*
- **Long self-tests launched on sda, sdb, sdc, sdd** at ~05:56 UTC.
  ETA ~23 h each → **~05:00 UTC Mon 2026-06-29** (drives quote conservatively).
- NVMe short self-test launched (a prior short test already shows
  *completed without error*).
- A reboot / shutdown / starting the installer **aborts an in-progress SAS long
  test.** The box must stay booted in the rescue OS until they finish.

---

## 2026-06-29 — burn-in complete (clean); SATA SSDs still not installed

**State at end of session:** the SAS long self-tests finished. The "do not
reboot" constraint above is **lifted** — the box can now be safely shut down /
rebooted / sent to the installer. Build is **still blocked** on the two SATA
SSDs not being physically present (unchanged from 2026-06-28).

### SMART long self-test — all four PASSED
Read via the resume-checklist command. All four: `Background long … Completed`,
`LBA_first_err = -`, sense `[- - -]` → entire surface read, **zero failed LBAs**.
Power-on hours advanced ~20 h vs. the burn-in-start readings, confirming the
tests ran to completion rather than aborting:

| Drive | POH at start (06-28) | POH at finish (06-29) |
|---|---|---|
| sda | 43,907 | 43,927 |
| sdb | 25,841 | 25,860 |
| sdc | 44,698 | 44,716 |
| sdd | 25,841 | 25,861 |

### Bus health — the 06-28 watch-item cleared
- `ioc_reset_count` on the HBA scsi_host is **still 0** after a full day of
  self-test read load. The elevated non-medium error counts (2,559–3,327) did
  **not** produce any HBA resets → confirmed benign interface noise, not a
  failing SAS cable / HBA seating. No action needed.
- NVMe: no self-test in progress; prior short test passed.

### Still blocked — unchanged
- **The two 500 GB SATA SSDs are still not connected.** `lsblk -d -e7,11` shows
  only the 4 SAS disks, the USB stick (`sde`), and the NVMe. `issues/001` and the
  whole data tier remain blocked until both SSDs are cabled/powered in.

### Resume checklist (next session)
1. ~~Check the SAS long tests finished clean~~ — **done, all PASSED (above).**
2. **Install + cable the two SATA SSDs**, then confirm they enumerate
   (`lsblk -d -e7,11` should show two ~500 GB `sata` drives).
3. Then proceed to `issues/001` — wipe the NVMe (still holds titan's old Proxmox
   LVM stack) + plain single-disk Debian install on the NVMe; Ansible then builds
   the btrfs raid1 **data** pool across the two SSDs (per the revised PRD, the
   root is no longer raid1).
