#!/usr/bin/env bash
set -euo pipefail

apt_install yazi

link "configs/yazi" "$HOME/.config/yazi"
