#!/usr/bin/env bash
# Intel CPU microcode (from non-free-firmware). Applied at next boot.
set -euo pipefail

apt_ensure intel-microcode
