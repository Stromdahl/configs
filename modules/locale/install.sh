#!/usr/bin/env bash
# System locale: en_DK.UTF-8 default (English UI, Nordic conventions — ISO dates,
# 24h time, metric). Generates sv_SE.UTF-8 + en_US.UTF-8 + en_GB.UTF-8 as well
# so anything that wants Swedish strings, US fallbacks, or UK formatting can.
# Overrides whatever d-i picked at install time.
set -euo pipefail

apt_ensure locales

readonly LOCALES_NEEDED=(
  "en_DK.UTF-8 UTF-8"
  "sv_SE.UTF-8 UTF-8"
  "en_US.UTF-8 UTF-8"
  "en_GB.UTF-8 UTF-8"
)
readonly LOCALE_GEN=/etc/locale.gen

# Build a desired version of /etc/locale.gen and compare. Uncomment any of our
# entries that are present-but-commented; append any that are missing entirely.
tmp="$(mktemp)"
cp -- "$LOCALE_GEN" "$tmp"

for entry in "${LOCALES_NEEDED[@]}"; do
  # Match "# en_DK.UTF-8 UTF-8" or "#en_DK.UTF-8 UTF-8" (dots match literally
  # enough for these specific strings; no other locale collides).
  if grep -qE "^#[[:space:]]*${entry}\$" "$tmp"; then
    sed -i -E "s|^#[[:space:]]*(${entry})\$|\\1|" "$tmp"
  fi
  if ! grep -qxF -- "$entry" "$tmp"; then
    printf '%s\n' "$entry" >> "$tmp"
  fi
done

locale_gen_changed=0
if cmp -s -- "$tmp" "$LOCALE_GEN"; then
  ok "locale.gen already has all needed locales uncommented"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would update $LOCALE_GEN to uncomment: ${LOCALES_NEEDED[*]}"
  else
    sudo install -m 644 -o root -g root -- "$tmp" "$LOCALE_GEN"
    ok "updated: $LOCALE_GEN"
    locale_gen_changed=1
  fi
fi
rm -f -- "$tmp"

# locale-gen is the slow step (a few seconds per locale). Only run if file changed.
if (( locale_gen_changed )); then
  sudo locale-gen
  ok "locale-gen completed"
fi

# Default locale file (LANG / LANGUAGE) — overrides whatever d-i wrote.
readonly DEFAULT_LOCALE_SRC="$DOTFILES_ROOT/configs/locale/locale"
readonly DEFAULT_LOCALE_DST=/etc/default/locale

if [[ -r "$DEFAULT_LOCALE_DST" ]] && cmp -s -- "$DEFAULT_LOCALE_SRC" "$DEFAULT_LOCALE_DST"; then
  ok "default locale already current: $DEFAULT_LOCALE_DST"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $DEFAULT_LOCALE_SRC -> $DEFAULT_LOCALE_DST"
else
  sudo install -m 644 -o root -g root -- "$DEFAULT_LOCALE_SRC" "$DEFAULT_LOCALE_DST" \
    || die "failed to install $DEFAULT_LOCALE_DST"
  ok "installed: $DEFAULT_LOCALE_DST"
fi
