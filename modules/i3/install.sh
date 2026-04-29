#!/usr/bin/env bash
# Legacy X11 fallback.
set -euo pipefail

apt_ensure i3 i3status

link "configs/i3"       "$HOME/.config/i3"
link "configs/i3status" "$HOME/.config/i3status"

# i3 keybindings call workspace_set / workmode by name — they need to be in PATH.
mkdir -p "$HOME/.local/bin"
for f in "$DOTFILES_ROOT"/bin/desktop/*; do
  [[ -f "$f" && -x "$f" ]] || continue
  link "$f" "$HOME/.local/bin/$(basename -- "$f")"
done
