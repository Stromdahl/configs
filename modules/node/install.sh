#!/usr/bin/env bash
# Install the latest nvm release and link the node bashrc.d snippet.
set -euo pipefail

link "configs/node/node.sh" "$HOME/.bashrc.d/node.sh"

apt_ensure curl

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install latest nvm"
  exit 0
fi

# Resolve the latest released nvm tag via the GitHub /releases/latest redirect
# (sidesteps the unauthenticated API rate limit).
NVM_VERSION="$(curl -fsI -o /dev/null -w '%{redirect_url}' \
  https://github.com/nvm-sh/nvm/releases/latest | sed -E 's|.*/||')"
[[ "$NVM_VERSION" =~ ^v[0-9] ]] || die "could not resolve latest nvm version"

# PROFILE=/dev/null keeps the installer out of our shell rc files;
# configs/node/node.sh is what loads nvm.
PROFILE=/dev/null bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
ok "nvm: installed $NVM_VERSION"
