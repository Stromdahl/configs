# argon-101 — hardware (VM)

Debian VM on **argon** (PVE VMID 101) — the (planned) NetBird routing peer for
remote homelab access. No bare-metal hardware of its own; virtual hardware is in
`hosts/argon/qemu-server/101.conf`:

- **vCPU:** 2 cores · **RAM:** 2 GB · **Disk:** 8 GB (local-lvm, ssd)
- **Firmware:** OVMF · cloud-init (`ciuser: ms`) · DHCP (192.168.1.177)
- **Guest:** Debian (l26) · `onboot: 1` · no passthrough

It's a guest on argon → see `hosts/argon/HARDWARE.md`. Goes down whenever argon
does (the host has a reliability history — see that doc's incident log).
