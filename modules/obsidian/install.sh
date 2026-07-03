#!/usr/bin/env bash
# Obsidian (markdown knowledge base) on the workstation. Not packaged in Debian,
# so we install the upstream AppImage pinned to $VERSION under ~/.local/opt, plus
# a generated .desktop entry so it appears in the wofi launcher and handles
# obsidian:// links. Bump $VERSION to upgrade (the AppImage is re-downloaded and
# the launcher entry rewritten on the next run).
#
# The Flathub flatpak (md.obsidian.Obsidian) is the lower-maintenance alternative
# but sandboxes filesystem access; the AppImage sees the whole home dir, which
# suits vaults living outside ~/Documents (e.g. ~/notes).
set -euo pipefail

readonly VERSION=1.12.7
readonly DEST="$HOME/.local/opt/obsidian"
readonly APPIMAGE="$DEST/Obsidian-$VERSION.AppImage"
readonly ICON="$DEST/obsidian.png"
readonly URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v$VERSION/Obsidian-$VERSION.AppImage"
readonly APPS_DIR="$HOME/.local/share/applications"
readonly DESKTOP="$APPS_DIR/obsidian.desktop"

# libfuse2 is what type-2 AppImages need to self-mount (Debian 13 ships fuse3 by
# default); curl fetches the release asset.
apt_ensure libfuse2t64 curl

# --- icon (512px, extracted from this AppImage version) -------------------
link "configs/obsidian/obsidian.png" "$ICON"

# --- AppImage binary ------------------------------------------------------
if [[ -x "$APPIMAGE" ]]; then
  ok "obsidian AppImage present: $APPIMAGE"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would download $URL -> $APPIMAGE"
else
  require_cmd curl
  mkdir -p -- "$DEST"
  tmp="$(mktemp "$DEST/.download.XXXXXX")"
  trap 'rm -f -- "$tmp"' EXIT
  info "downloading Obsidian $VERSION (~124 MB) ..."
  curl -fL --retry 3 -o "$tmp" -- "$URL" || die "download failed: $URL"
  chmod +x -- "$tmp"
  mv -f -- "$tmp" "$APPIMAGE"
  trap - EXIT
  ok "installed AppImage: $APPIMAGE"
fi

# --- launcher entry -------------------------------------------------------
# Exec carries the versioned path + --no-sandbox (as upstream's own entry does),
# so a $VERSION bump rewrites this file. cmp -s keeps re-runs a no-op.
desktop_tmp="$(mktemp)"
cat > "$desktop_tmp" <<EOF
[Desktop Entry]
Type=Application
Name=Obsidian
Comment=Markdown knowledge base
Exec=$APPIMAGE --no-sandbox %U
Icon=$ICON
Terminal=false
Categories=Office;
StartupWMClass=obsidian
MimeType=x-scheme-handler/obsidian;
EOF

if [[ -r "$DESKTOP" ]] && cmp -s -- "$desktop_tmp" "$DESKTOP"; then
  ok "launcher entry current: $DESKTOP"
  rm -f -- "$desktop_tmp"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would write launcher entry: $DESKTOP"
  rm -f -- "$desktop_tmp"
else
  mkdir -p -- "$APPS_DIR"
  install -m 644 -- "$desktop_tmp" "$DESKTOP"
  rm -f -- "$desktop_tmp"
  ok "wrote launcher entry: $DESKTOP"
  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
