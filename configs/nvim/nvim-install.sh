#!/usr/bin/env bash
set -euo pipefail

# Config
VERSION_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/nvim-version"
PREFIX="$HOME/.local"
BIN_DIR="$PREFIX/bin"
BASE_DIR="$PREFIX/neovim"

# Read version tag
if [[ ! -f "$VERSION_FILE" ]]; then
  cat >&2 <<EOF
Error: missing version file: $VERSION_FILE

Create it with one line containing the desired Neovim release tag, e.g.:

  stable
  nightly
  v0.11.4
  0.11.4

EOF
  exit 1
fi

raw_ver="$(tr -d ' \t\n' < "$VERSION_FILE")"
case "$raw_ver" in
  stable|nightly|v[0-9]*.[0-9]*.*) TAG="$raw_ver" ;;
  [0-9]*.[0-9]*.*) TAG="v$raw_ver" ;;
  *) echo "invalid version in $VERSION_FILE: '$raw_ver'" >&2; exit 1 ;;
esac
INSTALL_DIR="$BASE_DIR/$TAG"

# Fast-path: already installed and linked
if [[ -x "$BIN_DIR/nvim" ]] && command -v realpath >/dev/null 2>&1; then
  target="$(realpath "$BIN_DIR/nvim" 2>/dev/null || true)"
  if [[ -n "${target:-}" && "$target" == "$INSTALL_DIR/bin/nvim" && -x "$target" ]]; then
    echo "nvim $TAG already installed at $INSTALL_DIR and linked at $BIN_DIR/nvim"
    exit 0
  fi
fi

# If installation exists but symlink not updated, just relink
if [[ -x "$INSTALL_DIR/bin/nvim" ]]; then
  mkdir -p "$BIN_DIR"
  ln -sf "$INSTALL_DIR/bin/nvim" "$BIN_DIR/nvim"
  echo "linked existing nvim $TAG -> $BIN_DIR/nvim"
  exit 0
fi

# Detect OS/arch and asset
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64|amd64) ASSET_BASE="nvim-linux-x86_64" ;;
      aarch64|arm64) ASSET_BASE="nvim-linux-arm64" ;;
      *) echo "unsupported arch on Linux: $ARCH"; exit 1 ;;
    esac
    ;;
  Darwin)
    case "$ARCH" in
      x86_64) ASSET_BASE="nvim-macos-x86_64" ;;
      arm64)  ASSET_BASE="nvim-macos-arm64" ;;
      *) echo "unsupported arch on macOS: $ARCH"; exit 1 ;;
    esac
    ;;
  *) echo "unsupported OS: $OS"; exit 1 ;;
esac

ASSET_TGZ="${ASSET_BASE}.tar.gz"
BASE_URL="https://github.com/neovim/neovim/releases/download/${TAG}"
URL_TGZ="${BASE_URL}/${ASSET_TGZ}"
URL_SHA="${URL_TGZ}.sha256sum"   # optional

# Prep
mkdir -p "$BIN_DIR" "$BASE_DIR"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Download
echo "→ fetching $URL_TGZ"
curl -fL --retry 3 -o "$WORK/$ASSET_TGZ" "$URL_TGZ"

# Optional checksum
if curl -fsL -o "$WORK/${ASSET_TGZ}.sha256sum" "$URL_SHA"; then
  echo "→ verifying checksum"
  (cd "$WORK" && sha256sum -c "${ASSET_TGZ}.sha256sum") || {
    echo "warning: checksum mismatch; continuing" >&2
  }
fi

# Install
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$WORK/$ASSET_TGZ" -C "$INSTALL_DIR" --strip-components=1
ln -sf "$INSTALL_DIR/bin/nvim" "$BIN_DIR/nvim"

echo "✔ installed: $("$BIN_DIR/nvim" --version | head -n1)"
echo "bin: $BIN_DIR/nvim"
case ":$PATH:" in *":$BIN_DIR:"*) : ;; *) echo "add to PATH: export PATH=\"$BIN_DIR:\$PATH\"" ;; esac
