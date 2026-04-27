#!/usr/bin/env bash
set -euo pipefail

apt_install foot

link "configs/foot" "$HOME/.config/foot"
