#!/usr/bin/env bash
# Install rustup (latest) and link the rust bashrc.d snippet.
set -euo pipefail

link "configs/rust/rust.sh" "$HOME/.bashrc.d/rust.sh"

apt_ensure curl

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install or update rustup"
  exit 0
fi

if command -v rustup >/dev/null 2>&1; then
  rustup self update
  ok "rustup: updated"
else
  # --no-modify-path keeps the installer out of our shell rc files;
  # configs/rust/rust.sh is what loads cargo into our shells.
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  ok "rustup: installed"
fi
