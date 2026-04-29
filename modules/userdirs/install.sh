#!/usr/bin/env bash
set -euo pipefail

link "configs/miscellaneous/user-dirs.dirs" "$HOME/.config/user-dirs.dirs"

if [[ -f "$DOTFILES_ROOT/configs/miscellaneous/xsessionrc" ]]; then
  link "configs/miscellaneous/xsessionrc" "$HOME/.xsessionrc"
fi
