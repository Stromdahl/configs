#!/usr/bin/env bash
# Install fzf and link the fzf bashrc.d snippet.
set -euo pipefail

apt_ensure fzf

link "configs/fzf/fzf.sh" "$HOME/.bashrc.d/fzf.sh"
