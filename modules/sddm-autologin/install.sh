#!/usr/bin/env bash
# SDDM autologin into Plasma Wayland for the 'couch' user. Also flips the system
# default target to graphical (Debian no-desktop installs default to multi-user).
# Session=plasma.desktop is the Wayland session shipped by plasma-workspace; the
# X11 session (plasmax11.desktop) remains selectable in the SDDM picker after logout.
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

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo systemctl set-default graphical.target && sudo systemctl enable sddm"
  exit 0
fi

# Default target: only flip if not already graphical.
current_default="$(systemctl get-default 2>/dev/null || echo unknown)"
if [[ "$current_default" != "graphical.target" ]]; then
  sudo systemctl set-default graphical.target >/dev/null
  ok "default target -> graphical.target (was $current_default)"
else
  ok "default target already graphical.target"
fi

# Enable sddm (no --now; SDDM owns the graphical session, leave start to next boot).
if systemctl is-enabled sddm &>/dev/null; then
  ok "sddm already enabled"
else
  sudo systemctl enable sddm >/dev/null
  ok "sddm enabled"
fi
