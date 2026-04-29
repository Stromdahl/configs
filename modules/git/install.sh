#!/usr/bin/env bash
set -euo pipefail

link "configs/git/gitconfig" "$HOME/.gitconfig"
link "configs/git/git.sh"    "$HOME/.bashrc.d/git.sh"
