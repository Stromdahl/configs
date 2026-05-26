#!/usr/bin/env bash
# argon-only system tweaks. Currently just one: disable TSO/GSO/GRO on eno1 to
# work around the Intel e1000e "Detected Hardware Unit Hang" bug that took the
# host offline on 2026-05-26.
set -euo pipefail

apt_ensure ethtool

install_etc_file() {
  local name="$1" dst="$2" mode="${3:-644}"
  local src="$DOTFILES_ROOT/configs/argon-tweaks/$name"
  if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
    ok "etc ok: $dst"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $src -> $dst"
    return 1
  fi
  sudo install -D -m "$mode" -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
  return 0
}

unit_changed=0
install_etc_file nic-tx-hang-mitigation.service \
  /etc/systemd/system/nic-tx-hang-mitigation.service && unit_changed=1 || true

if [[ "${DRY_RUN:-0}" != 1 ]]; then
  if (( unit_changed )); then
    sudo systemctl daemon-reload
  fi
  if ! systemctl is-enabled --quiet nic-tx-hang-mitigation.service; then
    sudo systemctl enable nic-tx-hang-mitigation.service >/dev/null
    ok "enabled nic-tx-hang-mitigation.service"
  else
    ok "nic-tx-hang-mitigation.service already enabled"
  fi
  if ! systemctl is-active --quiet nic-tx-hang-mitigation.service; then
    sudo systemctl start nic-tx-hang-mitigation.service
    ok "started nic-tx-hang-mitigation.service"
  fi
fi
