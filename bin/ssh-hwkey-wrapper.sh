#!/bin/bash

# Usage: ./ssh-hwkey-wrapper.sh <ssh arguments>
# Example: ./ssh-hwkey-wrapper.sh user@myserver

# Function to check if a FIDO2/sk- key is loaded in the agent
function check_sk_key_loaded() {
    ssh-add -L 2>/dev/null | grep 'sk-' > /dev/null
}

# Function to wait for YubiKey/FIDO2 device
function wait_for_hwkey() {
    local prompt="Insert your hardware security key (YubiKey/FIDO2) and press ENTER to continue..."
    while true; do
        # Try to load the resident key
        ssh-add -K 2>&1 | tee /tmp/ssh-add-sk.log
        # Check if a sk- key is now present
        if check_sk_key_loaded; then
            break
        fi
        # If not, check for "No such device" or similar error
        grep -q -i -e "no such device" -e "not found" -e "No FIDO" /tmp/ssh-add-sk.log
        if [ $? -eq 0 ]; then
            echo "$prompt"
            read -r
        else
            # Some other error, show it and exit
            cat /tmp/ssh-add-sk.log
            exit 1
        fi
    done
    rm -f /tmp/ssh-add-sk.log
}

# Main logic: check if sk- key is loaded, if not, try to add, else prompt for key
if ! check_sk_key_loaded; then
    wait_for_hwkey
fi

# Now the sk- key is loaded, proceed to ssh
exec ssh "$@"