# shellcheck shell=bash
# Logging helpers. Source-only; not executable.

if [[ -t 2 ]]; then
  _LOG_RED=$'\e[31m'
  _LOG_YELLOW=$'\e[33m'
  _LOG_BLUE=$'\e[34m'
  _LOG_GREEN=$'\e[32m'
  _LOG_DIM=$'\e[2m'
  _LOG_BOLD=$'\e[1m'
  _LOG_RESET=$'\e[0m'
else
  _LOG_RED=''; _LOG_YELLOW=''; _LOG_BLUE=''; _LOG_GREEN=''; _LOG_DIM=''; _LOG_BOLD=''; _LOG_RESET=''
fi

info()  { printf '%s[%s]%s %s\n' "$_LOG_BLUE"   "${LOG_PREFIX:-info}" "$_LOG_RESET" "$*" >&2; }
ok()    { printf '%s[%s]%s %s\n' "$_LOG_GREEN"  "${LOG_PREFIX:-ok}"   "$_LOG_RESET" "$*" >&2; }
warn()  { printf '%s[%s]%s %s\n' "$_LOG_YELLOW" "${LOG_PREFIX:-warn}" "$_LOG_RESET" "$*" >&2; }
err()   { printf '%s[%s]%s %s\n' "$_LOG_RED"    "${LOG_PREFIX:-err}"  "$_LOG_RESET" "$*" >&2; }
die()   { err "$@"; exit 1; }
dim()   { printf '%s%s%s\n' "$_LOG_DIM" "$*" "$_LOG_RESET" >&2; }

section() {
  printf '\n%s==>%s %s%s%s\n' "$_LOG_BLUE" "$_LOG_RESET" "$_LOG_BOLD" "$*" "$_LOG_RESET" >&2
}
