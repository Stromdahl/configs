#!/usr/bin/env bash
set -euo pipefail

apt_ensure yazi

link "configs/yazi" "$HOME/.config/yazi"
