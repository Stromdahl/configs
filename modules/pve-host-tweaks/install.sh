#!/usr/bin/env bash
# PVE host (titan) quirks. Currently: a udev rule + script that re-issues
# the QEMU usb-host attach for VM 100 every time the 8BitDo Pro 3 receiver
# re-enumerates (its VID/PID changes on every controller wake/sleep, which
# breaks QEMU's by-port passthrough). See configs/pve-host-tweaks/.
set -euo pipefail

install_etc_file() {
  local src="$1" dst="$2" mode="${3:-644}"
  if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
    ok "etc ok: $dst"
    return 1   # 1 == no change
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $src -> $dst"
    return 1
  fi
  sudo install -D -m "$mode" -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
  return 0   # 0 == changed
}

readonly CFG="$DOTFILES_ROOT/configs/pve-host-tweaks"

rules_changed=0
install_etc_file "$CFG/91-pve-vm100-8bitdo-reattach.rules" /etc/udev/rules.d/91-pve-vm100-8bitdo-reattach.rules && rules_changed=1 || true

install_etc_file "$CFG/pve-vm100-8bitdo-reattach" /usr/local/sbin/pve-vm100-8bitdo-reattach 755 || true

if (( rules_changed )) && [[ "${DRY_RUN:-0}" != 1 ]]; then
  sudo udevadm control --reload-rules || warn "udevadm reload failed (will apply next boot)"
fi
