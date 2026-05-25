# LXC config snapshots — titan (Proxmox VE)

Sibling to `qemu-server/`. Reference copies of `/etc/pve/nodes/titan/lxc/<vmid>.conf`.
Proxmox owns the live files via pmxcfs; these aren't auto-applied. Update by hand
when a CT config changes meaningfully:

```bash
ssh titan 'sudo /usr/sbin/pct config <vmid>' > hosts/titan/lxc/<vmid>.conf
git add hosts/titan/lxc/<vmid>.conf
```

To restore from a snapshot (disaster recovery, CT stopped):

```bash
scp hosts/titan/lxc/<vmid>.conf titan:/tmp/<vmid>.conf
ssh titan 'sudo cp /tmp/<vmid>.conf /etc/pve/nodes/titan/lxc/<vmid>.conf'
```

## CTs

(none yet)

Sibling on titan: **titan-100** (VMID 100, qemu-server) is the HTPC VM with
RTX 2060 passthrough — see `hosts/titan/qemu-server/100.conf`. Keep CT vs VM
numbering separate; LXCs live in the 100s starting at 101 to leave 100 to
the HTPC.

## Quirks

- **pvesh / pct as ms**: pmxcfs only accepts root/www-data IPC. Always
  `sudo pvesh ...` and `sudo pct ...` — running them as ms (uid 1000)
  gives `ipcc_send_rec failed: Unknown error -1`. Symptom looks like
  pmxcfs is broken; it isn't.
- **PVE 9 firewall**: if the datacenter or node firewall is on, the CT
  defaults to DROP-inbound — open SSH (port 22) in its firewall tab or
  via `/etc/pve/firewall/<vmid>.fw` if you need to reach it from off-LAN.
- **Don't touch 100**: titan-100 is the HTPC VM with USB + RTX 2060
  passthrough; restoring `100.conf` here would do nothing (it's in
  `qemu-server/`), but be careful not to confuse the two when reading
  pct/qm output.
