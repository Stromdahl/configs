#!/usr/bin/env bash
# Non-sudo daily-use user 'couch' for SDDM autologin. No password (locked) — SDDM
# autologin handles login; password-based auth doesn't reach this account.
# `ms` (the user running install.sh) is the admin/sudo account; not touched here.
set -euo pipefail

readonly USER=couch
readonly GROUPS_NEEDED=(video render audio plugdev input dialout tty bluetooth)

# Account.
if id "$USER" &>/dev/null; then
  ok "user '$USER' already exists"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo useradd --create-home --shell /bin/bash $USER && sudo passwd -l $USER"
  else
    sudo useradd --create-home --shell /bin/bash "$USER"
    sudo passwd -l "$USER" >/dev/null
    ok "created user: $USER (password locked)"
  fi
fi

# Groups (idempotent: skip if already a member).
current_groups=""
if id "$USER" &>/dev/null; then
  current_groups="$(id -nG "$USER")"
fi
for g in "${GROUPS_NEEDED[@]}"; do
  if printf '%s\n' $current_groups | grep -qx "$g"; then
    continue
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo gpasswd -a $USER $g"
  else
    sudo gpasswd -a "$USER" "$g" >/dev/null
    ok "added $USER to $g"
  fi
done

# Pre-create XDG dirs owned by couch. `install -D -o couch` on the autostart .desktop
# (in modules/steam) would only chown the leaf; intermediates left root-owned break
# KConfig writes.
for d in .config .config/autostart .local/share .cache; do
  target="/home/$USER/$d"
  if [[ -d "$target" ]]; then
    continue
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo install -d -m 755 -o $USER -g $USER -- $target"
  else
    sudo install -d -m 755 -o "$USER" -g "$USER" -- "$target"
    ok "created $target"
  fi
done
