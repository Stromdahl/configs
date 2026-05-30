# neon — hardware reference

Debian **docker host** at **192.168.1.153** (`jellyfin.stromdahl.tech`). Custom-built
desktop, **not** a Proxmox node — plain Debian running docker-ce (Jellyfin + other
containers). Deploys land in `/opt/neon/` via `git push neon`.

| | |
|---|---|
| **Board** | ASUS **Z170I PRO GAMING** (Mini-ITX) — custom build, DMI system strings unset |
| **CPU** | Intel Core **i5-6600K** — Skylake, 4C/4T, 3.5 GHz (unlocked), VT-x |
| **RAM** | 16 GB — 2× 8 GB Corsair Vengeance LPX DDR4-2133 (CMK16GX4M2A2133C13), **both DIMM slots full** |
| **Storage** | Samsung **990 PRO 2 TB** NVMe (`nvme0n1`, media/containers) + Kingston UV400 480 GB SATA SSD (`sda`) |
| **GPU** | NVIDIA **GTX 1070** (GP104) — available for transcoding |
| **NIC / WiFi** | Intel **I219-V** onboard 1 GbE + Qualcomm Atheros QCA6174 802.11ac |
| **BIOS** | ASUS Z170I 3805, **2018-05-16** |
| **OS** | Debian 13 (trixie), kernel `6.12.90+deb13.1` (stock Debian; runs en_GB locale) |

## Notes
- **Both RAM slots full** (Z170I is Mini-ITX, 2 slots, 32 GB max) — a bump means
  swapping in a 2× 16 GB kit. DDR4-2133 is slow but fine for a container host.
- **2 TB 990 PRO** is the data/media drive; the 480 GB SATA SSD is secondary.
  No redundancy on either.
- Aging platform (Skylake 2015, BIOS 2018) but stable. Single 1 GbE uplink.

## Refresh
```bash
ssh ms@192.168.1.153 'for k in sys_vendor product_name board_name bios_version bios_date; do echo "$k=$(cat /sys/class/dmi/id/$k)"; done; \
  lscpu; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; lspci | grep -iE "vga|ethernet|network"; \
  sudo dmidecode -t memory | grep -E "Size:|Locator:|Part Number:|Speed:" | grep -v Serial'
```
