#!/usr/bin/env bash
# BlueZ + firmware. couch is already in 'bluetooth' group (modules/couch-user).
# Controller pairing is interactive (KDE's bluedevil applet or `bluetoothctl`).
set -euo pipefail

apt_ensure bluez bluez-tools bluez-firmware

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo systemctl enable --now bluetooth"
  exit 0
fi

if systemctl is-active bluetooth &>/dev/null && systemctl is-enabled bluetooth &>/dev/null; then
  ok "bluetooth service already active+enabled"
else
  sudo systemctl enable --now bluetooth
  ok "bluetooth enabled+started"
fi
