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
- **Whole Intel xHCI controller (`00:14.0`) passed through as `hostpci2`.**
  Replaces the older per-port `usbN: host=1-4.x` setup. Rationale: the
  8BitDo Pro 3 dock-receiver re-enumerates with a different VID/PID on
  every controller wake/sleep (`2dc8:3109` idle ↔ `2dc8:310b` active).
  QEMU's `usb-host` backend handles each new enumeration by calling
  `libusb_claim_interface`, which detaches the host's kernel driver
  (xpad / hid-generic) and triggers a USB device reset. The reset
  reliably broke the dongle's 2.4 GHz pairing with the controller, so
  the VM saw the device wake for a few seconds and then drop. Passing
  through the entire xHCI eliminates QEMU's USB layer entirely — the
  guest kernel owns the controller and handles wake/sleep transitions
  natively, exactly like bare metal. titan is a headless PVE server with
  no other USB consumers, so giving up host USB costs nothing.
  Implication: any device plugged into any port on this controller (the
  4-port hub at `1-4` *and* unused root-hub ports) appears inside VM 100,
  not on titan. See [[project-pve-usb-passthrough]].
- qemu-guest-agent enabled, onboot=1, virtio scsi+net.
