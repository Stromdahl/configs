#!/usr/bin/env bash
# fail2ban: ban brute-force ssh attempts (5/600s, 1h ban). Drops a single
# jail.local override that enables the sshd jail; the package's defaults are
# fine for everything else.
set -euo pipefail

apt_ensure fail2ban

readonly SRC="$DOTFILES_ROOT/configs/fail2ban/jail.local"
readonly DST=/etc/fail2ban/jail.local

changed=0
if [[ -r "$DST" ]] && cmp -s -- "$SRC" "$DST"; then
  ok "fail2ban jail.local already current: $DST"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $SRC -> $DST"
  else
    sudo install -m 644 -o root -g root -- "$SRC" "$DST" || die "failed to install $DST"
    ok "installed: $DST"
    changed=1
  fi
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: systemctl enable --now fail2ban (reload if changed)"
  exit 0
fi

if (( changed )); then
  sudo systemctl reload fail2ban 2>/dev/null || sudo systemctl restart fail2ban
fi
sudo systemctl enable --now fail2ban
ok "fail2ban enabled"
