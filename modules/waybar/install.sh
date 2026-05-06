#!/usr/bin/env bash
set -euo pipefail

apt_ensure waybar

link "configs/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "configs/waybar/style.css"    "$HOME/.config/waybar/style.css"
link "configs/waybar/scripts"      "$HOME/.config/waybar/scripts"

# User unit overrides the package's /usr/lib/systemd/user/waybar.service,
# which Requires graphical-session.target — a target this setup never starts.
# Ours is keyed on WAYLAND_DISPLAY and uses Restart=always to survive the
# boot race (xdg-desktop-portal warm-up, outputs not yet up, etc.).
link "configs/waybar/waybar.service" "$HOME/.config/systemd/user/waybar.service"

if [[ "${DRY_RUN:-0}" != 1 ]]; then
  systemctl --user daemon-reload
fi
