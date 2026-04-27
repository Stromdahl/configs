#!/usr/bin/env bash
# Laptops only — include in host modules.conf selectively.
set -euo pipefail

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would run: $DOTFILES_ROOT/bin/battery-guardian-installer.sh"
  exit 0
fi

bash "$DOTFILES_ROOT/bin/battery-guardian-installer.sh"
