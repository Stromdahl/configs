#!/usr/bin/env bash
# Install python toolchain (system python + virtualenvwrapper) and link
# the python bashrc.d snippet.
set -euo pipefail

apt_ensure python3 python3-pip virtualenvwrapper

link "configs/python/python.sh" "$HOME/.bashrc.d/python.sh"
