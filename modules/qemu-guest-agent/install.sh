#!/usr/bin/env bash
# qemu-guest-agent — the in-guest helper that talks to the QEMU/Proxmox host over
# the virtio-serial channel. Enables: clean ACPI shutdown from the host, the
# guest's IP showing up in the Proxmox UI, and fsfreeze-for-consistent-backup.
#
# The systemd unit is static (no [Install]) and BindsTo= the virtio-ports device,
# so it auto-starts whenever Proxmox attaches the agent channel. Don't try to
# `systemctl enable --now` it — without the channel, the start job parks for
# ~90s until timeout. We just install the package and, if the channel happens
# to already be there, kick the service. Otherwise we tell the user how to
# enable it on the Proxmox host.
set -euo pipefail

apt_ensure qemu-guest-agent

readonly CHANNEL=/dev/virtio-ports/org.qemu.guest_agent.0

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: start qemu-guest-agent if $CHANNEL exists, otherwise warn"
  exit 0
fi

if [[ -e "$CHANNEL" ]]; then
  if systemctl is-active qemu-guest-agent &>/dev/null; then
    ok "qemu-guest-agent already active"
  else
    sudo systemctl start qemu-guest-agent
    ok "qemu-guest-agent started"
  fi
else
  warn "agent channel $CHANNEL missing — enable on Proxmox host:"
  warn "  qm set <vmid> --agent enabled=1     # then stop+start the VM"
  warn "service is BindsTo= the channel and will auto-start once it appears"
fi
