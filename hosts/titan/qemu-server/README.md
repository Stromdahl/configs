# VM config snapshots — titan (Proxmox VE 9)

Reference copies of `/etc/pve/nodes/titan/qemu-server/<vmid>.conf`. Proxmox
owns the live files via pmxcfs; these aren't auto-applied. Update by hand
when a VM config changes meaningfully:

```bash
ssh titan 'sudo /usr/sbin/qm config 100' > hosts/titan/qemu-server/100.conf
git add hosts/titan/qemu-server/100.conf
```

To restore from a snapshot (disaster recovery, VM stopped):

```bash
scp hosts/titan/qemu-server/100.conf titan:/tmp/100.conf
ssh titan 'sudo cp /tmp/100.conf /etc/pve/nodes/titan/qemu-server/100.conf'
```

## 100 (titan-100, gaming HTPC)

- RTX 2060 PCI passthrough: `hostpci0: 0000:01:00.0,x-vga=1`
- GPU USB-C controller: `hostpci1: 0000:01:00.2`
- USB hub on host port 1-4 (Genesys Logic, 4 downstream ports) passed through
  per-port — keyboard / Bluetooth / gamepad receivers + one free port for
  hot-swap. `usb0..usb3: host=1-4.{1..4}`
- qemu-guest-agent enabled, onboot=1, virtio scsi+net.
