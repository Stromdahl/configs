#!/usr/bin/env bash
set -euo pipefail

apt_install mako-notifier

link "configs/mako/config" "$HOME/.config/mako/config"
