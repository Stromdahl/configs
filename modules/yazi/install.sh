#!/usr/bin/env bash
set -euo pipefail

apt_ensure yazi

link "configs/yazi/config" "$HOME/.config/yazi"
link "configs/yazi/yazi.sh" "$HOME/.bashrc.d/yazi.sh"
