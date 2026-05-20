# VM config snapshots — argon (Proxmox VE)

Reference copies of `/etc/pve/nodes/argon/qemu-server/<vmid>.conf`. Proxmox
owns the live files via pmxcfs; these aren't auto-applied. Update by hand
when a VM config changes meaningfully:

```bash
ssh argon 'sudo /usr/sbin/qm config <vmid>' > hosts/argon/qemu-server/<vmid>.conf
git add hosts/argon/qemu-server/<vmid>.conf
```

To restore from a snapshot (disaster recovery, VM stopped):

```bash
scp hosts/argon/qemu-server/<vmid>.conf argon:/tmp/<vmid>.conf
ssh argon 'sudo cp /tmp/<vmid>.conf /etc/pve/nodes/argon/qemu-server/<vmid>.conf'
```

## VMs

- **home-assistant** (VMID TBD) — HAOS VM. Snapshot config once we record the VMID.
- **netbird router** (VMID TBD) — planned Debian 13 VM acting as the single
  NetBird routing peer that advertises `192.168.1.0/24` to remote peers.
