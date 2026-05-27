#!/usr/bin/env bash
# Scaffold the Hermes long-term-memory vault at ~/hermes-vault.
#
# The vault is the "warm tier" of the three-tier memory pattern: a stable,
# Obsidian-style tree of reference files that the Hermes binary reads via
# its `obsidian` skill. This module sets up only the directory + seed
# files; it does NOT install the agent (see modules/hermes-agent) and does
# NOT manage the Syncthing share (see modules/syncthing — share setup is
# non-declarative, done once via `syncthing cli`).
set -euo pipefail

VAULT="$HOME/hermes-vault"
SKEL="$DOTFILES_ROOT/configs/hermes-agent/vault-skeleton"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: mkdir -p $VAULT/{Daily,Inbox,Work,Personal,People,System/Assistant/logs}"
  info "would: copy seed files from $SKEL into $VAULT (no-clobber)"
  exit 0
fi

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

# Marker guard — only on hosts running the Hermes agent. The agent
# autonomously reorganizes the vault and deletes Syncthing's .stfolder marker,
# which safety-halts the share until the marker is restored + a rescan runs. A
# user path-unit watches the vault and does exactly that within seconds.
if [[ -d "$HOME/.hermes" ]]; then
  link "configs/hermes-vault/systemd/hermes-vault-marker.path" \
       "$HOME/.config/systemd/user/hermes-vault-marker.path"
  link "configs/hermes-vault/systemd/hermes-vault-marker.service" \
       "$HOME/.config/systemd/user/hermes-vault-marker.service"
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: systemctl --user daemon-reload + enable --now hermes-vault-marker.path"
  else
    systemctl --user daemon-reload
    systemctl --user enable --now hermes-vault-marker.path
    "$DOTFILES_ROOT/bin/hermes-vault-ensure-marker.sh" || true
    ok "hermes-vault marker guard active (hermes-vault-marker.path)"
  fi
else
  dim "hermes-vault: no ~/.hermes — skipping agent marker guard"
fi
