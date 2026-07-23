# argon — hardware reference

Proxmox VE host at **192.168.1.18**. Sibling to `titan`. Hosts the
Home Assistant OS VM (100) and the `argon-101` Debian VM (101).

> **⚠️ Chassis transplant, 2026-07-23.** `argon` now runs on the **second
> physical EliteDesk 800 G4 DM** (same model). The original unit failed
> repeatedly (see incident history — NIC hang, recurring thermal trips) and was
> retired. The **NVMe disk, the 8 GB SO-DIMM, and both USB radios were carried
> over** to a healthy same-model chassis; everything else (board, PSU, chassis,
> **onboard NIC — new MAC**) is a fresh unit. **The incident history below dated
> *before* 2026-07-23 pertains to the RETIRED unit** — the current unit starts
> with a clean log. NIC-hang mitigation (`argon-tweaks`) is retained as a
> precaution (same I219-LM silicon), not because this unit has exhibited the bug.

| | |
|---|---|
| **Model** | HP EliteDesk 800 G4 DM 65W (Desktop Mini, 1L mini-PC) |
| **Model SKU** | 2YH17AV (unit serial/service tag deliberately omitted — public repo) |
| **Form factor** | Desktop Mini (HP DMI mislabels chassis as "Mini Tower") |
| **CPU** | Intel Core i5-8500 — Coffee Lake, 6C/6T, 3.0 GHz base / 4.1 GHz turbo, 65 W, VT-x |
| **RAM** | 8 GB total. 1× 8 GB DDR4-2667 SO-DIMM (Hynix HMA81GS6JJR8N-VK) in **DIMM1**; **DIMM3 empty** → single-channel, one slot free |
| **Storage** | 1× WD PC SN520 NVMe, 256 GB (238.5 GiB), `nvme0n1` (DRAM-less entry-level NVMe) — *carried over from the retired unit; SMART PASSED, 7% wear at transplant* |
| **Wired NIC** | Intel **I219-LM** (`e1000e`), onboard `eno1`, MAC `80:e8:2c:22:05:96` (current unit) — *the retired unit hit the Hardware Unit Hang bug; mitigation retained as precaution, see below* |
| **WiFi** | Realtek RTL8852AE 802.11ax (`rtw89_8852ae`) — present, unused for the host |
| **Baseboard** | HP 845A, KBC 07.D2.00 |
| **BIOS** | Current unit: version **TBD** (re-check with `dmidecode -t bios`); set to UEFI (no CSM), Secure Boot off, VT-x/VT-d on at transplant. (Retired unit was HP Q21 Ver. 02.08.00, 2019-06-25.) |
| **USB radios** | Zigbee coordinator **ConBee II** (`1cf1:0030`) → ZHA, passthrough `usb1`. Thread/Zigbee **Nabu Casa ZBT-2** (`303a:831a`) → Thread/OTBR/Matter, passthrough `usb0` — *currently unplugged (unused); config entries still present. ⚠️ Keep the two radios physically apart + ConBee on a USB-2 extension away from USB-3 — direct-plug + adjacency made the ConBee radio deaf at transplant (coordinator connected but heard no devices).* |
| **PVE** | pve-manager 9.0.3, Debian 13.5 (trixie) (as of 2026-07-23) |

## Notes / planning

- **RAM is the tight resource.** 8 GB total, with HAOS (VM 100) alone reserved
  4 GB plus `argon-101` and PVE overhead. One free SO-DIMM slot (DIMM3) — adding
  a matched DDR4-2667 stick would both raise headroom and restore dual-channel.
- **NVMe is single + entry-level / DRAM-less.** No redundancy on the host disk.
- **BIOS is from 2019.** Worth updating given the stability history below (HP G4 DM
  has substantially newer BIOS releases addressing power/USB/NIC issues).

## Known issues / incident history

> Entries below dated **before 2026-07-23** belong to the **retired first unit**.

- **2026-07-23 — chassis transplant (retired unit → current unit).** After the
  original EliteDesk went down and stayed down, its NVMe + SO-DIMM + both USB
  radios were moved into a spare same-model EliteDesk. Verified from a Debian
  rescue boot before first Proxmox boot: SMART PASSED (7% wear, 0 media errors),
  `pve` VG + all VM disks intact, RAM seen, `eno1` present. First boot clean —
  both VMs autostarted, HA back at `.99`. **Zigbee gotcha at bring-up:** ConBee
  showed *coordinator connected but 0 devices* — caused by (a) the ZBT-2 plugged
  directly alongside it (2.4 GHz interference — now unplugged) and (b) several
  bulbs manually switched off at the wall while HA was out. Powering a bulb → it
  rejoined instantly; radio is healthy. Long-term: put the ConBee on a USB-2
  extension away from USB-3/other radios.
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
