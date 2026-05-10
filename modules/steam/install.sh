#!/usr/bin/env bash
# Steam (apt — flatpak Steam on NVIDIA has GL-runtime version friction) plus the
# udev rules for controllers (steam-devices is NOT a transitive dep of steam-installer)
# and a Big-Picture autostart .desktop for the 'couch' user.
set -euo pipefail

apt_ensure steam-installer steam-devices

readonly SRC="$DOTFILES_ROOT/configs/steam/steam-big-picture.desktop"
readonly DST=/home/couch/.config/autostart/steam-big-picture.desktop

# Only install the autostart file once couch exists (couch-user runs earlier in
# modules.conf). In dry-run on a fresh box, couch may not exist yet — fall back
# to a "would:" message.
if ! id couch &>/dev/null; then
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install (after couch-user runs): $SRC -> $DST"
    exit 0
  fi
  die "user 'couch' does not exist yet — couch-user module must run before steam"
fi

if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "Big Picture autostart already current: $DST"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $SRC -> $DST (owner couch:couch)"
  exit 0
fi

sudo install -D -m 644 -o couch -g couch -- "$SRC" "$DST" || die "failed to install $DST"
ok "installed: $DST"
