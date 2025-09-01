#!/bin/bash
set -euo pipefail

# --- settings you can tweak ---
THRESHOLDS=("20" "15" "10" "7")   # stepped warnings (%)
CRITICAL=5                        # start countdown at/under this (%)
SUSPEND_DELAY=60                  # seconds between final warn and suspend
HYSTERESIS=3                      # clears warn state after charge/recovery
# --------------------------------

BIN="$HOME/.local/bin/battery-guardian.sh"
SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$(dirname "$BIN")" "$SYSTEMD_DIR"

# install main script
cat > "$BIN" <<'EOF'
#!/bin/bash
set -euo pipefail

THRESHOLDS=("20" "15" "10" "7")
CRITICAL=5
SUSPEND_DELAY=60
HYSTERESIS=3

STATEBASE="${XDG_RUNTIME_DIR:-/run/user/$UID}/.battery-guardian"
mkdir -p "$STATEBASE"

BATDIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1) || true
[[ -d "$BATDIR" ]] || exit 0

cap=$(<"$BATDIR/capacity")
status=$(<"$BATDIR/status")

# reset all state when not discharging
if [[ "$status" != "Discharging" ]]; then
  rm -rf "$STATEBASE"
  mkdir -p "$STATEBASE"
  exit 0
fi

# helper: mark threshold notified
mark_notified() { touch "$STATEBASE/notified_$1"; }
was_notified() { [[ -f "$STATEBASE/notified_$1" ]]; }

# final countdown state
WARN_FILE="$STATEBASE/final_warn_epoch"
SUSPENDED_FLAG="$STATEBASE/suspended"

# if battery recovered above critical + hysteresis, clear countdown state
if (( cap >= CRITICAL + HYSTERESIS )); then
  rm -f "$WARN_FILE" "$SUSPENDED_FLAG"
fi

# stepped warnings
for t in "${THRESHOLDS[@]}"; do
  if (( cap <= t )); then
    if ! was_notified "$t"; then
      urgency=normal
      [[ $t -le 10 ]] && urgency=critical
      notify-send -u "$urgency" "Battery low" "$cap% remaining (<= $t%)"
      mark_notified "$t"
    fi
  else
    # clear state for this threshold if we recovered above t + hysteresis
    if (( cap >= t + HYSTERESIS )); then
      rm -f "$STATEBASE/notified_$t"
    fi
  fi
done

# final countdown and suspend
if (( cap <= CRITICAL )); then
  now=$(date +%s)
  if [[ ! -f "$WARN_FILE" && ! -f "$SUSPENDED_FLAG" ]]; then
    echo "$now" > "$WARN_FILE"
    notify-send -u critical "Battery critically low" \
      "Suspending in ${SUSPEND_DELAY}s unless charging (now ${cap}%)"
    exit 0
  fi

  if [[ -f "$WARN_FILE" && ! -f "$SUSPENDED_FLAG" ]]; then
    warn_at=$(<"$WARN_FILE")
    if (( now - warn_at >= SUSPEND_DELAY )); then
      # re-check charging right before suspend
      status_now=$(<"$BATDIR/status")
      cap_now=$(<"$BATDIR/capacity")
      if [[ "$status_now" == "Discharging" && $cap_now -le $CRITICAL ]]; then
        notify-send -u critical "Suspending now" "${cap_now}% remaining"
        touch "$SUSPENDED_FLAG"
        systemctl suspend
      else
        rm -f "$WARN_FILE" "$SUSPENDED_FLAG"
      fi
    fi
  fi
fi
EOF

chmod +x "$BIN"

# systemd service
cat > "$SYSTEMD_DIR/battery-guardian.service" <<EOF
[Unit]
Description=Battery guardian (stepped warnings + suspend)
ConditionPathExistsGlob=/sys/class/power_supply/BAT*/capacity

[Service]
Type=oneshot
ExecStart=$BIN
EOF

# systemd timer (every 60s)
cat > "$SYSTEMD_DIR/battery-guardian.timer" <<'EOF'
[Unit]
Description=Run battery guardian every 60s

[Timer]
OnBootSec=1min
OnUnitActiveSec=60s
AccuracySec=15s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now battery-guardian.timer

echo "Installed. Stepped notifications at: ${THRESHOLDS[*]}%, final at <=${CRITICAL}% with ${SUSPEND_DELAY}s countdown."
echo "Edit $BIN to change settings, then: systemctl --user restart battery-guardian.timer"
