#!/usr/bin/env bash
# Lightweight controller verification: jstest CLI + GUI. The in-kernel xpad driver
# handles current Xbox controllers (USB + BT). xpadneo DKMS is not in Debian repos
# and is left out of scope.
#
# Also ships a udev rule for the 8BitDo Pro 3 Receiver to disable USB autosuspend
# (see configs/gamepad/81-8bitdo-pro-3.rules).
set -euo pipefail

apt_ensure joystick jstest-gtk

readonly RULE_SRC="$DOTFILES_ROOT/configs/gamepad/81-8bitdo-pro-3.rules"
readonly RULE_DST=/etc/udev/rules.d/81-8bitdo-pro-3.rules

if [[ -r "$RULE_DST" ]] && cmp -s -- "$RULE_SRC" "$RULE_DST"; then
  ok "udev rule already current: $RULE_DST"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $RULE_SRC -> $RULE_DST (+ udevadm reload/trigger)"
  exit 0
fi

sudo install -D -m 644 -o root -g root -- "$RULE_SRC" "$RULE_DST" || die "failed to install $RULE_DST"
ok "installed: $RULE_DST"

sudo udevadm control --reload-rules || warn "udevadm reload failed (will apply next boot)"
sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=2dc8 || warn "udevadm trigger failed (replug to apply)"
