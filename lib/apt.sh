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

# apt_findable <pkg> — 0 if the package exists in any configured apt source
# (i.e. apt-cache has metadata for it), 1 otherwise. Used during DRY_RUN to
# catch typos like 'libnvidia-gl:i386' (real name: libgl1-nvidia-glvnd-glx:i386).
# Does not hit the network.
#
# Implementation note: uses `apt-cache madison`, which prints one line per
# available version/source and prints nothing for unknown packages. Both `show`
# and `policy` are unreliable for this — they return exit 0 in some flag
# combinations even when nothing was found.
apt_findable() {
  local pkg="$1"
  [[ -n "$(apt-cache madison -- "$pkg" 2>/dev/null)" ]]
}

# apt_ensure <pkg> [<pkg>...] — install only the missing ones, in one batch.
# In DRY_RUN, additionally validates that every missing package is findable in
# the current apt cache and warns about ones that aren't (likely typos, OR
# packages that need a not-yet-applied source change like enabling non-free).
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
    local -a notfound=()
    for p in "${missing[@]}"; do
      apt_findable "$p" || notfound+=("$p")
    done
    if ((${#notfound[@]})); then
      warn "apt: not findable in current sources (typo or pending source change): ${notfound[*]}"
    fi
    info "would: sudo apt-get install -y ${missing[*]}"
    return 0
  fi
  sudo apt-get install -y "${missing[@]}"
  ok "apt: installed ${missing[*]}"
}
