#!/bin/bash
set -e

USER_NAME="${USER}"
USER_ID=$(id -u)
SCRIPT_PATH="$HOME/.dotfiles/bin/workspace_set"
TRIGGER_SCRIPT="/usr/local/bin/trigger_workspace.sh"
UDEV_RULE="/etc/udev/rules.d/99-display-connect.rules"

echo "🔧 Skapar trigger-skript..."
sudo tee "$TRIGGER_SCRIPT" > /dev/null <<EOF
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$USER_ID
sudo -u $USER_NAME /usr/bin/systemd-run --user --on-active=1s --description="Run workspace_set on display connect" $SCRIPT_PATH
EOF

sudo chmod +x "$TRIGGER_SCRIPT"

echo "🔧 Skapar udev-regel..."
sudo tee "$UDEV_RULE" > /dev/null <<EOF
SUBSYSTEM=="drm", ACTION=="change", RUN+="$TRIGGER_SCRIPT"
EOF

echo "🔄 Laddar om udev-regler..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "✅ Aktiverar linger för användaren (så systemd --user funkar)..."
sudo loginctl enable-linger "$USER_NAME"

echo "✅ Klart. Skriptet '$SCRIPT_PATH' körs när en display kopplas in."
