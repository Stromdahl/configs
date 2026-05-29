#!/usr/bin/env bash
# Network helpers: probe(1) on PATH and a bashrc.d snippet that adds
# `ports`, `publicip`, and the `hermes` SSH launcher.
set -euo pipefail

link "bin/probe" "$HOME/.local/bin/probe"
link "configs/network-tools/network-tools.sh" "$HOME/.bashrc.d/network-tools.sh"
