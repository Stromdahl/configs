#!/bin/bash

# touchpad setup
# exec xinput set-prop "SYNA2B31:00 06CB:7F8B Touchpad" "libinput Tapping Enabled" 1
# exec xinput set-prop "SYNA2B31:00 06CB:7F8B Touchpad" "libinput Natural Scrolling Enabled" 1


# xrandr --output DP-1 --primary --mode 1920x1200 --pos 0x0 --output eDP-1 --pos -1920x0  
echo 'hello world'
setxkbmap -layout gb,se
setxkbmap -option 'grp:alt_shift_toggle'
