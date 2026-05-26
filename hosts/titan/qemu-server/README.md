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

## 9000 (deb13-tmpl, Debian 13 template)

Canonical cloud-init template for spinning up new Debian 13 (trixie) VMs
on this homelab. Replaces the ad-hoc `community-scripts/ProxmoxVE
debian-13-vm.sh` recipe that produced `argon-101`.

- Source image: `debian-13-genericcloud-amd64.qcow2` from
  `cloud.debian.org/images/cloud/trixie/latest/`, SHA512-verified.
- Hardware shape: `q35` + OVMF + `efidisk0`, `cpu: x86-64-v2-AES`
  (portable across argon/titan, not pinned to host CPU),
  `scsihw: virtio-scsi-single`, `scsi0: discard=on,iothread=1,ssd=1`,
  `agent: enabled=1,fstrim_cloned_disks=1`, headless serial console
  (`serial0: socket`, `vga: serial0`).
- `qemu-guest-agent` is baked into the image (via `virt-customize`) and
  enabled before sealing — first-boot IP reporting works without a delay.
- `net0` has **no** `firewall=1` flag — PVE 9's NIC-level default-DROP
  policy would silently break every clone's network until an explicit
  allow rule was added. Clones can opt in per VM.
- **Disk image is identity-less**: no user baked in, no SSH host keys,
  empty `/etc/machine-id`. Identity arrives via cloud-init at first boot.
- **PVE config has homelab defaults pre-filled**: `ciuser: ms`,
  `sshkeys: stromdahl.keys`, `ipconfig0: ip=dhcp`. Clones inherit these,
  so the common case is `qm clone … && qm start …` with no `qm set` in
  between. Override per-clone for static IP or a different user (see
  "Cloning 9000").
- Disk: 8 GiB (matches argon-101). Cloud-init `growpart`s the rootfs on
  first boot. Clones bump via `qm resize <id> scsi0 +<N>G`.

## Building / rebuilding template 9000

Run on titan. Requires `libguestfs-tools` (`sudo apt-get install
libguestfs-tools`). Storage assumes `local-lvm`; adjust if titan's
storage layout changes.

```bash
# 1. Fetch and verify image
sudo mkdir -p /var/lib/vz/template/qcow
cd /var/lib/vz/template/qcow
sudo wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
sudo wget https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS
sudo sha512sum -c --ignore-missing SHA512SUMS   # must print "OK"

# 2. Bake qemu-guest-agent into the image
sudo virt-customize -a debian-13-genericcloud-amd64.qcow2 \
    --install qemu-guest-agent \
    --run-command 'systemctl enable qemu-guest-agent'

# 3. Create VM 9000 with the canonical hardware shape
sudo qm create 9000 --name deb13-tmpl --ostype l26 \
    --machine q35 --bios ovmf --cpu x86-64-v2-AES \
    --cores 2 --memory 2048 \
    --scsihw virtio-scsi-single \
    --net0 virtio,bridge=vmbr0 \
    --agent enabled=1,fstrim_cloned_disks=1 \
    --serial0 socket --vga serial0 \
    --tablet 0 --onboot 0
sudo qm set 9000 --efidisk0 local-lvm:0,efitype=4m,pre-enrolled-keys=0
sudo qm set 9000 --scsi0 local-lvm:0,discard=on,iothread=1,ssd=1,\
import-from=/var/lib/vz/template/qcow/debian-13-genericcloud-amd64.qcow2
sudo qm resize 9000 scsi0 8G
sudo qm set 9000 --ide2 local-lvm:cloudinit
sudo qm set 9000 --boot order=scsi0

# 4. First boot for the sealing ritual (temporary DHCP, no user)
sudo qm set 9000 --ipconfig0 ip=dhcp
sudo qm start 9000
# wait for guest agent
until sudo qm guest cmd 9000 ping >/dev/null 2>&1; do sleep 1; done
sudo qm guest exec 9000 -- cloud-init status --wait

# 5. Seal — truncate (do NOT delete) /etc/machine-id, drop ssh host keys
sudo qm guest exec 9000 --timeout 120 -- bash -c '
    apt-get clean &&
    apt-get autoremove --purge -y &&
    cloud-init clean --logs &&
    rm -rf /tmp/* /var/tmp/* \
           /var/log/*.log /var/log/*/*.log /var/log/journal/* \
           /var/lib/dhcp/* /var/lib/cloud/* \
           /etc/ssh/ssh_host_* \
           /root/.bash_history &&
    truncate -s 0 /etc/machine-id &&
    ln -sf /etc/machine-id /var/lib/dbus/machine-id &&
    sync
'
sudo qm shutdown 9000 --timeout 60

# 6. Convert to template, then bake in homelab cloud-init defaults so
#    plain `qm clone 9000 <id> --full 1 && qm start <id>` is enough.
sudo qm set 9000 --delete ipconfig0
sudo qm template 9000
sudo qm set 9000 \
    --ciuser ms \
    --sshkeys <(curl -fsSL https://github.com/stromdahl.keys) \
    --ipconfig0 ip=dhcp

# 7. Snapshot config back to dotfiles
ssh titan 'sudo qm config 9000' > hosts/titan/qemu-server/9000.conf
```

Notes:

- **Never `rm /etc/machine-id`** — `truncate -s 0` it. systemd only
  regenerates the ID when the file *exists and is empty*; deletion ⇒ no
  regeneration ⇒ DHCP-lease collisions across clones.
- `cloud-init clean --machine-id` has historically *removed* the file
  (Launchpad #2002784), which is why we don't trust it and seal by hand.
- Do **not** use `cpu: host` "for performance" — it locks the template
  to titan's CPU model and breaks clone-to-other-host. `x86-64-v2-AES`
  is the PVE 9 UI default and portable across argon/titan.
- Do **not** use `q35,viommu=virtio` — known Debian-trixie initramfs
  root-mount failure (PVE forum 170206).
- Storage `local-lvm` (`lvmthin`, content `images,rootdir`) hosts both
  `scsi0` and the `ide2: cloudinit` drive. `local` (dir, no `images`)
  cannot hold either. Snippets are not enabled on any storage; we don't
  use `cicustom`, so this is fine.

## Cloning 9000

The template's PVE config pre-fills `ciuser: ms`, `sshkeys`, and
`ipconfig0: ip=dhcp`, so clones inherit them — no post-clone `qm set` is
required for the common case. Full clone, not linked (template lives on
`local-lvm`; linked clones would lock to the same storage).

```bash
# DHCP, default ms user (common case)
sudo qm clone 9000 <NEW_VMID> --name <NEW_NAME> --full 1
sudo qm resize <NEW_VMID> scsi0 +<N>G   # optional, defaults to 8 GiB
sudo qm set <NEW_VMID> --onboot 1       # if it should start at boot
sudo qm start <NEW_VMID>
```

```bash
# Static-IP override (LAN 192.168.1.0/24, gateway .1) — overrides the
# inherited ipconfig0=dhcp. Override --ciuser / --sshkeys the same way
# for a non-default user.
sudo qm clone 9000 <NEW_VMID> --name <NEW_NAME> --full 1
sudo qm set <NEW_VMID> \
    --ipconfig0 ip=192.168.1.<X>/24,gw=192.168.1.1 \
    --nameserver 192.168.1.1 \
    --searchdomain lan
sudo qm start <NEW_VMID>
```

First boot takes ~20–30 s; `qm guest cmd <NEW_VMID> network-get-interfaces`
returns the lease once cloud-init finishes. SSH as `ms@<ip>` works
immediately with the GitHub-published keys (see [[user-ssh-keys]]),
then run `cd ~/.dotfiles && ./install.sh` to apply the host's module set.
