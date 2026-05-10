#!/usr/bin/env bash
# PipeWire audio stack (replaces PulseAudio). Run BEFORE kde so task-kde-desktop
# doesn't briefly install pulseaudio and then get it swapped out.
set -euo pipefail

apt_ensure pipewire-audio

readonly SRC="$DOTFILES_ROOT/configs/pipewire/51-htpc-no-suspend.conf"
readonly DST=/etc/wireplumber/wireplumber.conf.d/51-htpc-no-suspend.conf

if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "wireplumber HDMI no-suspend already current"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $SRC -> $DST"
  exit 0
fi

sudo install -D -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
ok "installed: $DST"
