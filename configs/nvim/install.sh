#!/bin/sh

set -e

REQUIRED_VERSION="v0.10.0"
INSTALL_DIR="/usr/local/bin"

# Check current version
get_nvim_version() {
  if command -v nvim >/dev/null 2>&1; then
    nvim --version | head -n1 | awk '{print $2}'
  else
    echo "none"
  fi
}

version_lt() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

install_nvim() {
  echo "Installing Neovim $REQUIRED_VERSION..."

  TMP_DIR=$(mktemp -d)
  ARCHIVE_URL="https://github.com/neovim/neovim/releases/download/v$REQUIRED_VERSION/nvim-linux64.tar.gz"

  echo "Downloading from $ARCHIVE_URL"
  curl -L "$ARCHIVE_URL" -o "$TMP_DIR/nvim.tar.gz"

  echo "Extracting..."
  tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

  echo "Installing to $INSTALL_DIR..."
  sudo cp "$TMP_DIR/nvim-linux64/bin/nvim" "$INSTALL_DIR/nvim"

  echo "Cleaning up..."
  rm -rf "$TMP_DIR"

  echo "Neovim $REQUIRED_VERSION installed successfully."
}

CURRENT_VERSION=$(get_nvim_version)

if [ "$CURRENT_VERSION" = "none" ]; then
  echo "Neovim not found."
  install_nvim
elif version_lt "$CURRENT_VERSION" "$REQUIRED_VERSION"; then
  echo "Neovim version $CURRENT_VERSION is less than required $REQUIRED_VERSION."
  install_nvim
else
  echo "Neovim version $CURRENT_VERSION meets the requirement."
fi
