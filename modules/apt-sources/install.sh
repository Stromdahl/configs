#!/usr/bin/env bash
# Enable contrib + non-free + non-free-firmware on Trixie's default deb822 sources
# and add trixie-backports (needed for nvidia 550). Field-scoped Components edit;
# whole-file rewrite would clobber Signed-By and brick apt.
set -euo pipefail

readonly DEB822_MAIN=/etc/apt/sources.list.d/debian.sources
readonly LEGACY_LIST=/etc/apt/sources.list
readonly BACKPORTS_DST=/etc/apt/sources.list.d/trixie-backports.sources
readonly BACKPORTS_SRC="$DOTFILES_ROOT/configs/apt-sources/trixie-backports.sources"
readonly REQUIRED_COMPONENTS="main contrib non-free non-free-firmware"

mutated=0

# Returns 0 if the deb822 stanza already has all required components in Components:.
deb822_components_ok() {
  local file="$1"
  awk -v want="$REQUIRED_COMPONENTS" '
    BEGIN { ok = 1 }
    /^Components:/ {
      n = split(want, w, " ")
      for (i = 1; i <= n; i++) {
        if (index($0, w[i]) == 0) { ok = 0; exit }
      }
    }
    END { exit ok ? 0 : 1 }
  ' "$file"
}

rewrite_deb822_components() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v want="$REQUIRED_COMPONENTS" '
    /^Components:/ { print "Components: " want; next }
    { print }
  ' "$file" >"$tmp"
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    ok "deb822 components already correct: $file"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    rm -f -- "$tmp"
    info "would: rewrite Components: in $file to '$REQUIRED_COMPONENTS'"
    return 0
  fi
  sudo install -m 644 -o root -g root -- "$tmp" "$file" || { rm -f -- "$tmp"; die "failed to install $file"; }
  rm -f -- "$tmp"
  ok "updated: $file"
  mutated=1
}

ensure_legacy_components() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v want="$REQUIRED_COMPONENTS" '
    /^deb(-src)?[[:space:]]+.*[[:space:]](trixie|trixie-security|trixie-updates)([[:space:]]|$)/ {
      # Drop any current trailing components after the suite, replace with required set.
      n = split($0, f, " ")
      out = f[1] " " f[2] " " f[3]
      for (i = 4; i <= n; i++) {
        if (f[i] ~ /^(main|contrib|non-free|non-free-firmware)$/) continue
        out = out " " f[i]
      }
      print out " " want
      next
    }
    { print }
  ' "$file" >"$tmp"
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    ok "legacy list already correct: $file"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    rm -f -- "$tmp"
    info "would: rewrite trixie lines in $file to include '$REQUIRED_COMPONENTS'"
    return 0
  fi
  sudo install -m 644 -o root -g root -- "$tmp" "$file" || { rm -f -- "$tmp"; die "failed to install $file"; }
  rm -f -- "$tmp"
  ok "updated: $file"
  mutated=1
}

# Main sources (deb822 preferred on Trixie).
if [[ -f "$DEB822_MAIN" ]]; then
  if deb822_components_ok "$DEB822_MAIN"; then
    ok "deb822 components already correct: $DEB822_MAIN"
  else
    rewrite_deb822_components "$DEB822_MAIN"
  fi
elif [[ -s "$LEGACY_LIST" ]]; then
  ensure_legacy_components "$LEGACY_LIST"
else
  die "neither $DEB822_MAIN nor a non-empty $LEGACY_LIST exists — d-i must have produced one of these"
fi

# Backports.
if [[ -f "$BACKPORTS_DST" ]] && cmp -s -- "$BACKPORTS_SRC" "$BACKPORTS_DST"; then
  ok "backports source already in place: $BACKPORTS_DST"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $BACKPORTS_SRC -> $BACKPORTS_DST"
  else
    sudo install -m 644 -o root -g root -- "$BACKPORTS_SRC" "$BACKPORTS_DST" \
      || die "failed to install $BACKPORTS_DST"
    ok "installed: $BACKPORTS_DST"
    mutated=1
  fi
fi

# If we changed anything, force the next apt_ensure to re-run apt-get update.
if (( mutated )) && [[ -f "$_APT_UPDATED_FLAG" ]]; then
  rm -f -- "$_APT_UPDATED_FLAG"
  info "invalidated apt-update cache flag"
fi
