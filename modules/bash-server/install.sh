#!/usr/bin/env bash
set -euo pipefail

link "configs/bash/bashrc-server" "$HOME/.bashrc"

# Ensure ~/.bashrc.d/ exists so other modules (e.g. git) can drop snippets
# without depending on whoever runs first.
mkdir -p -- "$HOME/.bashrc.d"
