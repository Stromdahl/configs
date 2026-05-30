# titan-100 — hardware (VM)

HTPC / gaming VM on **titan** (PVE VMID 100). It has no bare-metal hardware of its
own; virtual hardware is defined in `hosts/titan/qemu-server/100.conf`:

- **vCPU:** 5 cores (`cpu: host`) · **RAM:** 8 GB · **Disk:** 32 GB (local-lvm)
- **Passthrough (real hardware from titan):**
  - NVIDIA **RTX 2060** — `hostpci0 0000:01:00.0` (x-vga) + `hostpci1 0000:01:00.2` (HDMI audio)
  - USB controller — `hostpci2 0000:00:14.0` (controllers/remotes; see 8BitDo notes)
- **Guest:** Linux (l26) · `onboot: 1` · net virtio on vmbr0 (192.168.1.176)

The physical GPU lives in titan → see `hosts/titan/HARDWARE.md`. Change hardware
via the qm config, not here.
