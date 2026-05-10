#!/usr/bin/env bash
# One-shot bootstrap for a fresh Debian/Ubuntu machine.
#
# Usage (fresh box, repo not yet cloned):
#   wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
#
# Or, if the repo is already cloned:
#   cd ~/.dotfiles && ./bootstrap.sh
#
# Steps: apt-install git+curl, clone (or update) the repo at $DOTFILES_DIR, run
# the ssh module so authorized_keys is in place, then STOP and print the next
# step. bootstrap does prep only; the user runs install.sh themselves so they
# can dry-run, pick a module subset, or review what's about to change first.
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/Stromdahl/configs.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

say() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || die "cannot read /etc/os-release; this installer targets Debian/Ubuntu"
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
  debian:*|ubuntu:*|*:*debian*|*:*ubuntu*) ;;
  *) die "unsupported distro: ID=${ID:-?}. This installer targets Debian/Ubuntu." ;;
esac

need_pkg=()
command -v git  >/dev/null 2>&1 || need_pkg+=(git)
command -v curl >/dev/null 2>&1 || need_pkg+=(curl)
if ((${#need_pkg[@]})); then
  say "installing prerequisites: ${need_pkg[*]}"
  sudo apt-get update
  sudo apt-get install -y ca-certificates "${need_pkg[@]}"
fi

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "repo present: $DOTFILES_DIR (fetching latest)"
  git -C "$DOTFILES_DIR" fetch --prune origin
  git -C "$DOTFILES_DIR" checkout "$DOTFILES_BRANCH"
  git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_BRANCH"
elif [[ -e "$DOTFILES_DIR" ]]; then
  die "$DOTFILES_DIR exists and is not a git checkout; move it aside and re-run"
else
  say "cloning $DOTFILES_REPO -> $DOTFILES_DIR"
  git clone --branch "$DOTFILES_BRANCH" --single-branch -- "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Drop SSH keys (and ~/.ssh/config) so a future SSH session works even if the
# user delays the main install. Idempotent: re-runs are no-ops if content matches.
say "running ssh module (authorized_keys + config)"
"$DOTFILES_DIR/install.sh" --module ssh

cat >&2 <<EOF

==> bootstrap done.
    repo:    $DOTFILES_DIR
    host:    $(hostname -s)$([[ -f "$DOTFILES_DIR/hosts/$(hostname -s)/modules.conf" ]] || printf ' (no profile yet; will fall back to hosts/default/)')

next step — run install.sh manually:

    cd $DOTFILES_DIR && ./install.sh --dry-run   # preview every change
    cd $DOTFILES_DIR && ./install.sh             # apply

EOF
