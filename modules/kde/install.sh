#!/usr/bin/env bash
# KDE Plasma 6 desktop + SDDM. task-kde-desktop is the Debian-recommended metapackage
# (same set d-i's KDE task installs). Pulls Plasma 6.3.x (Trixie), SDDM, plasma-nm,
# bluedevil, kscreen, powerdevil. Both Wayland and X11 Plasma sessions ship.
set -euo pipefail

apt_ensure task-kde-desktop sddm kde-config-gtk-style

# Boot to a graphical login. A Debian no-desktop base install defaults to
# multi-user.target and leaves sddm's enablement to its postinst; make it
# deterministic here so any KDE host comes up at SDDM (the couch layer's
# sddm-autologin module layers autologin on top, but must not be required for
# a plain desk install to reach a login).
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo systemctl set-default graphical.target && sudo systemctl enable sddm"
  exit 0
fi

current_default="$(systemctl get-default 2>/dev/null || echo unknown)"
if [[ "$current_default" != "graphical.target" ]]; then
  sudo systemctl set-default graphical.target >/dev/null
  ok "default target -> graphical.target (was $current_default)"
else
  ok "default target already graphical.target"
fi

if systemctl is-enabled sddm &>/dev/null; then
  ok "sddm already enabled"
else
  sudo systemctl enable sddm >/dev/null
  ok "sddm enabled"
fi
