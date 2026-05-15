#!/usr/bin/env bash
# ufw: default deny incoming + allow ssh/http/https. Idempotent — ufw rejects
# duplicate rules silently with exit 0, and `--force enable` is a no-op when
# already active.
set -euo pipefail

apt_ensure ufw

readonly PORTS=(22/tcp 80/tcp 443/tcp)

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo ufw default deny incoming"
  info "would: sudo ufw default allow outgoing"
  for p in "${PORTS[@]}"; do info "would: sudo ufw allow $p"; done
  info "would: sudo ufw --force enable"
  exit 0
fi

sudo ufw default deny incoming >/dev/null
sudo ufw default allow outgoing >/dev/null
for p in "${PORTS[@]}"; do
  sudo ufw allow "$p" >/dev/null
done
sudo ufw --force enable >/dev/null
ok "ufw active; allowed: ${PORTS[*]}"
