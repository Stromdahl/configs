#!/usr/bin/env bash
set -euo pipefail

apt_ensure foot

link "configs/foot" "$HOME/.config/foot"
