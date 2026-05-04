#!/usr/bin/env bash
# Install wl-clipboard and link the clipboard-aliases bashrc.d snippet.
set -euo pipefail

apt_ensure wl-clipboard

link "configs/wl-clipboard/wl-clipboard.sh" "$HOME/.bashrc.d/wl-clipboard.sh"
