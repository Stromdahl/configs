#!/usr/bin/env bash
# Workstation installer. Reads hosts/<hostname>/modules.conf and runs each
# listed module from modules/<name>/install.sh.
#
# Run directly when the repo is already cloned. bootstrap.sh does prep only
# (apt + clone + ssh keys) and then prints the install.sh command for the user
# to run — it does NOT auto-invoke install.sh.
set -euo pipefail

DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck source=lib/log.sh
. "$DOTFILES_ROOT/lib/log.sh"
# shellcheck source=lib/platform.sh
. "$DOTFILES_ROOT/lib/platform.sh"
# shellcheck source=lib/symlink.sh
. "$DOTFILES_ROOT/lib/symlink.sh"
# shellcheck source=lib/apt.sh
. "$DOTFILES_ROOT/lib/apt.sh"

usage() {
  cat <<EOF
Usage: $(basename -- "$0") [--host NAME] [--module LIST] [--dry-run] [-h]

  --host NAME        Use hosts/NAME/modules.conf (default: \$(hostname -s))
  --module LIST      Run only these modules (comma-separated), ignoring the host list
  --dry-run          Show what would change; run no apt/symlink mutations
  -h, --help         Show this help

New machine:
  wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
  # then, when bootstrap prints the next step:
  cd ~/.dotfiles && ./install.sh --dry-run
  cd ~/.dotfiles && ./install.sh
EOF
}

HOST=""
MODULE_OVERRIDE=""
export DRY_RUN="${DRY_RUN:-0}"

while (($#)); do
  case "$1" in
    --host)     HOST="${2:-}"; shift 2 ;;
    --host=*)   HOST="${1#*=}"; shift ;;
    --module)   MODULE_OVERRIDE="${2:-}"; shift 2 ;;
    --module=*) MODULE_OVERRIDE="${1#*=}"; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) err "unknown flag: $1"; usage >&2; exit 2 ;;
  esac
done

: "${HOST:=$(hostname -s)}"
[[ "$DRY_RUN" == 1 ]] && warn "dry-run: no changes will be made"

require_debian

print_module_list() {
  # Writes module names, one per line, to stdout. Non-zero exit = no list
  # available (bootstrap will die with a helpful message).
  if [[ -n "$MODULE_OVERRIDE" ]]; then
    printf '%s\n' "${MODULE_OVERRIDE//,/$'\n'}"
    return 0
  fi
  local conf="$DOTFILES_ROOT/hosts/$HOST/modules.conf"
  if [[ ! -f "$conf" ]]; then
    local default_conf="$DOTFILES_ROOT/hosts/default/modules.conf"
    [[ -f "$default_conf" ]] || return 1
    warn "no modules.conf for host '$HOST' — falling back to hosts/default/" >&2
    warn "after this run, create hosts/$HOST/modules.conf to customize this machine" >&2
    conf="$default_conf"
  fi
  sed -E 's/[[:space:]]*#.*$//' -- "$conf" | awk 'NF'
}

list_known_hosts() {
  local d
  for d in "$DOTFILES_ROOT"/hosts/*/; do
    [[ -d "$d" ]] || continue
    err "  - $(basename -- "$d")"
  done
}

run_module() {
  local name="$1"
  local script="$DOTFILES_ROOT/modules/$name/install.sh"
  [[ -f "$script" ]] || { err "module not found: $name ($script)"; return 1; }
  LOG_PREFIX="$name" section "module: $name"
  # NOTE: do NOT call this function from an `if`/`&&`/`||` context. Bash silently
  # disables `set -e` inside subshells launched in such contexts (including the
  # subshell below), even when the subshell's script re-enables it. Use the
  # set+e / capture-rc / set-e pattern in main() instead.
  # shellcheck source=/dev/null
  ( LOG_PREFIX="$name" . "$script" )
}

main() {
  info "host=$HOST root=$DOTFILES_ROOT"
  local -a modules=()
  local raw
  if ! raw="$(print_module_list)"; then
    err "no module list for host '$HOST': $DOTFILES_ROOT/hosts/$HOST/modules.conf"
    if compgen -G "$DOTFILES_ROOT/hosts/*/modules.conf" >/dev/null; then
      err "known hosts:"
      list_known_hosts
    fi
    exit 1
  fi
  mapfile -t modules <<<"$raw"
  # mapfile on an empty string still produces a single empty element; strip it
  if ((${#modules[@]} == 1)) && [[ -z "${modules[0]}" ]]; then
    modules=()
  fi
  ((${#modules[@]} > 0)) || die "no modules to run"

  info "modules: ${modules[*]}"

  local -a failed=() succeeded=()
  local m rc
  for m in "${modules[@]}"; do
    # Run run_module OUTSIDE a conditional so `set -e` inside the module's
    # subshell isn't silently suppressed (bash quirk: errexit is disabled in
    # subshells launched in `if`/`&&`/`||` context, even if the script inside
    # explicitly sets it). Disable parent errexit around the call so a failing
    # module doesn't take down install.sh itself.
    set +e
    run_module "$m"
    rc=$?
    set -e
    if (( rc == 0 )); then
      succeeded+=("$m")
    else
      failed+=("$m")
    fi
  done

  section "summary"
  ok "succeeded: ${succeeded[*]:-none}"
  if ((${#failed[@]})); then
    err "failed: ${failed[*]}"
    exit 1
  fi
}

trap 'rm -f -- "$_APT_UPDATED_FLAG"' EXIT
main "$@"
