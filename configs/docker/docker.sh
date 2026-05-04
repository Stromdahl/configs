# shellcheck shell=bash
# Docker shortcuts.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

# Kill and remove all docker containers
alias docker_kill='(docker stop $(docker ps -aq) 2>/dev/null && docker rm -f $(docker ps -aq) 2>/dev/null)'

docker_nuke() {
  docker_kill
  docker system prune -af
  docker volume prune -af
}

alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}" | (read -r; printf "%s\n" "$REPLY"; sort -k2,2r)'
alias wdpsa='watch "docker ps -a --format \"table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\" | (sed -u 1q; sort -t\"(\" -k2,2)"'
