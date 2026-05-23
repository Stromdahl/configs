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

- **titan-hermes** (VMID 101) — Nous Research Hermes agent (always-on Python
  daemon calling external LLM APIs via OpenRouter). See
  `hosts/titan-hermes/modules.conf`.

Sibling on titan: **titan-100** (VMID 100, qemu-server) is the HTPC VM with
RTX 2060 passthrough — see `hosts/titan/qemu-server/100.conf`. Keep CT vs VM
numbering separate; LXCs live in the 100s starting at 101 to leave 100 to
the HTPC.

## Creating titan-hermes (VMID 101)

One-shot, run on titan. The `ms` admin user has NOPASSWD sudo; all `pvesh`
and `pct` calls need it because pmxcfs rejects connections from non-root /
non-www-data users (`[ipcs] crit: connection from bad user 1000! - rejected`).

```bash
# 1. Refresh template list and confirm Debian 13 standard is present.
sudo pveam update
sudo pveam list local | grep debian-13-standard
# If missing:
#   sudo pveam download local debian-13-standard_<version>_amd64.tar.zst

# 2. Pick the next free VMID (titan-100 occupies 100). On a fresh setup
#    this returns 101.
VMID=$(sudo pvesh get /cluster/nextid)

# 3. Create the container. Unprivileged, nesting+keyctl on so systemd-user
#    units work cleanly. 32 GiB disk fits venv + node_modules + Chromium +
#    growth headroom for session memory and skills. 4 GiB RAM gives
#    Chromium room to spike under Playwright without OOM-kill.
sudo pct create "$VMID" \
  local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname titan-hermes \
  --cores 2 --memory 4096 --swap 512 \
  --rootfs local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --ssh-public-keys <(curl -fsSL https://github.com/stromdahl.keys) \
  --onboot 1 --start 1

# 4. Inside the CT: create the ms admin user with NOPASSWD sudo and
#    stromdahl.keys for SSH. Pattern matches argon-101.
sudo pct exec "$VMID" -- bash -c '
  apt-get update && apt-get install -y sudo curl ca-certificates
  useradd -m -s /bin/bash -G sudo ms
  install -d -m 700 -o ms -g ms /home/ms/.ssh
  curl -fsSL https://github.com/stromdahl.keys \
    | install -m 600 -o ms -g ms /dev/stdin /home/ms/.ssh/authorized_keys
  echo "ms ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-ms-nopasswd
  chmod 440 /etc/sudoers.d/10-ms-nopasswd
'

# 5. Snapshot the resulting config back into this repo.
sudo pct config "$VMID" | sudo tee /tmp/"$VMID".conf >/dev/null
# (then from your workstation:)
scp titan:/tmp/<vmid>.conf hosts/titan/lxc/<vmid>.conf
```

After SSH works to the new CT, on the CT itself:

```bash
ssh ms@titan-hermes
git clone https://github.com/Stromdahl/configs ~/.dotfiles
cd ~/.dotfiles && ./install.sh --dry-run
cd ~/.dotfiles && ./install.sh
# then follow the "First-run setup" steps in hosts/titan-hermes/modules.conf
```

## Quirks

- **pvesh / pct as ms**: pmxcfs only accepts root/www-data IPC. Always
  `sudo pvesh ...` and `sudo pct ...` — running them as ms (uid 1000)
  gives `ipcc_send_rec failed: Unknown error -1`. Symptom looks like
  pmxcfs is broken; it isn't.
- **PVE 9 firewall**: if the datacenter or node firewall is on, the CT
  defaults to DROP-inbound — open SSH (port 22) in its firewall tab or
  via `/etc/pve/firewall/<vmid>.fw` if you need to reach it from off-LAN.
- **Unprivileged + Chromium**: Playwright runs headless Chromium with
  its own `--no-sandbox` in CI/server envs, so no kernel-side fiddling
  needed. If Chromium fails to start with seccomp errors, add
  `lxc.apparmor.profile: unconfined` (last resort — weakens isolation).
- **Sandbox backend**: Hermes config defaults to `local` (tools run in
  the CT as the ms user; the LXC itself is the isolation boundary). If
  you ever switch to the `docker` backend, install docker in the CT —
  nesting is already on.
- **Don't touch 100**: titan-100 is the HTPC VM with USB + RTX 2060
  passthrough; restoring `100.conf` here would do nothing (it's in
  `qemu-server/`), but be careful not to confuse the two when reading
  pct/qm output.
