#!/usr/bin/env bash
# Install nvim from GitHub releases (via configs/nvim/nvim-install)
# and symlink the config dir.
set -euo pipefail

apt_ensure build-essential

# octo.nvim's PR-review workflow needs the GitHub CLI on PATH and authenticated.
# gh ships from its own apt repo (cli.github.com), not Debian's, so don't hard-
# require it here — just nudge if it's missing. Install: https://cli.github.com
command -v gh >/dev/null || warn "nvim: octo.nvim needs the 'gh' CLI (https://cli.github.com); then run 'gh auth login'"

link "configs/nvim" "$HOME/.config/nvim"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would run: $DOTFILES_ROOT/configs/nvim/nvim-install"
  exit 0
fi

bash "$DOTFILES_ROOT/configs/nvim/nvim-install"
