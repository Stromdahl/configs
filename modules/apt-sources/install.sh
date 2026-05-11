#!/usr/bin/env bash
# Replace d-i's apt sources with an opinionated canonical layout:
#   - main archive via the LTH Debian mirror (debian.lth.se)
#   - security via security.debian.org (LTH doesn't carry security)
#   - all four components: main contrib non-free non-free-firmware
#   - trixie-backports added (NVIDIA 550 et al)
# Backs up the d-i-written sources once on first overwrite.
set -euo pipefail

readonly DEB822_MAIN_SRC="$DOTFILES_ROOT/configs/apt-sources/debian.sources"
readonly DEB822_MAIN_DST=/etc/apt/sources.list.d/debian.sources
readonly DEB822_MAIN_ORIG="${DEB822_MAIN_DST}.dotfiles-orig"

readonly BACKPORTS_SRC="$DOTFILES_ROOT/configs/apt-sources/trixie-backports.sources"
readonly BACKPORTS_DST=/etc/apt/sources.list.d/trixie-backports.sources

readonly LEGACY_LIST=/etc/apt/sources.list

mutated=0

# install_apt_source <src> <dst> [<orig-backup-path>]
# cmp-then-install. If $orig-backup-path is given AND the dst exists AND no
# backup yet, copy the existing dst to that backup path before overwriting.
install_apt_source() {
  local src="$1" dst="$2" orig="${3:-}"
  if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
    ok "apt source already current: $dst"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    if [[ -n "$orig" ]] && [[ -f "$dst" ]] && [[ ! -e "$orig" ]]; then
      info "would back up: $dst -> $orig"
    fi
    info "would install: $src -> $dst"
    return 0
  fi
  if [[ -n "$orig" ]] && [[ -f "$dst" ]] && [[ ! -e "$orig" ]]; then
    sudo cp -a -- "$dst" "$orig"
    ok "backed up original: $dst -> $orig"
  fi
  sudo install -m 644 -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
  mutated=1
}

install_apt_source "$DEB822_MAIN_SRC" "$DEB822_MAIN_DST" "$DEB822_MAIN_ORIG"
install_apt_source "$BACKPORTS_SRC"   "$BACKPORTS_DST"

# Legacy /etc/apt/sources.list — d-i on Trixie writes deb822, so this file is
# usually empty / commented-out (just a cdrom line). If it has live `deb`/`deb-src`
# entries, we'd end up with duplicate sources. Don't touch, but warn the user.
if [[ -f "$LEGACY_LIST" ]] && grep -E '^[[:space:]]*deb(-src)?[[:space:]]' "$LEGACY_LIST" >/dev/null; then
  warn "$LEGACY_LIST has uncommented deb lines that may shadow $DEB822_MAIN_DST — review manually"
fi

# Force the next apt_ensure to re-run apt-get update against the new sources.
if (( mutated )) && [[ -f "$_APT_UPDATED_FLAG" ]]; then
  rm -f -- "$_APT_UPDATED_FLAG"
  info "invalidated apt-update cache flag"
fi
