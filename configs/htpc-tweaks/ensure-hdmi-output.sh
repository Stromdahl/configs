#!/bin/bash
# Enable any connected HDMI/DP output when Plasma starts.
# Failure mode this handles: TV off at boot → kscreen saves "all outputs
# disabled" → TV on later but Plasma keeps the connector dark.
for o in HDMI-A-1 HDMI-A-2 DP-1 DVI-D-1; do
  [[ "$(cat "/sys/class/drm/card0-${o}/status" 2>/dev/null)" == "connected" ]] && {
    kscreen-doctor "output.${o}.enable" 2>/dev/null
    break
  }
done
