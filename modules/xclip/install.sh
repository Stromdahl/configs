#!/usr/bin/env bash
# Install xclip and link the xclip bashrc.d snippet (clipboard aliases).
set -euo pipefail

apt_ensure xclip

link "configs/xclip/xclip.sh" "$HOME/.bashrc.d/xclip.sh"
