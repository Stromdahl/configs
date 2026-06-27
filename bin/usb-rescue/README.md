# usb-rescue

Builds a **persistent Debian 13 (trixie) XFCE rescue OS** that boots from the
Ventoy USB stick via [vtoyboot](https://www.ventoy.net/en/plugin_vtoyboot.html).
Drop it next to the ISOs already on the stick, boot a sick machine from it, and
SSH in (key-only) to troubleshoot. Unlike a live ISO it's a real read-write
install — packages, configs and logs persist.

## Usage

Two steps, both as root. They default to `BUILD_DIR=/var/tmp/rescue-build` and
the stick at `/media/ms/Ventoy`.

```sh
sudo bash 01-build-rescue-image.sh      # debootstrap + XFCE + tools + grub (~15-20 min)
sudo bash 02-finalize-rescue-image.sh   # KVM smoke-test + vtoyboot + copy to stick
```

`01` produces `debian-rescue.img`; `02` boots it in a throwaway KVM VM (the real
proof the bootloader works), runs `vtoyboot.sh` inside the booted OS, renames to
`debian-rescue.img.vtoy`, and copies it onto the stick. Then reboot the target,
pick it from the Ventoy menu, and `ssh ms@debian-rescue.local`.

Tunables via env, e.g. `sudo IMG_SIZE_GB=40 SUITE=trixie bash 01-build-rescue-image.sh`.
The SSH key is fetched from `github.com/stromdahl.keys` (override with `SSH_PUBKEY=...`).

## What's inside

XFCE desktop + `gdisk`/`parted`/`gparted`, `lvm2`/`cryptsetup`/`mdadm`,
`nvme-cli`/`smartmontools`, `nmap`/`tcpdump`, `ntfs-3g`/`exfatprogs`, NetworkManager
+ avahi (mDNS), wifi firmware, firefox-esr. Login `ms`, temp password `rescue`
(change on first boot); SSH is key-only.

## Gotchas baked into the scripts (don't re-discover)

- **vtoyboot ships as an `.iso`** with the real `vtoyboot-*.tar.gz` inside it; a
  naive `curl|grep` for a `.tar.gz` release asset matches nothing and, under
  `set -e -o pipefail`, silently kills the build. `01` downloads the iso and
  `7z`-extracts the tarball.
- The GRUB **`-bin`** packages don't ship `/etc/default/grub`; the script writes
  it fresh and `mkdir -p /boot/grub` so postinst `update-grub` doesn't error.
- **Secure Boot must be OFF** on target machines — the inner GRUB is unsigned
  (shim-signed deliberately dropped for reliability).
- `vtoyboot.sh` must run in the **booted** OS, not a chroot — hence the KVM boot.
- Re-run `vtoyboot.sh` (staged at `/root` in the image) after any in-OS kernel
  upgrade, then re-copy to the stick.
- The chroot binds (`--rbind /run` etc.) are made `rslave` before unmount so a
  recursive `umount` can't propagate to the host's real `/run`/`/dev`.
