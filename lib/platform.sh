# shellcheck shell=bash

require_debian() {
  [[ -r /etc/os-release ]] || die "cannot read /etc/os-release; this bootstrap targets Debian/Ubuntu only"
  # shellcheck source=/dev/null
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    debian:*|ubuntu:*|*:*debian*|*:*ubuntu*) return 0 ;;
  esac
  die "unsupported distro: ID=${ID:-?} ID_LIKE=${ID_LIKE:-?}. This bootstrap targets Debian/Ubuntu."
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v -- "$c" >/dev/null 2>&1 || die "missing required command: $c"
  done
}
