#!/usr/bin/env bash
# Install Hermes Agent (NousResearch) + scaffold the long-term-memory vault.
#
# Layers on top of the `syncthing` module: the vault at ~/hermes-vault is
# intended to be added as a Syncthing folder via the web UI / `syncthing
# cli` after install. This module does not manage the share — matches the
# existing non-declarative syncthing pattern (see modules/syncthing/).
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

# Scaffold the vault. mkdir -p is idempotent; the per-file copy below is
# no-clobber so re-runs never overwrite agent edits.
VAULT="$HOME/hermes-vault"
SKEL="$DOTFILES_ROOT/configs/hermes-agent/vault-skeleton"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: mkdir -p $VAULT/{Daily,Inbox,Work,Personal,People,System/Assistant/logs}"
  info "would: copy seed files from $SKEL into $VAULT (no-clobber)"
else
  mkdir -p -- \
    "$VAULT/Daily" \
    "$VAULT/Inbox" \
    "$VAULT/Work" \
    "$VAULT/Personal" \
    "$VAULT/People" \
    "$VAULT/System/Assistant/logs"
  # Walk the skeleton and copy each file only if absent. GNU `cp -n` would
  # do this too, but explicit is friendlier when nothing got skipped vs.
  # everything got skipped.
  while IFS= read -r -d '' rel; do
    dst="$VAULT/$rel"
    if [[ -e "$dst" ]]; then
      dim "vault: keep existing $rel"
    else
      mkdir -p -- "$(dirname -- "$dst")"
      cp -- "$SKEL/$rel" "$dst"
      ok "vault: seed $rel"
    fi
  done < <(cd "$SKEL" && find . -type f -printf '%P\0')
fi

# Next-steps banner — printed every run; purely informational.
cat >&2 <<EOF

  hermes-agent next steps:
  1. cp ~/.hermes/env.example ~/.hermes/.env   # then edit
     (paste OPENROUTER_API_KEY; prepaid credits only, auto-recharge OFF).
  2. hermes setup                              # pick default model.
  3. Syncthing web UI (http://127.0.0.1:8384):
     add folder ~/hermes-vault and share it with your other devices.
  4. hermes                                    # start a session.

EOF
