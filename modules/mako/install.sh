#!/usr/bin/env bash
set -euo pipefail

apt_ensure mako-notifier

link "configs/mako/config" "$HOME/.config/mako/config"
