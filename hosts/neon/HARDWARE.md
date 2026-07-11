# neon — hardware reference

Custom-built Mini-ITX desktop being reborn as a **desk-based Debian gaming rig**
(see `hosts/neon/PRD.md`). Was the Debian docker host (`jellyfin.stromdahl.tech`,
192.168.1.153); that role retired to helium (issue 009). Same physical chassis,
new life. **Not** a Proxmox node.

| | |
|---|---|
| **Board** | ASUS **Z170I PRO GAMING** (Mini-ITX) — custom build, DMI system strings unset |
| **CPU** | Intel Core **i5-6600K** — Skylake, 4C/4T, 3.5 GHz (unlocked), VT-x |
| **RAM** | 16 GB — 2× 8 GB Corsair Vengeance LPX DDR4-2133 (CMK16GX4M2A2133C13), **both DIMM slots full** (max 32 GB) |
| **Storage** | Samsung **990 PRO 2 TB** NVMe (`nvme0n1`) — sole internal drive |
| **GPU** | NVIDIA **GTX 1070** (GP104, `10de:1b81`) — Pascal, still installed |
| **NIC / WiFi** | Intel **I219-V** onboard 1 GbE + Qualcomm Atheros QCA6174 802.11ac |
| **BIOS** | ASUS Z170I 3805, **2018-05-16** |
| **OS** | Target: Debian 13. Currently booted on the Ventoy Debian rescue OS (`debian-rescue`) for the rebuild. |

## Notes

- **Verified against the running machine 2026-07-11** (via the rescue OS, issue 030),
  correcting the pre-teardown spec this file used to carry.
- **The helium harvest took only the secondary 480 GB Kingston UV400 SATA SSD.**
  The GTX 1070, the 990 PRO NVMe, and both RAM DIMMs all remained — the issue-009
  note about "freeing the 1.8 TB NVMe as a backup-target candidate" was never acted on.
  The chassis now has a single internal drive (the NVMe); the only SATA/USB device
  otherwise present during the rebuild is the USB rescue stick.
- **Both RAM slots full** — a bump to 32 GB means swapping in a 2× 16 GB kit.
  DDR4-2133 is slow but fine.
- Aging platform (Skylake 2015, BIOS 2018) but stable. Single 1 GbE uplink.
- The GTX 1070 is a **Pascal** card; the `nvidia` module was written for Turing
  (RTX 2060) — same proprietary driver family, but confirm before relying on it.

## Refresh
```bash
ssh ms@192.168.1.153 'for k in sys_vendor product_name board_name bios_version bios_date; do echo "$k=$(cat /sys/class/dmi/id/$k)"; done; \
  lscpu; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; lspci | grep -iE "vga|ethernet|network"; \
  sudo dmidecode -t memory | grep -E "Size:|Locator:|Part Number:|Speed:" | grep -v Serial'
```
