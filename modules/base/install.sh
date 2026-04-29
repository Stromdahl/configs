#!/usr/bin/env bash
# Core packages every workstation needs, plus PATH linking for bin/ scripts.
set -euo pipefail

apt_ensure \
  git curl ca-certificates jq build-essential bash-completion \
  xclip ripgrep

mkdir -p "$HOME/.local/bin"
for f in "$DOTFILES_ROOT"/bin/*; do
  [[ -f "$f" && -x "$f" ]] || continue
  link "$f" "$HOME/.local/bin/$(basename -- "$f")"
done
