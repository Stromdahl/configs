# shellcheck shell=bash
# Syncthing bash completion.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

command -v syncthing &>/dev/null && complete -C /usr/bin/syncthing syncthing
