# shellcheck shell=bash
# apt helpers. DRY_RUN=1 to preview. Uses a per-run flag so multiple modules
# don't repeatedly `apt-get update`.

_APT_UPDATED_FLAG="${TMPDIR:-/tmp}/.dotfiles-apt-updated.$$"

_apt_update_once() {
  [[ -f "$_APT_UPDATED_FLAG" ]] && return 0
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo apt-get update"
    touch -- "$_APT_UPDATED_FLAG"
    return 0
  fi
  sudo apt-get update
  touch -- "$_APT_UPDATED_FLAG"
}

# apt_installed <pkg> — 0 if installed, 1 otherwise
apt_installed() {
  local pkg="$1"
  dpkg-query -W -f='${Status}' -- "$pkg" 2>/dev/null | grep -q 'install ok installed'
}

# apt_ensure <pkg> [<pkg>...] — install only the missing ones, in one batch
apt_ensure() {
  local -a missing=()
  local p
  for p in "$@"; do
    apt_installed "$p" || missing+=("$p")
  done
  if ((${#missing[@]} == 0)); then
    ok "apt: all present (${*})"
    return 0
  fi
  _apt_update_once
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo apt-get install -y ${missing[*]}"
    return 0
  fi
  sudo apt-get install -y "${missing[@]}"
  ok "apt: installed ${missing[*]}"
}
