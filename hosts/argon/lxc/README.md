# LXC config snapshots — argon (Proxmox VE)

Sibling to `qemu-server/`. Reference copies of `/etc/pve/nodes/argon/lxc/<vmid>.conf`.
Proxmox owns the live files via pmxcfs; these aren't auto-applied. Update by hand
when a CT config changes meaningfully:

```bash
ssh argon 'sudo /usr/sbin/pct config <vmid>' > hosts/argon/lxc/<vmid>.conf
git add hosts/argon/lxc/<vmid>.conf
```

To restore from a snapshot (disaster recovery, CT stopped):

```bash
scp hosts/argon/lxc/<vmid>.conf argon:/tmp/<vmid>.conf
ssh argon 'sudo cp /tmp/<vmid>.conf /etc/pve/nodes/argon/lxc/<vmid>.conf'
```

## CTs

- **argon-hermes** (VMID 201) — Nous Research Hermes agent (always-on Python
  daemon calling external LLM APIs). See `hosts/argon-hermes/modules.conf`.

## Creating argon-hermes (VMID 201)

One-shot, run on argon as root. Mirrors the cloud-init shape used for
argon-101 but via plain `pct create` since LXC has no cloud-init story
on Debian templates.

```bash
# 1. Refresh template list and download Debian 13 standard.
pveam update
pveam available | grep debian-13-standard
pveam download local debian-13-standard_<version>_amd64.tar.zst

# 2. Create the container. Unprivileged, nesting+keyctl on so systemd-user
#    units work cleanly. 16 GiB disk fits venv + node_modules + Chromium
#    with growth headroom for session memory.
pct create 201 \
  local:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname argon-hermes \
  --cores 2 --memory 2048 --swap 512 \
  --rootfs local-lvm:16 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --ssh-public-keys <(curl -fsSL https://github.com/stromdahl.keys) \
  --onboot 1 --start 1

# 3. Inside the CT (pct enter 201): create the ms admin user with NOPASSWD
#    sudo and stromdahl.keys for SSH. Pattern matches argon-101.
pct exec 201 -- bash -c '
  apt-get update && apt-get install -y sudo curl ca-certificates
  useradd -m -s /bin/bash -G sudo ms
  install -d -m 700 -o ms -g ms /home/ms/.ssh
  curl -fsSL https://github.com/stromdahl.keys \
    | install -m 600 -o ms -g ms /dev/stdin /home/ms/.ssh/authorized_keys
  echo "ms ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-ms-nopasswd
  chmod 440 /etc/sudoers.d/10-ms-nopasswd
'

# 4. Snapshot the resulting config back into this repo.
pct config 201 > /tmp/201.conf
# (then from your workstation:)
scp argon:/tmp/201.conf hosts/argon/lxc/201.conf
```

After SSH works to the new CT, on the CT itself:

```bash
ssh ms@argon-hermes
git clone https://github.com/Stromdahl/configs ~/.dotfiles
cd ~/.dotfiles && ./install.sh --dry-run
cd ~/.dotfiles && ./install.sh
# then follow the "First-run setup" steps in hosts/argon-hermes/modules.conf
```

## Quirks

- **PVE 9 firewall**: if the datacenter or node firewall is on, the CT
  defaults to DROP-inbound — open SSH (port 22) in its firewall tab or
  via `/etc/pve/firewall/201.fw` if you need to reach it from off-LAN.
- **Unprivileged + Chromium**: Playwright runs headless Chromium with
  its own `--no-sandbox` in CI/server envs, so no kernel-side fiddling
  needed. If Chromium fails to start with seccomp errors, add
  `lxc.apparmor.profile: unconfined` (last resort — weakens isolation).
- **Sandbox backend**: Hermes config defaults to `local` (tools run in
  the CT as the ms user). If you ever switch to the `docker` backend,
  install docker in the CT — nesting is already on.
