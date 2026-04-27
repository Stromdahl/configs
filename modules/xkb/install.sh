#!/usr/bin/env bash
# System-wide X11 keyboard option overlay (caps->escape, rwin->level3 switch).
# Only meaningful on X11; harmless on pure Wayland/sway hosts.
set -euo pipefail

readonly SRC="$DOTFILES_ROOT/configs/miscelanius/90-custom-xkb.conf"
readonly DST="/etc/X11/xorg.conf.d/90-custom-xkb.conf"

[[ -f "$SRC" ]] || die "missing $SRC"

if [[ -f "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "xkb: $DST already up to date"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo install -m 644 $SRC $DST"
  exit 0
fi

sudo install -D -m 644 -- "$SRC" "$DST"
ok "xkb: installed $DST"
