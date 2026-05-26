#!/usr/bin/env bash
# Install docker (Debian-packaged) + docker compose plugin and link the
# docker bashrc.d snippet.
set -euo pipefail

apt_ensure docker.io docker-compose

# Let the current user run docker without sudo. Idempotent: usermod -aG is a
# no-op if already a member. The group membership takes effect on next login.
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$USER"
  info "added $USER to docker group (effective on next login)"
fi

link "configs/docker/docker.sh" "$HOME/.bashrc.d/docker.sh"
