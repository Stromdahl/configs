#!/usr/bin/env bash
# Legacy X11 fallback.
set -euo pipefail

apt_ensure i3 i3status

link "configs/i3"       "$HOME/.config/i3"
link "configs/i3status" "$HOME/.config/i3status"
