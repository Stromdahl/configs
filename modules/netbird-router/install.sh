#!/usr/bin/env bash
# Enables IP forwarding for a host acting as a NetBird routing peer
# (advertises a LAN subnet to remote mesh peers). Layered on top of the
# 'netbird' module — opt-in via modules.conf on routing-peer hosts only.
set -euo pipefail

readonly SRC="$DOTFILES_ROOT/configs/netbird-router/99-netbird-router.conf"
readonly DST=/etc/sysctl.d/99-netbird-router.conf

if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "sysctl drop-in already current: $DST"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $SRC -> $DST"
  info "would: sysctl --system"
  exit 0
fi

sudo install -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
ok "installed: $DST"

sudo sysctl --system >/dev/null || die "sysctl --system failed"
ok "sysctl reloaded"
