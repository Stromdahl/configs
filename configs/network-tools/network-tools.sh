# shellcheck shell=bash
# Network-related shell helpers.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

# Open ss with fzf for quickly poking at listening ports.
alias ports='ss -ptunl | fzf'

# Show this machine's public IP.
alias publicip='curl -s http://ifconfig.me/all.json | jq -r .ip_addr'
