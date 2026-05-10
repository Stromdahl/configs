#!/usr/bin/env bash
# Wake-on-LAN for the wired interface. Skip silently on Wi-Fi-only hosts (WoL over
# Wi-Fi requires WoWLAN support that's chipset-specific and rarely worth fighting).
set -euo pipefail

apt_ensure ethtool

readonly SRC="$DOTFILES_ROOT/configs/wol/wol@.service"
readonly DST=/etc/systemd/system/wol@.service

# Install the templated unit file (cmp-then-install).
if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "wol@.service unit already current"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $SRC -> $DST + systemctl daemon-reload"
  else
    sudo install -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
    sudo systemctl daemon-reload
    ok "installed: $DST"
  fi
fi

# Auto-detect the active wired interface from the default route.
iface="$(ip -4 route show default 2>/dev/null | awk '/^default/{print $5; exit}')"
if [[ -z "$iface" ]]; then
  warn "no default-route interface detected — WoL setup skipped"
  exit 0
fi

# Skip wireless interfaces.
if [[ -d "/sys/class/net/$iface/wireless" ]]; then
  warn "interface '$iface' is wireless — skipping WoL"
  exit 0
fi

unit="wol@${iface}.service"
if systemctl is-enabled "$unit" &>/dev/null; then
  ok "$unit already enabled"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo systemctl enable --now $unit"
  exit 0
fi

sudo systemctl enable --now "$unit"
ok "$unit enabled+started"
