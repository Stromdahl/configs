#!/usr/bin/env bash
# SDDM autologin into Plasma Wayland for the 'couch' user. Session=plasma.desktop is
# the Wayland session shipped by plasma-workspace; the X11 session (plasmax11.desktop)
# remains selectable in the SDDM picker after logout. Enabling SDDM and flipping the
# default target to graphical is the kde module's job (runs earlier), so this only
# layers the autologin config on top.
set -euo pipefail

readonly SRC="$DOTFILES_ROOT/configs/sddm-autologin/autologin.conf"
readonly DST=/etc/sddm.conf.d/autologin.conf

if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "sddm autologin already current: $DST"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $SRC -> $DST"
  else
    sudo install -D -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
    ok "installed: $DST"
  fi
fi
