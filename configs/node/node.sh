# shellcheck shell=bash
# Node toolchain: nvm + Yarn Switch.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

# Yarn Switch
[ -s "$HOME/.yarn/switch/env" ] && source "$HOME/.yarn/switch/env"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
