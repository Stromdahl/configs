#!/usr/bin/env bash
# Nous Research Hermes agent (https://github.com/NousResearch/hermes-agent).
# Runs the upstream installer once, idempotently, leaving `hermes update`
# as the supported update mechanism going forward.
#
# Upstream installer behavior (scripts/install.sh from main):
#   - clones repo to ~/.hermes/hermes-agent
#   - sudo apt installs: build-essential python3-dev libffi-dev ripgrep ffmpeg
#   - installs uv + Python 3.11 venv, `uv pip install -e '.[all]'`
#   - installs Node 22 + `npm install` + Playwright Chromium
#     (sudo npx playwright install-deps chromium)
#   - drops launcher at ~/.local/bin/hermes
#   - appends `export PATH="$HOME/.local/bin:$PATH"` to ~/.bashrc, ~/.zshrc,
#     ~/.profile UNLESS ~/.local/bin is already on PATH
#
# Symlink note: bash-server links ~/.bashrc -> dotfiles/configs/bash/bashrc-server.
# bashrc-server already exports ~/.local/bin on PATH, so pre-exporting it
# here makes the installer skip its rc-file appends entirely — otherwise
# the `>> ~/.bashrc` would follow the symlink and edit the repo file.
set -euo pipefail

readonly HERMES_INSTALLER_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
readonly HERMES_BIN="$HOME/.local/bin/hermes"
readonly HERMES_HOME="$HOME/.hermes"
readonly ENV_EXAMPLE_DST="$HERMES_HOME/.env.example"

# apt prereqs the upstream installer would `sudo apt install` itself. Doing
# it here means our log shows it (and DRY_RUN previews it) instead of the
# upstream curl-pipe deciding silently.
apt_ensure curl ca-certificates git \
  build-essential python3-dev libffi-dev \
  ripgrep ffmpeg

if [[ -x "$HERMES_BIN" ]]; then
  ok "hermes already installed at $HERMES_BIN"
  info "to update: hermes update"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: curl -fsSL $HERMES_INSTALLER_URL | bash"
    info "would: install hermes-agent + uv + Python 3.11 venv + Node 22 + Playwright Chromium"
  else
    info "running upstream hermes installer (this clones, builds, and installs Chromium — minutes)"
    # Pre-export PATH so installer skips its `>> ~/.bashrc` append (avoids
    # following the bashrc symlink into the dotfiles repo).
    export PATH="$HOME/.local/bin:$PATH"
    curl -fsSL --retry 3 -- "$HERMES_INSTALLER_URL" | bash
    [[ -x "$HERMES_BIN" ]] || die "hermes installer ran but $HERMES_BIN not found"
    ok "hermes installed at $HERMES_BIN"
  fi
fi

# Drop a commented env template alongside ~/.hermes/.env. We intentionally
# don't auto-create .env — the user picks a provider at first run.
mkdir -p -- "$HERMES_HOME"
link "configs/hermes/env.example" "$ENV_EXAMPLE_DST"

if [[ ! -e "$HERMES_HOME/.env" ]]; then
  warn "no $HERMES_HOME/.env yet — to configure:"
  warn "  cp $ENV_EXAMPLE_DST $HERMES_HOME/.env"
  warn "  \$EDITOR $HERMES_HOME/.env    # uncomment one provider's key"
  warn "  hermes model                 # then pick a model"
fi
