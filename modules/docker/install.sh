#!/usr/bin/env bash
# Install docker (Debian-packaged) + docker compose plugin and link the
# docker bashrc.d snippet.
set -euo pipefail

apt_ensure docker.io docker-compose

link "configs/docker/docker.sh" "$HOME/.bashrc.d/docker.sh"
