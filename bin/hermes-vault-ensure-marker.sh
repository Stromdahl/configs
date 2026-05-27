#!/usr/bin/env bash
# Recreate the Syncthing .stfolder marker in ~/hermes-vault and poke a rescan.
#
# The Hermes agent autonomously reorganizes its memory vault (cron-driven) and
# in doing so deletes ~/hermes-vault/.stfolder. Syncthing then safety-halts the
# folder ("folder marker missing") and does not self-heal until the marker is
# back AND a scan runs — otherwise up to an hour of stalled sync. This script,
# driven by hermes-vault-marker.path on every change to the vault dir, restores
# the marker and triggers an immediate rescan so the halt clears within seconds.
set -euo pipefail

readonly VAULT="$HOME/hermes-vault"
readonly FOLDER_ID="hermes-vault"

[[ -d "$VAULT" ]] || exit 0
mkdir -p "$VAULT/.stfolder"

cfg=""
for c in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
  [[ -f "$c" ]] && { cfg="$c"; break; }
done
[[ -n "$cfg" ]] || exit 0

# Read the GUI api key + listen port straight from Syncthing's own config, then
# always talk to the loopback side of whatever address it binds.
mapfile -t kv < <(python3 - "$cfg" <<'PY'
import sys, xml.etree.ElementTree as ET
gui = ET.parse(sys.argv[1]).getroot().find("gui")
print((gui.findtext("apikey") or "").strip())
addr = (gui.findtext("address") or "127.0.0.1:8384").strip()
print("127.0.0.1:" + (addr.rsplit(":", 1)[-1] if ":" in addr else "8384"))
PY
)
apikey="${kv[0]:-}"
address="${kv[1]:-127.0.0.1:8384}"
[[ -n "$apikey" ]] || exit 0

curl -fsS -m 5 -X POST -H "X-API-Key: $apikey" \
  "http://$address/rest/db/scan?folder=$FOLDER_ID" >/dev/null 2>&1 || true
