# titan-hermes-agent — hardware (VM)

Debian VM on **titan** (PVE VMID 101) running the Hermes agent (Nous). No bare-metal
hardware of its own; virtual hardware is in `hosts/titan/qemu-server/101.conf`:

- **vCPU:** 2 cores (`x86-64-v2-AES`) · **RAM:** 4 GB · **Disk:** 32 GB (local-lvm, ssd)
- **Firmware:** OVMF / q35 · cloud-init (`ciuser: ms`) · DHCP (192.168.1.189)
- **Guest:** Debian (l26) · `onboot: 1` · no passthrough

It's a guest on titan → see `hosts/titan/HARDWARE.md`.
