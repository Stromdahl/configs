#!/usr/bin/env bash
# Thin wrapper around the existing bin/setup-syncthing.sh, which is already
# idempotent (apt install, systemctl --user enable, ufw allow).
set -euo pipefail

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would run: $DOTFILES_ROOT/bin/setup-syncthing.sh"
  exit 0
fi

bash "$DOTFILES_ROOT/bin/setup-syncthing.sh"
