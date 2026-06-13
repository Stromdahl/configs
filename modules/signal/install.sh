#!/usr/bin/env bash
# Signal Desktop from the upstream updates.signal.org apt repo. A GUI Electron
# messenger with no daemon to manage — install and done. Linking the desktop
# app to your phone is a per-host runtime step inside the app, not handled here.
#
# NB: the repo's Suites label is the literal string `xenial` for every Debian/
# Ubuntu release — Signal serves one repo under that legacy codename. Do not
# "correct" it to stable/bookworm; that points at nothing.
set -euo pipefail

readonly KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
readonly KEYRING_DST=/usr/share/keyrings/signal-desktop-keyring.gpg

readonly SRC_FILE="$DOTFILES_ROOT/configs/signal/signal-desktop.sources"
readonly SRC_DST=/etc/apt/sources.list.d/signal-desktop.sources

# Tools needed to fetch + dearmor the upstream key.
apt_ensure curl gnupg

mutated=0

# --- GPG key --------------------------------------------------------------
if [[ -s "$KEYRING_DST" ]]; then
  ok "signal keyring already present: $KEYRING_DST"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: curl $KEY_URL | gpg --dearmor -o $KEYRING_DST"
else
  require_cmd curl gpg
  curl -fsSL -- "$KEY_URL" | sudo gpg --dearmor --yes -o "$KEYRING_DST" \
    || die "failed to install signal keyring at $KEYRING_DST"
  sudo chmod 644 -- "$KEYRING_DST"
  ok "installed signal keyring: $KEYRING_DST"
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
apt_ensure signal-desktop
