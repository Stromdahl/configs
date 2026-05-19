#!/usr/bin/env bash
# OpenSSH server: key-only, no root. Single profile for workstations and
# servers — single-user box, so the workstation/server hardening distinction
# isn't worth two modules.
set -euo pipefail

apt_ensure openssh-server

readonly SRC="$DOTFILES_ROOT/configs/sshd/10-dotfiles.conf"
readonly DST=/etc/ssh/sshd_config.d/10-dotfiles.conf

changed=0
if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "sshd drop-in already current: $DST"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $SRC -> $DST"
  else
    sudo install -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
    ok "installed: $DST"
    changed=1
  fi
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: systemctl enable --now ssh (reload if drop-in changed)"
  exit 0
fi

if (( changed )); then
  sudo systemctl reload ssh 2>/dev/null || true
fi
sudo systemctl enable --now ssh
ok "sshd enabled"
