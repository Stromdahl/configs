#!/usr/bin/env bash
set -euo pipefail

apt_ensure waybar

link "configs/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "configs/waybar/style.css"    "$HOME/.config/waybar/style.css"
link "configs/waybar/scripts"      "$HOME/.config/waybar/scripts"
