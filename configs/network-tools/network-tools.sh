# shellcheck shell=bash
# Network-related shell helpers.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

# Open ss with fzf for quickly poking at listening ports.
alias ports='ss -ptunl | fzf'

# Show this machine's public IP.
alias publicip='curl -s http://ifconfig.me/all.json | jq -r .ip_addr'

# Probe titan-hermes-agent on port 22, then launch the remote hermes CLI.
# IP kept in sync with the titan-hermes-agent Host block in ~/.ssh/config.
function hermes () {
    if ! timeout 1 bash -c '</dev/tcp/192.168.1.189/22' 2>/dev/null; then
        echo "hermes: titan-hermes-agent (192.168.1.189:22) unreachable" >&2
        return 1
    fi
    ssh -t titan-hermes-agent /home/ms/.local/bin/hermes
}
