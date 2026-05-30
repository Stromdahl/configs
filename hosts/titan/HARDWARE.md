# titan — hardware reference

Proxmox VE host at **192.168.1.174**. Sibling to `argon`. Hosts the HTPC/gaming
VM (`titan-100`, with RTX 2060 passthrough), the Hermes agent VM
(`titan-hermes-agent`), and the Debian 13 cloud-init template (VMID 9000).

| | |
|---|---|
| **Board / chassis** | Supermicro **X11SCV-Q** rev 1.20 (Mini-ITX, embedded/compact; product DMI strings left at Supermicro defaults) |
| **CPU** | Intel Core **i5-9400** — Coffee Lake Refresh, 6C/6T, 2.9 GHz base / 4.1 GHz turbo, 65 W, VT-x |
| **RAM** | 16 GB. 2× 8 GB DDR4 **SO-DIMM**, both slots full (DIMMA1 + DIMMB1) — **mismatched modules** (Innodisk D4S-8G24H1G8C1 + Micron 8ATF1G64HZ), running at 2400 MT/s. No free slot. |
| **Storage** | 1× Samsung **970 EVO Plus 250 GB** NVMe (`nvme0n1`) |
| **GPU** | NVIDIA **RTX 2060** (TU104) at `01:00.0` — bound to vfio and passed through to `titan-100`; not used by the host |
| **Wired NIC** | Intel **I219-LM** (`e1000e`, onboard) + Intel **I210** (second 1 GbE port) |
| **BIOS** | Supermicro 1.4, 2020-09-03 |
| **OS** | Debian 13 (trixie), Proxmox VE 9, kernel `7.0.2-3-pve` |

## Notes
- **Both RAM slots are populated** (unlike argon's one free slot) — a RAM bump
  means *replacing* modules, not adding. Mismatched but stable at 2400 MT/s.
- **I219-LM is the same `e1000e` NIC family that hangs on argon** (see
  `hosts/argon/HARDWARE.md`). titan does **not** currently carry the `argon-tweaks`
  offload-disable mitigation. If titan ever logs "Detected Hardware Unit Hang",
  apply the same `ethtool -K eno1 tso off gso off gro off` fix. It has a second
  NIC (I210) as a fallback path.
- GPU + its HD-audio function (`01:00.2`) + a USB controller (`00:14.0`) are bound
  to vfio for `titan-100` — see `hosts/titan/qemu-server/100.conf`.

## Refresh
```bash
ssh titan 'for k in sys_vendor product_name board_name bios_version bios_date; do echo "$k=$(cat /sys/class/dmi/id/$k)"; done; \
  lscpu; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; lspci | grep -iE "vga|ethernet|network"; \
  sudo dmidecode -t memory | grep -E "Size:|Locator:|Part Number:|Speed:" | grep -v Serial'
```
