#!/usr/bin/env bash
# Flatpak runtime + system-wide Flathub remote. Required for Jellyfin Media Player
# (and a clean future Widevine-Firefox path).
set -euo pipefail

apt_ensure flatpak plasma-discover-backend-flatpak

if flatpak remotes --system --columns=name 2>/dev/null | grep -qx flathub; then
  ok "flathub remote already configured"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
  exit 0
fi

sudo flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
ok "flathub remote added"
