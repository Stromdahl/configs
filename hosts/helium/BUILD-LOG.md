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
1. **The two 500 GB SATA SSDs are not connected.** The SATA AHCI controller is
   present but no SATA drive enumerates — only the 4 SAS disks, the NVMe, and the
   Ventoy USB stick. `issues/001` (btrfs raid1 root) and the whole hot-data tier
   are blocked until these are cabled/powered in. **Verify they're physically
   installed before the next session.**
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

### ⏳ In progress — DO NOT REBOOT until done
- **Long self-tests launched on sda, sdb, sdc, sdd** at ~05:56 UTC.
  ETA ~23 h each → **~05:00 UTC Mon 2026-06-29** (drives quote conservatively).
- NVMe short self-test launched (a prior short test already shows
  *completed without error*).
- A reboot / shutdown / starting the installer **aborts an in-progress SAS long
  test.** The box must stay booted in the rescue OS until they finish.

### Resume checklist (next session)
1. Check the tests finished clean:
   ```bash
   ssh ms@192.168.1.174 'for d in sda sdb sdc sdd; do printf "%s: " $d; echo rescue | sudo -S smartctl -l selftest /dev/$d 2>/dev/null | grep -m2 -iE "status|Completed|in progress"; done'
   ```
   Pass = `Completed`, no failing LBA. Any failing LBA on a used drive → consider
   swapping it before building the pool.
2. Confirm the **two SATA SSDs** now enumerate (`lsblk -d -e7,11`).
3. Then proceed to `issues/001` — wipe the NVMe + Debian install with btrfs raid1
   root across the two SSDs.
