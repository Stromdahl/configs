#!/usr/bin/env bash
# Enable Debian's unattended-upgrades for security updates. The package's own
# defaults in /etc/apt/apt.conf.d/50unattended-upgrades already restrict to
# *-security origins; we just need to flip the periodic switches on and add
# a small local-override file.
set -euo pipefail

apt_ensure unattended-upgrades

install_etc_file() {
  local name="$1" dst="$2"
  local src="$DOTFILES_ROOT/configs/unattended-upgrades/$name"
  if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
    ok "etc ok: $dst"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $src -> $dst"
    return 0
  fi
  sudo install -m 644 -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
}

install_etc_file 20auto-upgrades            /etc/apt/apt.conf.d/20auto-upgrades
install_etc_file 52unattended-upgrades-local /etc/apt/apt.conf.d/52unattended-upgrades-local
