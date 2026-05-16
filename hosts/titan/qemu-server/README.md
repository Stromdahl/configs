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
  per-port for keyboard / Bluetooth / hot-swap: `usb0=1-4.1`, `usb1=1-4.2`,
  `usb3=1-4.4`. **Port 1-4.3 (the 8BitDo Pro 3 dock) is intentionally not
  passed by-port** — QEMU's by-port slot loses the device when its VID/PID
  changes (Pro 3 receiver flips between `2dc8:3109` idle and `2dc8:310b`
  active on every controller wake/sleep), and by-port re-attach never
  recovers without manual intervention. Instead the dock is passed by-id
  in two slots: `usb2=2dc8:3109` and `usb4=2dc8:310b`. QEMU's 2s auto-poll
  reattaches whichever PID is live; only one of the two is ever connected
  at a time. See [[project-pve-usb-passthrough]].
- qemu-guest-agent enabled, onboot=1, virtio scsi+net.
