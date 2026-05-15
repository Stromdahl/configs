#!/usr/bin/env bash
# qemu-guest-agent — the in-guest helper that talks to the QEMU/Proxmox host over
# the virtio-serial channel. Enables: clean ACPI shutdown from the host, the
# guest's IP showing up in the Proxmox UI, and fsfreeze-for-consistent-backup.
# On the Proxmox host the channel still has to be enabled per-VM:
#   qm set <vmid> --agent enabled=1
set -euo pipefail

apt_ensure qemu-guest-agent

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo systemctl enable --now qemu-guest-agent"
  exit 0
fi

if systemctl is-active qemu-guest-agent &>/dev/null && systemctl is-enabled qemu-guest-agent &>/dev/null; then
  ok "qemu-guest-agent already active+enabled"
else
  sudo systemctl enable --now qemu-guest-agent
  ok "qemu-guest-agent enabled+started"
fi
