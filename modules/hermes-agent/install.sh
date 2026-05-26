#!/usr/bin/env bash
# Install the Hermes Agent binary (NousResearch) via pipx and wire up the
# operator env file. Companion to modules/hermes-vault, which scaffolds the
# long-term memory vault at ~/hermes-vault (this module does NOT depend on
# it — pipx install + env.example symlink work standalone, but a host with
# `hermes-agent` enabled almost always also wants `hermes-vault`).
#
# Hermes runs interactively after install: copy ~/.hermes/env.example to
# ~/.hermes/.env, paste the OpenRouter key, then `hermes setup`.
set -euo pipefail

apt_ensure pipx

# Idempotent install. `pipx install <pkg>` errors when already installed, so
# guard on the binary instead.
if command -v hermes >/dev/null 2>&1; then
  ok "hermes already installed: $(hermes --version 2>&1 | head -1)"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: pipx install hermes-agent"
else
  pipx install hermes-agent
  ok "installed hermes-agent (binary at ~/.local/bin/hermes)"
fi

# Operator copies this to ~/.hermes/.env. We never auto-create .env.
link "configs/hermes-agent/env.example" "$HOME/.hermes/env.example"

# Next-steps banner — printed every run; purely informational.
cat >&2 <<EOF

  hermes-agent next steps:
  1. cp ~/.hermes/env.example ~/.hermes/.env   # then edit
     (paste OPENROUTER_API_KEY; prepaid credits only, auto-recharge OFF).
  2. hermes setup                              # pick default model.
  3. hermes                                    # start a session.
  (Vault sharing via Syncthing: see modules/hermes-vault + hosts/<host>/
  modules.conf; share setup is non-declarative, done once via syncthing cli.)

EOF
