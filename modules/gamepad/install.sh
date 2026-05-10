#!/usr/bin/env bash
# Lightweight controller verification: jstest CLI + GUI. The in-kernel xpad driver
# handles current Xbox controllers (USB + BT). xpadneo DKMS is not in Debian repos
# and is left out of scope.
set -euo pipefail

apt_ensure joystick jstest-gtk
