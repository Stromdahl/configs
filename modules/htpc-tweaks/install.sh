#!/usr/bin/env bash
# HTPC-only system tweaks: disable screen-locker (couch has a locked password),
# ignore power/lid keys, mask sleep/suspend/hibernate (NVIDIA Turing + HDMI audio
# resume is a known black-screen generator), bound journald, rotate session logs.
set -euo pipefail

install_etc_file() {
  local name="$1" dst="$2"
  local src="$DOTFILES_ROOT/configs/htpc-tweaks/$name"
  if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
    ok "etc ok: $dst"
    return 1   # 1 == no change (so callers can skip post-actions)
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $src -> $dst"
    return 1
  fi
  sudo install -D -m 644 -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
  return 0   # 0 == changed
}

# Files (capture change-status to drive optional service reloads).
install_etc_file kscreenlockerrc /etc/xdg/kscreenlockerrc || true

logind_changed=0
install_etc_file 10-logind-htpc.conf /etc/systemd/logind.conf.d/10-htpc.conf && logind_changed=1 || true

journald_changed=0
install_etc_file 10-journald-htpc.conf /etc/systemd/journald.conf.d/10-htpc.conf && journald_changed=1 || true

install_etc_file htpc-sessions.logrotate /etc/logrotate.d/htpc-sessions || true

# Mask sleep targets (idempotent — second run is a no-op).
for unit in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  state="$(systemctl is-enabled "$unit" 2>/dev/null || echo unknown)"
  if [[ "$state" == "masked" ]]; then
    ok "$unit already masked"
    continue
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo systemctl mask $unit"
  else
    sudo systemctl mask "$unit" >/dev/null
    ok "masked $unit"
  fi
done

# Service reloads only when their config files changed.
if [[ "${DRY_RUN:-0}" != 1 ]]; then
  if (( logind_changed )); then
    sudo systemctl restart systemd-logind || warn "systemd-logind restart failed (will apply next boot)"
  fi
  if (( journald_changed )); then
    sudo systemctl restart systemd-journald || warn "systemd-journald restart failed (will apply next boot)"
  fi
fi
