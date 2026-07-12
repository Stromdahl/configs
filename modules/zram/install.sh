#!/usr/bin/env bash
# Compressed in-RAM swap via systemd-zram-generator. Cushion against OOM
# kills on the 16 GB box; no swap partition, no hibernation (see
# hosts/neon/PRD.md + issues/037). Config lives in configs/zram/.
set -euo pipefail

apt_ensure systemd-zram-generator

src="$DOTFILES_ROOT/configs/zram/zram-generator.conf"
dst="/etc/systemd/zram-generator.conf"

changed=1
if [[ -r "$dst" ]] && cmp -s -- "$src" "$dst"; then
  ok "etc ok: $dst"
  changed=0
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would install: $src -> $dst"
else
  sudo install -m 644 -o root -g root -- "$src" "$dst" || die "failed to install $dst"
  ok "installed: $dst"
fi

# Activate zram0 now if the config changed or it isn't up yet. The generator
# also runs at boot, so this just avoids a reboot on first apply.
zram_active() { swapon --show=NAME --noheadings 2>/dev/null | grep -qx /dev/zram0; }

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  zram_active || info "would: systemctl daemon-reload && systemctl start systemd-zram-setup@zram0.service"
elif (( changed )) || ! zram_active; then
  sudo systemctl daemon-reload
  sudo systemctl restart systemd-zram-setup@zram0.service || die "failed to start zram0"
  ok "zram0 active: $(swapon --show=NAME,SIZE --noheadings 2>/dev/null | grep zram0 || echo '?')"
else
  ok "zram0 already active"
fi
