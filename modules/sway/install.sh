#!/usr/bin/env bash
set -euo pipefail

apt_install sway swayidle swaylock xwayland wl-clipboard grim slurp wf-recorder

link "configs/sway/config" "$HOME/.config/sway/config"
