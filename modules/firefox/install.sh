#!/usr/bin/env bash
# Firefox ESR from Debian main. The non-ESR Firefox isn't packaged in Debian; if
# Widevine / streaming-service support is wanted later, switch to the Flatpak
# org.mozilla.firefox.
set -euo pipefail

apt_ensure firefox-esr
