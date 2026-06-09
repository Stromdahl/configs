# argon — hardware reference

Proxmox VE host at **192.168.1.18**. Sibling to `titan`. Hosts the
Home Assistant OS VM (100) and the `argon-101` Debian VM (101).

| | |
|---|---|
| **Model** | HP EliteDesk 800 G4 DM 65W (Desktop Mini, 1L mini-PC) |
| **Model SKU** | 2YH17AV (unit serial/service tag deliberately omitted — public repo) |
| **Form factor** | Desktop Mini (HP DMI mislabels chassis as "Mini Tower") |
| **CPU** | Intel Core i5-8500 — Coffee Lake, 6C/6T, 3.0 GHz base / 4.1 GHz turbo, 65 W, VT-x |
| **RAM** | 8 GB total. 1× 8 GB DDR4-2667 SO-DIMM (Hynix HMA81GS6JJR8N-VK) in **DIMM1**; **DIMM3 empty** → single-channel, one slot free |
| **Storage** | 1× WD PC SN520 NVMe, 256 GB (238.5 GiB), `nvme0n1` (DRAM-less entry-level NVMe) |
| **Wired NIC** | Intel **I219-LM** (`e1000e`), onboard `eno1` — *this is the NIC with the Hardware Unit Hang bug; see below* |
| **WiFi** | Realtek RTL8852AE 802.11ax (`rtw89_8852ae`) — present, unused for the host |
| **Baseboard** | HP 845A, KBC 07.D2.00 |
| **BIOS** | HP Q21 Ver. 02.08.00, dated **2019-06-25** (old — a BIOS update is almost certainly available) |
| **PVE** | pve-manager 9.0.3, kernel 6.14.8-2-pve (as of 2026-05-30) |

## Notes / planning

- **RAM is the tight resource.** 8 GB total, with HAOS (VM 100) alone reserved
  4 GB plus `argon-101` and PVE overhead. One free SO-DIMM slot (DIMM3) — adding
  a matched DDR4-2667 stick would both raise headroom and restore dual-channel.
- **NVMe is single + entry-level / DRAM-less.** No redundancy on the host disk.
- **BIOS is from 2019.** Worth updating given the stability history below (HP G4 DM
  has substantially newer BIOS releases addressing power/USB/NIC issues).

## Known issues / incident history

- **2026-05-26 — Intel e1000e "Detected Hardware Unit Hang" on `eno1`.** TX queue
  stalled, NIC unrecoverable without a powercycle; took the host offline. Mitigated
  by `argon-tweaks` → `nic-tx-hang-mitigation.service` (disables tso/gso/gro on
  `eno1`). Service confirmed `active` and clean on subsequent boots.
- **2026-05-30 — blinking-red power LED, host down.** Distinct from the NIC bug
  (machine wasn't POSTing). Recovered on a full AC-drain power-cycle, so likely a
  *transient* fault — but second incident in 4 days. If it recurs, capture the
  **blink count + beep pattern** (HP encodes the failed subsystem there) before
  power-cycling. Usual suspects on aging mini-PCs: PSU/power-brick degrading,
  thermals (dust / failing fan), or a marginal RAM stick.
- **2026-06-04 — blinking-red again; pattern captured: 4 red blinks, then white,
  no beep.** HP blink scheme: red = major category, white = minor; **major 4 =
  thermal** (4.2 CPU over-temp / 4.3 ambient / 4.4 — white count not captured).
  So the 05-30 "transient" read is superseded: this is a recurring **thermal
  trip**. Host did NOT come back after the first power-cycle — consistent with
  the board re-tripping while still hot or with a dead/blocked fan. Action:
  open the lid, check/clean blower fan + heatsink fins, verify fan spins at
  POST; if it trips again cold+clean, count the white blinks and suspect
  fan or thermal sensor/board.
- **2026-06-09 — root cause confirmed: blower fan completely clogged.** Opened
  the lid; the fan/heatsink was packed solid with dust. Cleaned it out. This
  matches the major-4 thermal trips exactly — the board was over-temping because
  airflow was choked, not a sensor/board fault. Now resolved. Watch for: temps
  under load (`sensors` / `ssh argon 'sensor coretemp'`) should sit well below
  the trip point; if a thermal blink recurs *with a clean fan*, escalate to fan
  RPM/bearing or the thermal sensor. Add a recurring dust-clean to maintenance.

```bash
ssh argon 'sudo dmidecode -t system -t baseboard -t bios -t processor -t memory; \
           lscpu; free -h; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; \
           lspci | grep -iE "ethernet|network"; pveversion'
```
