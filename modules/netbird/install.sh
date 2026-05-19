#!/usr/bin/env bash
# Install NetBird WireGuard mesh client (daemon + CLI) from the upstream
# pkgs.netbird.io apt repo. Headless: skips netbird-ui. Enrollment
# (`sudo netbird up --setup-key <KEY>`) is per-host runtime, not handled
# here — the daemon is enabled+started but sits idle until enrolled.
set -euo pipefail

readonly KEY_URL="https://pkgs.netbird.io/debian/public.key"
readonly KEYRING_DST=/usr/share/keyrings/netbird-archive-keyring.gpg

readonly SRC_FILE="$DOTFILES_ROOT/configs/netbird/netbird.sources"
readonly SRC_DST=/etc/apt/sources.list.d/netbird.sources

# Tools needed to fetch + dearmor the upstream key.
apt_ensure curl gnupg

mutated=0

# --- GPG key --------------------------------------------------------------
if [[ -s "$KEYRING_DST" ]]; then
  ok "netbird keyring already present: $KEYRING_DST"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: curl $KEY_URL | gpg --dearmor -o $KEYRING_DST"
else
  require_cmd curl gpg
  curl -fsSL -- "$KEY_URL" | sudo gpg --dearmor --yes -o "$KEYRING_DST" \
    || die "failed to install netbird keyring at $KEYRING_DST"
  sudo chmod 644 -- "$KEYRING_DST"
  ok "installed netbird keyring: $KEYRING_DST"
  mutated=1
fi

# --- apt source -----------------------------------------------------------
if [[ -r "$SRC_DST" ]] && cmp -s -- "$SRC_FILE" "$SRC_DST"; then
  ok "apt source already current: $SRC_DST"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $SRC_FILE -> $SRC_DST"
else
  sudo install -m 644 -o root -g root -- "$SRC_FILE" "$SRC_DST" \
    || die "failed to install $SRC_DST"
  ok "installed: $SRC_DST"
  mutated=1
fi

# Force the next apt_ensure to re-run apt-get update against the new source.
if (( mutated )) && [[ -n "${_APT_UPDATED_FLAG:-}" ]] && [[ -f "$_APT_UPDATED_FLAG" ]]; then
  rm -f -- "$_APT_UPDATED_FLAG"
  info "invalidated apt-update cache flag"
fi

# --- package --------------------------------------------------------------
apt_ensure netbird

# --- daemon ---------------------------------------------------------------
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  if systemctl is-enabled --quiet netbird 2>/dev/null; then
    info "netbird.service already enabled"
  else
    info "would: systemctl enable --now netbird"
  fi
  exit 0
fi

if ! systemctl is-enabled --quiet netbird 2>/dev/null; then
  sudo systemctl enable netbird
  ok "enabled netbird.service"
fi
if ! systemctl is-active --quiet netbird 2>/dev/null; then
  sudo systemctl start netbird
  ok "started netbird.service"
fi
