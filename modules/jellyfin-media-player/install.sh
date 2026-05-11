#!/usr/bin/env bash
# Jellyfin Media Player from Flathub (system-wide). Picked over the upstream .deb
# to kill GitHub-tarball URL drift / version-skew / checksum-pin maintenance.
# Requires the flatpak module to have run first (flatpak + flathub remote).
set -euo pipefail

# Flathub aliases com.github.iwalton3.jellyfin-media-player to this real id.
# Use the real id so the idempotency check matches what `flatpak list` reports.
readonly APP_ID=org.jellyfin.JellyfinDesktop

# In dry-run, the flatpak module hasn't actually installed flatpak yet — report
# what we'd do and exit clean instead of bailing.
if ! command -v flatpak >/dev/null 2>&1; then
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo flatpak install -y --noninteractive flathub $APP_ID (after flatpak module runs)"
    exit 0
  fi
  die "flatpak is not installed (modules.conf must run 'flatpak' before 'jellyfin-media-player')"
fi

if flatpak list --system --app --columns=application 2>/dev/null | grep -qx "$APP_ID"; then
  ok "$APP_ID already installed"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo flatpak install -y --noninteractive flathub $APP_ID"
  exit 0
fi

sudo flatpak install -y --noninteractive flathub "$APP_ID"
ok "installed: $APP_ID"
