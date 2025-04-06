#!/usr/bin/env bash

# Read battery level and status
level=$(cat /sys/class/power_supply/BAT0/capacity)
status=$(cat /sys/class/power_supply/BAT0/status)

# Function to send notification
send_notification() {
    if [[ "$level" -le 20 && "$status" == "Discharging" ]]; then 
      notify-send -u critical "Battery Low" "Battery level is critically low: ${level}%\nPlease plug in the charger!"
    else 
      notify-send "Battery Status" "Battery level: ${level}%\nStatus: ${status}"
    fi
}

# Check if "critical" flag is set
if [[ "$1" == "--critical" ]]; then
    # Only notify if battery is low and discharging
    if [[ "$level" -le 30 && "$status" == "Discharging" ]]; then
        send_notification
    fi
else
    # Send notification for any battery level
   send_notification 
fi
