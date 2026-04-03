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

echo ""
echo "Done! Syncthing web UI: http://127.0.0.1:8384"
echo "Run 'syncthing cli show system' to see your Device ID."
