# shellcheck shell=bash
# Idempotent symlink helper. DRY_RUN=1 to preview.

# link <src> <dst>
# - src may be absolute, or relative to $DOTFILES_ROOT
# - creates parent dir of dst
# - if dst already -> src: no-op
# - if dst is a broken symlink or wrong-target symlink: replace
# - if dst is a real file/dir: back up to dst.backup-<UTC timestamp>, then link
link() {
  local src="$1" dst="$2"
  [[ -n "$src" && -n "$dst" ]] || { err "link: need <src> <dst>"; return 2; }

  if [[ "$src" != /* ]]; then
    src="$DOTFILES_ROOT/$src"
  fi

  [[ -e "$src" ]] || { err "link: source missing: $src"; return 1; }

  local parent
  parent="$(dirname -- "$dst")"

  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink -- "$dst")"
    if [[ "$current" == "$src" ]]; then
      ok "link ok: $dst -> $src"
      return 0
    fi
    if [[ "${DRY_RUN:-0}" == 1 ]]; then
      info "would relink: $dst ($current -> $src)"
      return 0
    fi
    mkdir -p -- "$parent"
    ln -sfn -- "$src" "$dst"
    ok "relinked: $dst -> $src (was -> $current)"
    return 0
  fi

  if [[ -e "$dst" ]]; then
    local ts backup
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    backup="${dst}.backup-${ts}"
    if [[ "${DRY_RUN:-0}" == 1 ]]; then
      info "would back up $dst -> $backup, then link -> $src"
      return 0
    fi
    mv -- "$dst" "$backup"
    warn "backed up existing: $dst -> $backup"
    mkdir -p -- "$parent"
    ln -s -- "$src" "$dst"
    ok "linked: $dst -> $src"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would link: $dst -> $src"
    return 0
  fi
  mkdir -p -- "$parent"
  ln -s -- "$src" "$dst"
  ok "linked: $dst -> $src"
}
