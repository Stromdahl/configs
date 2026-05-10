#!/usr/bin/env bash
# KDE Plasma 6 desktop + SDDM. task-kde-desktop is the Debian-recommended metapackage
# (same set d-i's KDE task installs). Pulls Plasma 6.3.x (Trixie), SDDM, plasma-nm,
# bluedevil, kscreen, powerdevil. Both Wayland and X11 Plasma sessions ship.
set -euo pipefail

apt_ensure task-kde-desktop sddm kde-config-gtk-style
