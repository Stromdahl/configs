#!/usr/bin/env bash
# SSH: authorized_keys from github.com/stromdahl.keys + symlink ssh config.
set -euo pipefail

readonly KEYS_URL="https://github.com/stromdahl.keys"

mkdir -p -- "$HOME/.ssh"
chmod 700 -- "$HOME/.ssh"

link "configs/ssh/config" "$HOME/.ssh/config"

tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: fetch $KEYS_URL -> ~/.ssh/authorized_keys"
  exit 0
fi

curl -fsSL --retry 3 -o "$tmp" -- "$KEYS_URL"

[[ -s "$tmp" ]] || die "fetched key file is empty — refusing to overwrite authorized_keys"
if ! grep -Eq '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[^ ]+|sk-(ssh-ed25519|ecdsa-sha2-[^ ]+)@openssh\.com) ' -- "$tmp"; then
  die "fetched content does not look like SSH public keys; refusing"
fi

if [[ -f "$HOME/.ssh/authorized_keys" ]] && cmp -s -- "$tmp" "$HOME/.ssh/authorized_keys"; then
  ok "authorized_keys already current (from $KEYS_URL)"
else
  install -m 600 -- "$tmp" "$HOME/.ssh/authorized_keys"
  ok "authorized_keys updated from $KEYS_URL"
fi
