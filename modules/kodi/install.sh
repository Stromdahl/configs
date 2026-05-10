#!/usr/bin/env bash
# Kodi 21.x Omega from Debian main. Jellyfin/Plex add-ons are added from inside
# Kodi (account credentials; not scripted).
set -euo pipefail

apt_ensure kodi
