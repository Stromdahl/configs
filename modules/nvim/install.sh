#!/usr/bin/env bash
# Install nvim from GitHub releases (via configs/nvim/nvim-install)
# and symlink the config dir.
set -euo pipefail

apt_ensure build-essential

link "configs/nvim" "$HOME/.config/nvim"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would run: $DOTFILES_ROOT/configs/nvim/nvim-install"
  exit 0
fi

bash "$DOTFILES_ROOT/configs/nvim/nvim-install"
