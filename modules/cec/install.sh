#!/usr/bin/env bash
# HDMI-CEC userspace for the future Pulse-Eight USB-CEC adapter. NVIDIA GPUs do
# not pass CEC on Linux; the adapter plugs in via USB and appears as /dev/ttyACM0.
# couch is already in dialout+tty groups (modules/couch-user).
set -euo pipefail

apt_ensure cec-utils libcec6
