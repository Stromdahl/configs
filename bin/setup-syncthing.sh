#!/bin/bash
set -euo pipefail

# Setup Syncthing on Debian
# Installs syncthing, enables the user service, and opens firewall ports if ufw is active.

echo "=== Syncthing Setup ==="

# Install
if command -v syncthing &>/dev/null; then
    echo "Syncthing already installed: $(syncthing --version | head -1)"
else
    echo "Installing syncthing..."
    sudo apt update
    sudo apt install -y syncthing
fi

# Enable linger so user services keep running when the user isn't logged in
# (syncthing is a user service; without linger, SSH-only servers stop syncing
# the moment the SSH session ends). Idempotent: no-op if already enabled.
echo "Enabling linger for $USER (so syncthing runs without an SSH session)..."
sudo loginctl enable-linger "$USER"

# Enable and start user service
echo "Enabling syncthing user service..."
systemctl --user enable syncthing.service
systemctl --user start syncthing.service

# Firewall (only if ufw is active)
if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "Configuring ufw firewall rules..."
    sudo ufw allow 22000/tcp comment "Syncthing sync"
    sudo ufw allow 21027/udp comment "Syncthing discovery"
else
    echo "ufw not active, skipping firewall config."
    echo "If using another firewall, open ports 22000/tcp and 21027/udp."
fi

# Drop the auto-created "default" folder + ~/Sync. We don't use them and they
# confuse fresh setups. Idempotent: a no-op once already removed. Uses rmdir
# (not rm -rf) so a non-empty ~/Sync — meaning the user actually put data
# there — is left alone.
echo "Removing auto-created default folder (if present)..."
for _ in $(seq 1 30); do
    syncthing cli show system >/dev/null 2>&1 && break
    sleep 1
done
if syncthing cli config folders list 2>/dev/null | grep -qx default; then
    syncthing cli config folders default delete
    echo "  removed 'default' folder share"
fi
if [[ -d "$HOME/Sync" ]]; then
    rmdir "$HOME/Sync/.stfolder" 2>/dev/null || true
    if rmdir "$HOME/Sync" 2>/dev/null; then
        echo "  removed empty ~/Sync"
    else
        echo "  ~/Sync has content; leaving it"
    fi
fi

echo ""
echo "Done! Syncthing web UI: http://127.0.0.1:8384"
echo "Run 'syncthing cli show system' to see your Device ID."
