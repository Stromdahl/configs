#!/bin/bash

# Map SHA256 EDID hashes to display configurations

get_connected_connectors() {
    for connector in /sys/class/drm/card*-*; do
        if [[ -f "$connector/status" ]] && grep -q connected "$connector/status"; then
            echo "$connector"
        fi
    done
}

get_concatenated_edids() {
    local edid_concat=""
    while read -r connector; do
        local edid_file="$connector/edid"
        if [[ -f "$edid_file" ]]; then
            edid_concat+=$(xxd -p "$edid_file" | tr -d '\n')
        fi
    done < <(get_connected_connectors)
    echo "$edid_concat"
}

get_display_fingerprint() {
    local edids
    edids=$(get_concatenated_edids)
    if [[ -n "$edids" ]]; then
        echo -n "$edids" | sha256sum -z | awk '{print $1}'
    else
        echo ""
    fi
}

function workspace_work () {
  xrandr \
    --output eDP --off\
    --output HDMI-A-0 --mode 1920x1200 --pos 2560x0 --rotate left\
    --output DisplayPort-0 --off\
    --output DisplayPort-1 --primary --mode 2560x1440 --pos 0x240 --rotate normal
  sleep 0.2
  i3-msg [workspace=7] move workspace to output nonprimary
  i3-msg workspace 7
}

workspace_home() {
  xrandr\
    --output eDP --off\
    --output HDMI-A-0 --primary --mode 3440x1440 --pos 0x0 --rotate normal\
    --output DisplayPort-0 --off\
    --output DisplayPort-1 --off
}

workspace_laptop() {
  xrandr \
    --output eDP --primary --mode 1920x1080 --pos 0x0 --rotate normal\
    --output HDMI-A-0 --off\
    --output DisplayPort-0 --off\
    --output DisplayPort-1 --off
}

function notify-display-setup () {
  notify-send "Detected display setup: $1"
}

configure_setup() {
    local fingerprint="$1"
    bash /home/ms/.dotfiles/configs/miscelanius/xsessionrc
    case "$fingerprint" in
       # WORK
        "ffa9412cb40d2b9e86b643756061136577a862689ab51dbac29ff97002112cb7")
            notify-display-setup "WORK"
            workspace_work
            ;;

        # HOME
        "abcdef1234567890deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
            notify-display-setup "HOME"
            workspace_home
            ;;

        # LAPTOP
        "8ea010d1a71296db15a42a9deb0c7e01cd42489bf8fe32958b87de1006d69676")
            notify-display-setup "LAPTOP"
            workspace_laptop
            ;;

        *)
            notify-send "Unknown display setup: $fingerprint"
            workspace_laptop 
            exit 1
            ;;
    esac
}

# Entry point
if [[ "$1" == "list" ]]; then
    get_display_fingerprint
    exit 0
fi

fingerprint=$(get_display_fingerprint)
if [[ -z "$fingerprint" ]]; then
    echo "No connected displays with valid EDID"
    exit 1
fi

configure_setup "$fingerprint"
