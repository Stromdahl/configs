# krypton — hardware reference

Personal **laptop** — and the admin workstation these homelab tasks run from.

| | |
|---|---|
| **Model** | ASUS **Vivobook S 14** (M3407KA), board M3407KA |
| **CPU** | **AMD Ryzen AI 7 350** w/ Radeon 860M — 8C/16T, up to 4.31 GHz, AMD-V (Zen 5 "Krackan Point") |
| **RAM** | 32 GB — LPDDR5x, soldered on this thin-and-light chassis (no DIMM slots; not user-upgradeable) |
| **Storage** | Micron **1 TB** NVMe (`nvme0n1`, MTFDKBA1T0QGN) |
| **GPU** | Integrated AMD **Radeon 860M** (RDNA 3.5) — no discrete GPU |
| **WiFi** | Realtek RTL8852BE 802.11ax |
| **BIOS** | ASUS `M3407KA.311`, 2025-06-30 |
| **OS** | Debian 13 (trixie), kernel `6.12.88+deb13` |

## Notes
- Modern hardware (2025 BIOS); the daily driver, not a server.
- RAM is soldered — per-DIMM detail is unavailable (no passwordless sudo here, and
  there are no physical slots anyway).
- Sits on the LAN at 192.168.1.170 (DHCP) over WiFi (`wlp2s0`).

## Refresh (local)
```bash
for k in sys_vendor product_name board_name bios_version bios_date; do echo "$k=$(cat /sys/class/dmi/id/$k)"; done
lscpu; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; lspci | grep -iE "vga|3d|network"
```
