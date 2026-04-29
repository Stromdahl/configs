#!/usr/bin/env bash
set -euo pipefail

apt_ensure kanshi

link "configs/kanshi/config" "$HOME/.config/kanshi/config"
