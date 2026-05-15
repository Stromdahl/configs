#!/usr/bin/env bash
# 'deploy' system user used by the git-push deploy pipeline. Authorized keys
# come from github.com/stromdahl.keys (same source as the personal `ssh`
# module). Adds deploy to the docker group if it exists — so install AFTER
# modules/docker if both are listed.
set -euo pipefail

readonly DEPLOY_USER="deploy"
readonly KEYS_URL="https://github.com/stromdahl.keys"

if id -- "$DEPLOY_USER" >/dev/null 2>&1; then
  ok "user '$DEPLOY_USER' exists"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo useradd -m -s /bin/bash $DEPLOY_USER"
  else
    sudo useradd -m -s /bin/bash -- "$DEPLOY_USER"
    ok "created user $DEPLOY_USER"
  fi
fi

# docker group membership (best-effort — silent if docker not installed)
if getent group docker >/dev/null 2>&1; then
  if id -nG -- "$DEPLOY_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    ok "$DEPLOY_USER already in docker group"
  else
    if [[ "${DRY_RUN:-0}" == 1 ]]; then
      info "would: sudo usermod -aG docker $DEPLOY_USER"
    else
      sudo usermod -aG docker -- "$DEPLOY_USER"
      ok "added $DEPLOY_USER to docker group"
    fi
  fi
else
  warn "docker group missing — install modules/docker before modules/deploy-user, or accept that deploy.sh will need sudo"
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: fetch $KEYS_URL -> ~$DEPLOY_USER/.ssh/authorized_keys"
  exit 0
fi

deploy_home="$(getent passwd -- "$DEPLOY_USER" | cut -d: -f6)"
[[ -n "$deploy_home" ]] || die "could not resolve home dir for $DEPLOY_USER"

sudo install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" -- "$deploy_home/.ssh"

tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT

curl -fsSL --retry 3 -o "$tmp" -- "$KEYS_URL"
[[ -s "$tmp" ]] || die "fetched key file is empty — refusing to overwrite authorized_keys"
if ! grep -Eq '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[^ ]+|sk-(ssh-ed25519|ecdsa-sha2-[^ ]+)@openssh\.com) ' -- "$tmp"; then
  die "fetched content does not look like SSH public keys; refusing"
fi

ak="$deploy_home/.ssh/authorized_keys"
if sudo test -f "$ak" && sudo cmp -s -- "$tmp" "$ak"; then
  ok "$DEPLOY_USER authorized_keys already current"
else
  sudo install -m 0600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" -- "$tmp" "$ak"
  ok "$DEPLOY_USER authorized_keys updated from $KEYS_URL"
fi
