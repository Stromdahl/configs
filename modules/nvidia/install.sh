#!/usr/bin/env bash
# NVIDIA proprietary driver (Turing) + KMS for Wayland + 32-bit GL/Vulkan for Steam.
# Trixie main ships 550.163.01-2 (non-free) — supports Turing fully; no need for
# trixie-backports. (Using backports drags newer libxkbcommon0/libelf1t64/Mesa,
# which then break later apt installs that need the strict-version main
# companions like libxkbcommon-x11-0.) Requires apt-sources + i386-multiarch to
# have run first. Reboot needed afterwards to unload nouveau.
set -euo pipefail

apt_ensure nvidia-detect linux-headers-amd64
apt_ensure nvidia-driver nvidia-kernel-dkms nvidia-settings

# VA-API backend so Kodi/Firefox/mpv hardware-decode through NVDEC instead of CPU.
apt_ensure nvidia-vaapi-driver

# 32-bit GL + Vulkan stack for Steam / Proton.
# - libgl1-nvidia-glvnd-glx:i386 is the NVIDIA i386 OpenGL library (pulls
#   libnvidia-glcore:i386 etc. transitively).
# - libvulkan1:i386 is the Khronos Vulkan loader for 32-bit apps; the NVIDIA
#   Vulkan ICD is wired up by nvidia-driver on the amd64 side.
# - mesa-* 32-bit are kept for the rare software-fallback / non-NVIDIA-path cases.
apt_ensure libgl1-mesa-dri:i386 libglx-mesa0:i386 mesa-vulkan-drivers:i386 \
           libgl1-nvidia-glvnd-glx:i386 libvulkan1:i386

# Survive kernel-only upgrades that would otherwise autoremove the headers.
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo apt-mark manual linux-headers-amd64"
else
  sudo apt-mark manual linux-headers-amd64 >/dev/null
fi

# nvidia-drm modeset (Wayland + TTY recovery). install file, rebuild initramfs only on change.
readonly MODESET_SRC="$DOTFILES_ROOT/configs/nvidia/zz-nvidia-modeset.conf"
readonly MODESET_DST=/etc/modprobe.d/zz-nvidia-modeset.conf

if [[ -r "$MODESET_DST" ]] && cmp -s -- "$MODESET_SRC" "$MODESET_DST"; then
  ok "nvidia-drm modeset config already current"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $MODESET_SRC -> $MODESET_DST + update-initramfs -u"
  else
    sudo install -m 644 -o root -g root -- "$MODESET_SRC" "$MODESET_DST" \
      || die "failed to install $MODESET_DST"
    ok "installed: $MODESET_DST"
    sudo update-initramfs -u
    ok "initramfs updated"
  fi
fi
