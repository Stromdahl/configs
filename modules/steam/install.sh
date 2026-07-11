#!/usr/bin/env bash
# Steam (apt — flatpak Steam on NVIDIA has GL-runtime version friction) plus the
# udev rules for controllers (steam-devices is NOT a transitive dep of steam-installer).
# Steam-the-package only; the Big-Picture autostart is an HTPC concern and lives in
# the htpc-tweaks module (couch layer), so this installs cleanly on a desk rig too.
set -euo pipefail

apt_ensure steam-installer steam-devices
