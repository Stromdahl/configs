#!/usr/bin/env bash
# Install tmux, link its config dir, and bootstrap TPM (the tmux plugin
# manager). TPM is cloned into an XDG data dir OUTSIDE the repo — ~/.config/tmux
# is a symlink into this tree, so TPM's default path would clone plugins
# straight into the working tree. The plugins themselves are declared in
# configs/tmux/tmux.conf; install them inside tmux with  C-b I .
# Clipboard yanks use wl-copy, from the wl-clipboard module.
set -euo pipefail

apt_ensure tmux git

link "configs/tmux" "$HOME/.config/tmux"

TPM_DIR="$HOME/.local/share/tmux/plugins/tpm"

if [[ -d "$TPM_DIR/.git" ]]; then
  info "tpm already cloned"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would clone tpm into $TPM_DIR"
  exit 0
fi

git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
ok "tpm: cloned into $TPM_DIR"
info "inside tmux, press  C-b I  to install the configured plugins"
