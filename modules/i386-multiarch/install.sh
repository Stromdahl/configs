#!/usr/bin/env bash
# Enable i386 multi-arch so Steam and 32-bit Proton can install :i386 libs.
set -euo pipefail

if dpkg --print-foreign-architectures | grep -qx i386; then
  ok "i386 multi-arch already enabled"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo dpkg --add-architecture i386 (and invalidate apt-update flag)"
  exit 0
fi

sudo dpkg --add-architecture i386
rm -f -- "$_APT_UPDATED_FLAG"
ok "i386 multi-arch enabled"
