#!/usr/bin/env bash
# Host-specific blacklist layered on top of the host-agnostic 'unattended-upgrades'
# module. Drops in /etc/apt/apt.conf.d/54...-blacklist (alphabetical > 52).
set -euo pipefail

readonly SRC="$DOTFILES_ROOT/configs/unattended-upgrades-htpc/54unattended-upgrades-htpc-blacklist"
readonly DST=/etc/apt/apt.conf.d/54unattended-upgrades-htpc-blacklist

if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "htpc blacklist already current: $DST"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $SRC -> $DST"
  exit 0
fi

sudo install -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
ok "installed: $DST"
