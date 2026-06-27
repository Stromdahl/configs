#!/usr/bin/env bash
#
# 01-build-rescue-image.sh -- build a fixed-size Debian 13 (trixie) raw image
# with XFCE + rescue tooling + an SSH key, bootable on BOTH BIOS and UEFI.
# Step 1 of 2; produces $BUILD_DIR/debian-rescue.img (not yet vtoy-patched).
#
#   sudo bash 01-build-rescue-image.sh
#
# Env overrides: BUILD_DIR, IMG_SIZE_GB, SUITE, HOSTNAME, USERNAME, USER_PASS, SSH_PUBKEY
#
set -euo pipefail

# ===================== config =====================
BUILD_DIR="${BUILD_DIR:-/var/tmp/rescue-build}"
IMG="$BUILD_DIR/debian-rescue.img"
MNT="$BUILD_DIR/mnt"
IMG_SIZE_GB="${IMG_SIZE_GB:-30}"
SUITE="${SUITE:-trixie}"                  # Debian 13, matches the servers
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
HOSTNAME="${HOSTNAME:-debian-rescue}"
USERNAME="${USERNAME:-ms}"
USER_PASS="${USER_PASS:-rescue}"          # <-- TEMPORARY. Change on first boot: passwd
# SSH key: env override > github.com/stromdahl.keys (key policy) > literal fallback
SSH_PUBKEY="${SSH_PUBKEY:-}"
SSH_PUBKEY_FALLBACK="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvvJmR+ycLFNyTHf1XxJs1lN+ShMDOCkbQn3s0xIofB"

KERNEL_PKGS="linux-image-amd64"
GRUB_PKGS="grub-pc-bin grub-efi-amd64-bin grub-common grub2-common"
FW_PKGS="firmware-linux firmware-iwlwifi firmware-realtek firmware-atheros firmware-misc-nonfree"
NET_PKGS="network-manager network-manager-gnome avahi-daemon libnss-mdns"
DESKTOP_PKGS="xorg lightdm lightdm-gtk-greeter xfce4 xfce4-goodies xfce4-terminal \
  firefox-esr gvfs gvfs-backends file-roller"
TOOL_PKGS="sudo openssh-server curl wget vim nano tmux htop rsync less file tree git \
  ca-certificates bash-completion locales console-setup keyboard-configuration \
  gdisk parted gparted dosfstools e2fsprogs exfatprogs ntfs-3g f2fs-tools \
  lvm2 cryptsetup mdadm smartmontools nvme-cli hdparm \
  pciutils usbutils lsof strace \
  ethtool tcpdump nmap iputils-ping traceroute mtr-tiny bind9-dnsutils netcat-openbsd"

# ===================== preflight =====================
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$BUILD_DIR" "$MNT"
cd "$BUILD_DIR"          # contain any stray debootstrap wget-log here

# defensive: clear any leftovers from a previous interrupted run
umount -R "$MNT" 2>/dev/null || true
for l in $(losetup -j "$IMG" 2>/dev/null | cut -d: -f1); do losetup -d "$l" 2>/dev/null || true; done

echo "== installing host build deps =="
apt-get update
apt-get install -y debootstrap gdisk dosfstools e2fsprogs parted util-linux curl p7zip-full

# resolve SSH key now that curl is present
if [[ -z "$SSH_PUBKEY" ]]; then
  SSH_PUBKEY="$(curl -fsSL https://github.com/stromdahl.keys 2>/dev/null | grep -m1 . || true)"
fi
SSH_PUBKEY="${SSH_PUBKEY:-$SSH_PUBKEY_FALLBACK}"
echo "   ssh key: ${SSH_PUBKEY%% *} ...${SSH_PUBKEY##* }"

# fetch + extract vtoyboot (ships as an .iso with the real .tar.gz inside)
VTOY_TARBALL="$BUILD_DIR/vtoyboot.tar.gz"
if [[ ! -f "$VTOY_TARBALL" ]]; then
  echo "== fetching vtoyboot =="
  iso_url="$(curl -fsSL https://api.github.com/repos/ventoy/vtoyboot/releases/latest \
    | grep -oE 'https://[^"]+vtoyboot-[^"]+\.iso' | head -1 || true)"
  [[ -n "$iso_url" ]] || { echo "ERROR: could not resolve vtoyboot iso url" >&2; exit 1; }
  echo "   $iso_url"
  curl -fSL "$iso_url" -o "$BUILD_DIR/vtoyboot.iso" || { echo "ERROR: vtoyboot download failed" >&2; exit 1; }
  7z e -y -o"$BUILD_DIR" "$BUILD_DIR/vtoyboot.iso" 'vtoyboot-*.tar.gz' >/dev/null \
    || { echo "ERROR: could not extract tarball from vtoyboot.iso" >&2; exit 1; }
  mv -f "$BUILD_DIR"/vtoyboot-*.tar.gz "$VTOY_TARBALL"
fi

# ===================== create fixed-size image =====================
echo "== creating ${IMG_SIZE_GB}G fixed-size raw image =="
rm -f "$IMG"
fallocate -l "${IMG_SIZE_GB}G" "$IMG"

echo "== partitioning (GPT: BIOS-boot + ESP + root) =="
sgdisk --zap-all "$IMG"
sgdisk -n1:0:+1M   -t1:ef02 -c1:"BIOS boot" "$IMG"
sgdisk -n2:0:+512M -t2:ef00 -c2:"EFI"       "$IMG"
sgdisk -n3:0:0     -t3:8300 -c3:"root"      "$IMG"

LOOP="$(losetup -fP --show "$IMG")"
echo "loop device: $LOOP"
cleanup() {
  set +e
  # rslave first so a recursive unmount can't propagate to the host's /run, /dev, ...
  mount --make-rslave "$MNT" 2>/dev/null
  umount -R "$MNT" 2>/dev/null || umount -Rl "$MNT" 2>/dev/null
  losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

ESP="${LOOP}p2"; ROOT="${LOOP}p3"
echo "== making filesystems =="
mkfs.vfat -F32 -n EFI "$ESP"
mkfs.ext4 -q -L rescue-root "$ROOT"

mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "$ESP" "$MNT/boot/efi"

echo "== debootstrap $SUITE (this pulls the base system) =="
debootstrap --arch=amd64 --include=ca-certificates "$SUITE" "$MNT" "$MIRROR"

# bind host kernel interfaces into the chroot (rslave so cleanup can't escape)
mount --make-rslave / 2>/dev/null || true
for d in dev dev/pts proc sys run; do mount --rbind "/$d" "$MNT/$d"; done
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

ROOT_UUID="$(blkid -s UUID -o value "$ROOT")"
ESP_UUID="$(blkid -s UUID -o value "$ESP")"

echo "== staging vtoyboot inside the image =="
cp "$VTOY_TARBALL" "$MNT/root/vtoyboot.tar.gz"

# ===================== in-chroot configuration =====================
cat > "$MNT/root/configure.sh" <<CHROOT
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# don't let daemons try to start inside the chroot
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
HOSTS

cat > /etc/apt/sources.list <<SRC
deb $MIRROR $SUITE main contrib non-free-firmware non-free
deb $MIRROR ${SUITE}-updates main contrib non-free-firmware non-free
deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free-firmware non-free
SRC

cat > /etc/fstab <<FSTAB
UUID=$ROOT_UUID  /          ext4  errors=remount-ro  0 1
UUID=$ESP_UUID   /boot/efi  vfat  umask=0077         0 1
FSTAB

apt-get update
mkdir -p /boot/grub      # so kernel/grub postinst update-grub doesn't error
apt-get install -y locales
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

apt-get install -y $KERNEL_PKGS $GRUB_PKGS
apt-get install -y $FW_PKGS || echo "WARN: some firmware packages missing (non-fatal)"
apt-get install -y $NET_PKGS $TOOL_PKGS
apt-get install -y $DESKTOP_PKGS

# --- user account ---
useradd -m -s /bin/bash -G sudo,netdev,plugdev "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
install -d -m 700 -o "$USERNAME" -g "$USERNAME" /home/$USERNAME/.ssh
echo "$SSH_PUBKEY" > /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown "$USERNAME:$USERNAME" /home/$USERNAME/.ssh/authorized_keys
passwd -l root || true

# --- ssh: key-only, enabled at boot ---
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl enable ssh
systemctl enable NetworkManager
systemctl enable avahi-daemon
systemctl enable lightdm

# --- grub config: written fresh (the -bin packages don't ship /etc/default/grub) ---
mkdir -p /boot/grub
cat > /etc/default/grub <<GRUBDEF
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Debian"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200"
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
GRUBDEF

# --- install grub for BOTH firmware paths ---
grub-install --target=i386-pc --recheck "$LOOP"
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
             --bootloader-id=debian --removable --no-nvram --recheck
update-grub

apt-get clean
rm -f /usr/sbin/policy-rc.d
echo "CHROOT-CONFIG-DONE"
CHROOT

chmod +x "$MNT/root/configure.sh"
echo "== running in-chroot configuration (installs kernel, desktop, tools) =="
chroot "$MNT" /root/configure.sh

sync
echo
echo "=========================================================="
echo " BUILD COMPLETE: $IMG"
echo " Image size: $(du -h --apparent-size "$IMG" | cut -f1) fixed"
echo " Next: sudo bash 02-finalize-rescue-image.sh"
echo "=========================================================="
