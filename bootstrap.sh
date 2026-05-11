#!/usr/bin/env bash
# One-shot bootstrap for a fresh Debian/Ubuntu machine.
#
# Two run modes:
#
#   - As root (on a minimal install where sudo isn't set up yet):
#       wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
#     Installs sudo + git + curl, adds the target user to the sudo group, clones
#     the dotfiles into /home/<user>/.dotfiles owned by that user, then prints
#     the next step. You exit root, log in as the user, and run install.sh.
#
#   - As a regular user (sudo already available):
#       wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
#     Installs git + curl via sudo, clones into ~/.dotfiles, runs the ssh module,
#     then prints the next step.
#
# In root mode the target user is auto-detected (exactly one regular UID-1000+
# account in /etc/passwd). Override with DOTFILES_USER=<name>.
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/Stromdahl/configs.git}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

say() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || die "cannot read /etc/os-release; this installer targets Debian/Ubuntu"
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
  debian:*|ubuntu:*|*:*debian*|*:*ubuntu*) ;;
  *) die "unsupported distro: ID=${ID:-?}. This installer targets Debian/Ubuntu." ;;
esac

# Resolve target user (owner of the dotfiles checkout; runs install.sh after).
if [[ $EUID -eq 0 ]]; then
  TARGET_USER="${DOTFILES_USER:-}"
  if [[ -z "$TARGET_USER" ]]; then
    candidates=()
    while IFS=: read -r name _ uid _ _ home shell; do
      [[ "$uid" =~ ^[0-9]+$ ]] || continue
      (( uid >= 1000 && uid < 65534 )) || continue
      [[ -d "$home" ]] || continue
      case "$shell" in */bash|*/zsh|*/sh|*/fish) ;; *) continue;; esac
      candidates+=("$name")
    done < /etc/passwd
    case ${#candidates[@]} in
      1) TARGET_USER="${candidates[0]}"; say "auto-detected target user: $TARGET_USER (override with DOTFILES_USER)";;
      0) die "no regular user found in /etc/passwd. Create one first (adduser <name>) or set DOTFILES_USER=<name>." ;;
      *) die "multiple regular users found (${candidates[*]}). Pick one with DOTFILES_USER=<name>." ;;
    esac
  else
    id "$TARGET_USER" &>/dev/null || die "DOTFILES_USER=$TARGET_USER: user does not exist"
  fi
  AS_ROOT=1
else
  TARGET_USER="$(id -un)"
  AS_ROOT=0
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DOTFILES_DIR="${DOTFILES_DIR:-$TARGET_HOME/.dotfiles}"

# Install prerequisites. Root mode skips sudo (and installs sudo itself).
if (( AS_ROOT )); then
  need_pkg=(ca-certificates git curl sudo)
  missing=()
  for p in "${need_pkg[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || missing+=("$p")
  done
  if ((${#missing[@]})); then
    say "installing prerequisites (as root): ${missing[*]}"
    apt-get update
    apt-get install -y "${missing[@]}"
  fi
  if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx sudo; then
    say "adding $TARGET_USER to sudo group"
    usermod -aG sudo "$TARGET_USER"
  fi
else
  command -v sudo >/dev/null 2>&1 \
    || die "sudo not installed. Re-run this script as root (su -), or install sudo manually first."
  need_pkg=(ca-certificates git curl)
  missing=()
  for p in "${need_pkg[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || missing+=("$p")
  done
  if ((${#missing[@]})); then
    say "installing prerequisites: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  fi
fi

# Clone (or update) the repo as the target user.
run_as_target() {
  if (( AS_ROOT )); then
    sudo -u "$TARGET_USER" -H -- "$@"
  else
    "$@"
  fi
}

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "repo present: $DOTFILES_DIR (fetching latest as $TARGET_USER)"
  run_as_target git -C "$DOTFILES_DIR" fetch --prune origin
  run_as_target git -C "$DOTFILES_DIR" checkout "$DOTFILES_BRANCH"
  run_as_target git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_BRANCH"
elif [[ -e "$DOTFILES_DIR" ]]; then
  die "$DOTFILES_DIR exists and is not a git checkout; move it aside and re-run"
else
  say "cloning $DOTFILES_REPO -> $DOTFILES_DIR (as $TARGET_USER)"
  run_as_target git clone --branch "$DOTFILES_BRANCH" --single-branch -- "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Drop SSH keys early as the target user so a future SSH session works even if
# the user delays running install.sh. Idempotent.
say "running ssh module (authorized_keys + config) as $TARGET_USER"
run_as_target "$DOTFILES_DIR/install.sh" --module ssh

host_short="$(hostname -s)"
profile_note=""
[[ -f "$DOTFILES_DIR/hosts/$host_short/modules.conf" ]] \
  || profile_note=" (no profile for this host; install.sh will fall back to hosts/default/)"

if (( AS_ROOT )); then
  cat >&2 <<EOF

==> bootstrap done (root mode).
    repo:    $DOTFILES_DIR  (owned by $TARGET_USER)
    host:    $host_short$profile_note
    user:    $TARGET_USER (now in sudo group)

next step — leave root, log in fresh as $TARGET_USER so the new sudo group
membership takes effect, then run install.sh:

    exit                                  # leave the root shell
    # SSH back in as $TARGET_USER, then:
    cd $DOTFILES_DIR && ./install.sh --dry-run   # preview every change
    cd $DOTFILES_DIR && ./install.sh             # apply

EOF
else
  cat >&2 <<EOF

==> bootstrap done.
    repo:    $DOTFILES_DIR
    host:    $host_short$profile_note

next step — run install.sh manually:

    cd $DOTFILES_DIR && ./install.sh --dry-run   # preview every change
    cd $DOTFILES_DIR && ./install.sh             # apply

EOF
fi
