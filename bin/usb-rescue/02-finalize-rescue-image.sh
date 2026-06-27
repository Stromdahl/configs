#!/usr/bin/env bash
#
# 02-finalize-rescue-image.sh -- step 2 of 2.
#   1. boots the built image in a real KVM VM (UEFI/OVMF)  -> smoke test
#   2. SSHes in and runs vtoyboot.sh inside the booted OS  -> the supported path
#   3. powers off, renames to *.img.vtoy, copies to the Ventoy stick
#
#   sudo bash 02-finalize-rescue-image.sh
#
# Env overrides: BUILD_DIR, VENTOY_MNT, SSH_KEY, USER_PASS
#
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/var/tmp/rescue-build}"
IMG="$BUILD_DIR/debian-rescue.img"
FINAL="$BUILD_DIR/debian-rescue.img.vtoy"
VENTOY_MNT="${VENTOY_MNT:-/media/ms/Ventoy}"
DEST="$VENTOY_MNT/debian-rescue.img.vtoy"
SSH_KEY="${SSH_KEY:-/home/ms/.ssh/id_ed25519}"
SSH_PORT="${SSH_PORT:-2222}"
USER_PASS="${USER_PASS:-rescue}"          # matches 01-build (non-interactive sudo in the VM)
SERIAL_LOG="$BUILD_DIR/boot-serial.log"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
[[ -f "$IMG" ]] || { echo "Image not found: $IMG (run step 1 first)" >&2; exit 1; }
[[ -f "$SSH_KEY" ]] || { echo "SSH private key not found: $SSH_KEY" >&2; exit 1; }
[[ -d "$VENTOY_MNT" ]] || { echo "Ventoy stick not mounted at $VENTOY_MNT" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
echo "== installing qemu + OVMF (for boot test) =="
apt-get install -y qemu-system-x86 ovmf

OVMF_CODE="$(ls /usr/share/OVMF/OVMF_CODE_4M.fd 2>/dev/null || ls /usr/share/OVMF/OVMF_CODE.fd)"
OVMF_VARS_SRC="${OVMF_CODE/OVMF_CODE/OVMF_VARS}"
OVMF_VARS="$BUILD_DIR/OVMF_VARS.fd"
cp -f "$OVMF_VARS_SRC" "$OVMF_VARS"
: > "$SERIAL_LOG"

SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR"

echo "== booting image in KVM (UEFI), headless =="
qemu-system-x86_64 \
  -machine q35,accel=kvm -cpu host -smp 4 -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS" \
  -drive file="$IMG",format=raw,if=virtio \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
  -device virtio-net-pci,netdev=n0 \
  -serial file:"$SERIAL_LOG" -display none \
  -daemonize -pidfile "$BUILD_DIR/qemu.pid"
QEMU_PID="$(cat "$BUILD_DIR/qemu.pid")"
trap 'kill "$QEMU_PID" 2>/dev/null || true' EXIT   # never leave an orphaned VM holding the image / port
echo "   qemu pid $QEMU_PID ; waiting for SSH on 127.0.0.1:$SSH_PORT ..."

up=0
for i in $(seq 1 72); do      # up to 6 min
  if ssh $SSH_OPTS ms@127.0.0.1 true 2>/dev/null; then up=1; break; fi
  sleep 5
done

if [[ $up -ne 1 ]]; then
  echo "!! SSH never came up -- image may not boot. Last serial output:"
  tail -n 40 "$SERIAL_LOG" || true
  exit 1
fi
echo "== SMOKE TEST PASSED: boots (UEFI) + networking + key-auth SSH all work =="

echo "== applying vtoyboot inside the booted OS =="
ssh $SSH_OPTS ms@127.0.0.1 "echo '$USER_PASS' | sudo -S bash -c '
  set -e
  cd /root
  tar xf vtoyboot.tar.gz
  cd vtoyboot-*
  sh vtoyboot.sh
'" 2>&1 | sed 's/^/   [vtoyboot] /'

echo "== powering off the VM =="
ssh $SSH_OPTS ms@127.0.0.1 "echo '$USER_PASS' | sudo -S poweroff" 2>/dev/null || true
for i in $(seq 1 60); do kill -0 "$QEMU_PID" 2>/dev/null || break; sleep 2; done
kill "$QEMU_PID" 2>/dev/null || true
sleep 2
sync   # ensure the VM's writes (vtoyboot'd initramfs) are flushed to the image file

echo "== renaming to .vtoy =="
mv -f "$IMG" "$FINAL"

# sanity: free space on the stick
NEED_KB="$(du -k "$FINAL" | cut -f1)"
FREE_KB="$(df -Pk "$VENTOY_MNT" | tail -1 | awk '{print $4}')"
echo "   image ~$((NEED_KB/1024/1024))G, free on stick ~$((FREE_KB/1024/1024))G"
[[ "$FREE_KB" -gt "$NEED_KB" ]] || { echo "!! not enough free space on stick" >&2; exit 1; }

echo "== copying to Ventoy stick (this writes ~30G, be patient) =="
cp --sparse=never "$FINAL" "$DEST"
sync

echo "== verifying copy =="
ls -lh "$DEST"
if command -v filefrag >/dev/null 2>&1; then
  EXTENTS="$(filefrag "$DEST" 2>/dev/null | grep -oE '[0-9]+ extent' | grep -oE '[0-9]+' || echo '?')"
  echo "   extents on stick: $EXTENTS  (a low number = well-contiguous, good for Ventoy)"
fi

echo
echo "=========================================================="
echo " DONE.  $DEST"
echo " Reboot the target, pick it from the Ventoy menu, then:"
echo "   ssh ms@debian-rescue.local   (or use the DHCP IP)"
echo " First console/desktop password: $USER_PASS  (change it!)"
echo " NOTE: Secure Boot must be OFF on the target (inner GRUB is unsigned)."
echo "=========================================================="
