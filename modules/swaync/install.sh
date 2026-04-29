#!/usr/bin/env bash
set -euo pipefail

apt_ensure sway-notification-center

link "configs/swaync/config.json" "$HOME/.config/swaync/config.json"
link "configs/swaync/style.css"   "$HOME/.config/swaync/style.css"
