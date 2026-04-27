#!/usr/bin/env bash
set -euo pipefail

apt_install kanshi

link "configs/kanshi/config" "$HOME/.config/kanshi/config"
