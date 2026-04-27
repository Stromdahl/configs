#!/usr/bin/env bash
set -euo pipefail

link "configs/miscelanius/user-dirs.dirs" "$HOME/.config/user-dirs.dirs"

if [[ -f "$DOTFILES_ROOT/configs/miscelanius/xsessionrc" ]]; then
  link "configs/miscelanius/xsessionrc" "$HOME/.xsessionrc"
fi
