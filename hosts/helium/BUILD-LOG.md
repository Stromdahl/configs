# helium build log

Chronological record of the physical build / bring-up. The forward-looking work
units live in `issues/` (epic:bootstrap …); this file is "what actually happened
and where we left off". Newest entry at the bottom.

---

## 2026-06-28 — first boot on the rescue OS: hardware verification + SMART burn-in

**State at end of session:** helium is powered on, booted into the Ventoy
`debian-rescue` OS (Debian 13, kernel 6.12). Drive burn-in (SMART long self-tests)
is **in progress** — see the "do not reboot" note below. No installer has run; no
disk has been written.

### Access
- **IP:** `192.168.1.174` — it reclaimed titan's old DHCP lease (same hardware).
- **MAC (active NIC):** `ac:1f:6b:e4:5c:d1` = `eno2`, the Intel **I210** port.
  `eno1` (I219-LM) is down / no-carrier — fine, I210 is the preferred port per
  `hosts/titan/HARDWARE.md` (avoids the e1000e/I219 hang seen on argon).
- **SSH:** `ssh ms@192.168.1.174`, key-only (the `stromdahl.keys` ed25519).
  Needs the key loaded in your agent: `ssh-add ~/.ssh/id_ed25519`.
- **sudo:** temporary rescue password `rescue` (change/irrelevant — rescue OS is
  throwaway). `smartmontools` was apt-installed into the live rescue session.

### Hardware verified against the PRD
| Component | PRD | Found | OK? |
|---|---|---|---|
| CPU | i5-9400 | i5-9400, 6C/6T, VT-x | ✅ |
| RAM | 16 GB | 15 GiB (=16 GB) | ✅ |
| HBA | LSI 9300-8i, SAS3 IT-mode | Broadcom/LSI **SAS3008** Fusion-MPT SAS-3 | ✅ |
| HDD tier | 4× 12 TB SAS HGST He12 `MB012000JWDFD` | sda–sdd, 10.9 TiB, exact model, blank | ✅ |
| Boot | 970 EVO Plus 250 GB NVMe | nvme0n1 Samsung 970 EVO Plus 250 GB | ✅ (see ⚠️) |
| Data tier | **2× 500 GB SATA SSD → btrfs raid1** | **NONE present** | ❌ |

### ❗ Blockers / things needing your hands
1. **The two 500 GB SATA SSDs are not connected yet** — confirmed by user, *not*
   a fault: they simply haven't been physically installed. The probe matched (SATA
   AHCI controller present, but no SATA drive enumerates — only the 4 SAS disks,
   the NVMe, and the Ventoy USB stick). `issues/001` (btrfs raid1 root) and the
   whole hot-data tier are blocked until they're cabled/powered in. **Pending
   build step: install + cable both SSDs before the OS install.**
2. **The NVMe still holds titan's old Proxmox install** — full LVM stack
   (`pve-root`, `pve-data` thin pool, `pve-swap`) intact on `nvme0n1p3`. Must be
   wiped during the Debian install. Untouched so far.

### SMART results (read 2026-06-28 ~05:56 UTC)
All four SAS drives: **Health OK, 0 grown-defect-list entries, 0 uncorrected
read/write errors, 30–32 °C.** Mixed age confirms the PRD's dual-parity rationale:

| Drive | Serial | Mfg | Power-on hours |
|---|---|---|---|
| sda | 5PJHD06E | wk33 2020 | 43,907 (~5.0 y) |
| sdb | D5HH850F | wk10 2022 | 25,841 (~2.9 y) |
| sdc | 8CKDRRSE | wk42 2019 | 44,698 (~5.1 y) |
| sdd | D5HH8K8F | wk10 2022 | 25,841 (~2.9 y) |

- **Watch item:** non-medium error counts are elevated on all four (2,559–3,327).
  These are interface/bus-level events (resets/aborts), **not** platter defects —
  benign given 0 grown defects + 0 uncorrected. If they climb fast under load,
  suspect a SAS cable / HBA seating.
- **NVMe:** PASSED, 0 % wear, 100 % spare, 0 media errors, 40 °C, 1,486 POH.
  Healthy as the single non-redundant boot drive.

### HBA cooling & temperature monitoring
- **Active cooling confirmed:** a small **Noctua fan** is mounted on the SAS3008
  heatsink. This satisfies the "HBA has active airflow" half of `issues/001`'s
  acceptance criteria. (Essential — these cards thermally throttle/shut down when
  passively cooled.)
- **HBA temp is NOT software-readable in IT-mode.** The chip has an internal
  thermal sensor + hardware shutdown threshold, but `mpt3sas` exposes no temp
  (only `ioc_reset_count` on the scsi_host), there's no hwmon device for it, and
  storcli/sas3ircu don't apply/aren't installed. So there's no temperature number
  to alarm on.
- **Monitor proxies instead:** `ioc_reset_count` (cat
  `/sys/class/scsi_host/host0/ioc_reset_count`, should stay 0) and the drives'
  non-medium error counts. The Noctua + visual "is it spinning" check is the
  primary safeguard.
- Drive temps (which *are* readable) under self-test read load: SAS 32–34 °C
  (trip 60 °C), NVMe 40 °C (warn/crit 85 °C) — all cool.

### ⏳ Burn-in launched — DO NOT REBOOT until done *(resolved 2026-06-29, see below)*
- **Long self-tests launched on sda, sdb, sdc, sdd** at ~05:56 UTC.
  ETA ~23 h each → **~05:00 UTC Mon 2026-06-29** (drives quote conservatively).
- NVMe short self-test launched (a prior short test already shows
  *completed without error*).
- A reboot / shutdown / starting the installer **aborts an in-progress SAS long
  test.** The box must stay booted in the rescue OS until they finish.

---

## 2026-06-29 — burn-in complete (clean); SATA SSDs still not installed

**State at end of session:** the SAS long self-tests finished. The "do not
reboot" constraint above is **lifted** — the box can now be safely shut down /
rebooted / sent to the installer. Build is **still blocked** on the two SATA
SSDs not being physically present (unchanged from 2026-06-28).

### SMART long self-test — all four PASSED
Read via the resume-checklist command. All four: `Background long … Completed`,
`LBA_first_err = -`, sense `[- - -]` → entire surface read, **zero failed LBAs**.
Power-on hours advanced ~20 h vs. the burn-in-start readings, confirming the
tests ran to completion rather than aborting:

| Drive | POH at start (06-28) | POH at finish (06-29) |
|---|---|---|
| sda | 43,907 | 43,927 |
| sdb | 25,841 | 25,860 |
| sdc | 44,698 | 44,716 |
| sdd | 25,841 | 25,861 |

### Bus health — the 06-28 watch-item cleared
- `ioc_reset_count` on the HBA scsi_host is **still 0** after a full day of
  self-test read load. The elevated non-medium error counts (2,559–3,327) did
  **not** produce any HBA resets → confirmed benign interface noise, not a
  failing SAS cable / HBA seating. No action needed.
- NVMe: no self-test in progress; prior short test passed.

### Still blocked — unchanged
- **The two 500 GB SATA SSDs are still not connected.** `lsblk -d -e7,11` shows
  only the 4 SAS disks, the USB stick (`sde`), and the NVMe. `issues/001` and the
  whole data tier remain blocked until both SSDs are cabled/powered in.

### Resume checklist (next session)
1. ~~Check the SAS long tests finished clean~~ — **done, all PASSED (above).**
2. **Install + cable the two SATA SSDs**, then confirm they enumerate
   (`lsblk -d -e7,11` should show two ~500 GB `sata` drives).
3. Then proceed to `issues/001` — wipe the NVMe (still holds titan's old Proxmox
   LVM stack) + plain single-disk Debian install on the NVMe; Ansible then builds
   the btrfs raid1 **data** pool across the two SSDs (per the revised PRD, the
   root is no longer raid1).

---

## 2026-06-29 — second data-tier SSD released from neon (`/home/ms` preserved)

**State at end of session:** the second SATA SSD for the data tier is now
**sourced and logically released** — it is neon's OS drive, a **Kingston SUV400
447 GB** (`sda` on neon). neon's `/home/ms` (16 GB) was backed up to krypton, so
the disk can be wiped and moved into helium. The physical pull/install hasn't
happened yet; once it's in, helium has **both** data-tier SSDs and builds the
btrfs raid1 in one shot — no single-device/degraded window.

### Why this was needed
The data tier needs two SSDs; one was on hand, the other was still inside neon as
its boot disk. The original cutover plan ("neon keeps serving until retirement,
then frees its SSD") created a latent build-graph cycle: `issues/011` (data tier,
needs both SSDs) sits *upstream* of the whole `005 → 008 → 009` chain, yet the
second SSD only freed at `009` (retire neon). Resolved by the user's call to
**release neon now** rather than keep it serving — neon goes bootless until its
later rebuild (NVMe as OS+storage, via the rescue USB).

### neon disk layout (surveyed read-only, `ms@jellyfin.stromdahl.tech`)
| Disk | Model | Holds | Fate |
|---|---|---|---|
| `sda` | Kingston SUV400 **447 GB** SATA SSD | OS (`/`, 49 GB used incl. `/home/ms`) | **→ helium data tier** (wipe) |
| `nvme0n1` | Samsung 990 PRO **2 TB** | `/mnt/datastore`: media (1.7 TB) + Steam library | **stays in neon**, untouched |

### What was preserved / dropped
- **`/home/ms` (16 GB) → krypton** at `~/backups/neon-2026-06-29/home-ms/`.
  rsync `-aHAX`, exit 0, 250,430 files; dry-run reverify clean (only timestamp
  drift on live browser/Steam/Discord cache files). Captures projects (721 MB),
  Factorio saves, Steam Proton prefixes/saves (`.local` 11 GB), flatpak data.
  **Final delta** before pulling the disk:
  `rsync -aHAX ms@jellyfin.stromdahl.tech:/home/ms/ ~/backups/neon-2026-06-29/home-ms/`
- **Games:** Steam library lives on neon's NVMe (`/mnt/datastore/steam`) and stays;
  saves/prefixes are in the `/home/ms` backup. Both covered.
- **Media library (1.7 TB):** untouched on neon's NVMe; migrates to helium later
  (`issues/008`) once the HDD pool exists.
- ***arr Docker state (radarr/sonarr/etc. named volumes on neon's `sda`):**
  **intentionally NOT preserved** — user chose to rebuild the stack on helium.

### Resume checklist (next session)
1. Final delta rsync of neon's `/home/ms` (command above).
2. Power off neon → pull the Kingston SUV400 447 GB SSD.
3. Install + cable **both** SSDs in helium; confirm they enumerate
   (`lsblk -d -e7,11` → two ~447–500 GB `sata` drives).
4. Proceed to `issues/001` / `issues/011`: wipe NVMe, single-disk Debian install,
   Ansible builds the btrfs **raid1** data pool across both SSDs in one shot.

---

## 2026-06-29 (later) — both data-tier SSDs installed + SMART-accepted

**State at end of session:** both data-tier SSDs are now **physically installed,
cabled, enumerating, and SMART-accepted**. Still in the `debian-rescue` OS
(`ssh ms@192.168.1.174`); no installer has run, no disk written. The data tier is
unblocked — next is `issues/001` (wipe NVMe + single-disk Debian) then `issues/011`
(Ansible builds the raid1).

### The two SSDs — both turned out to be identical Kingston SUV400 480 GB
The "on-hand" SSD is the **same model** as the one pulled from neon, so this is a
**matched pair**, not the "500 GB + 447 GB Kingston" mix the earlier notes assumed.
Both are `KINGSTON SUV400S37480G`, 480 GB (447 GiB) — ideal for raid1.

| Dev | Serial (`ata-…` id) | Model | Capacity |
|---|---|---|---|
| `sde` | `50026B767400167E` | KINGSTON SUV400S37480G | 480 GB / 447 GiB |
| `sdf` | `50026B776705BF4D` | KINGSTON SUV400S37480G | 480 GB / 447 GiB |

### SMART results — both PASSED, healthy, burn-in clean
`smartctl 7.4` (present in the rescue image at `/usr/sbin/smartctl`).

| Metric | `sde` (…167E) | `sdf` (…BF4D) |
|---|---|---|
| Overall-health | **PASSED** | **PASSED** |
| Reallocated / Pending / Reported-uncorrect | 0 / 0 / 0 | 0 / 0 / 0 |
| UDMA CRC errors | 0 | 0 |
| Runtime bad blocks (raw / norm) | 17 / 96 | 18 / 99 |
| **SSD life left** | **95 %** (5 % used) | **96 %** (4 % used) |
| Power-on hours / cycles | 10 202 h / 1 501 | 17 443 h / 2 195 |
| Host writes | ~10.8 TiB | ~13.6 TiB |
| Temp now (min/max) | 30 °C (12/42) | 29 °C (14/43) |
| Error log | empty | empty |
| **Extended (long) self-test** | **Completed without error** | **Completed without error** |

The `87543` triple on sde (Raw_Read_Error_Rate / Hardware_ECC_Recovered /
Soft_ECC_Correction, all mirroring) is the known UV400 attribute quirk — normalized
value 100, not damage; sdf reads 0 for the same fields. Both accepted for the tier.

### ⚠️ Duplicate WWN — pin the raid1 by `ata-<serial>`, never `wwn-`
Both drives report the **same malformed LU WWN** (`0 550380 440010000`, NAA=0) — a
known Kingston UV400 firmware bug. Consequence: udev creates **no `wwn-*`
`/dev/disk/by-id` link at all**, and if it did it would collide. Only the
per-serial links are unique and safe:

```
/dev/disk/by-id/ata-KINGSTON_SUV400S37480G_50026B767400167E -> ../../sde
/dev/disk/by-id/ata-KINGSTON_SUV400S37480G_50026B776705BF4D -> ../../sdf
```

`issues/011` says "reference drives by stable identifiers" — that identifier must be
`ata-KINGSTON_SUV400S37480G_<serial>`. Applies to the Ansible mkfs/mount role,
fstab, and any smartd / disk-replacement runbook. (btrfs tracks its own UUIDs once
the array exists, so the array itself is unaffected — only the device references
around it.)

### Debian installer staged on the Ventoy stick
The **Debian 13.5.0 amd64 netinst** (`debian-13.5.0-amd64-netinst.iso`, sha256
`95838884…49d2a`, verified) is now on the rescue stick's exFAT data partition, so
`issues/001` needs no second USB — boot helium and pick it from the Ventoy menu.

Gotcha for adding files to the stick *while booted from it*: vtoyboot holds the raw
partition (`/dev/sdg1`, 8:97) `O_EXCL` via device-mapper, so a direct
`mount /dev/sdg1` fails ("Can't open blockdev"). Ventoy also exposes a 1:1 linear
passthrough at **`/dev/mapper/sdg1`** — mount *that* (`sudo mount -t exfat
/dev/mapper/sdg1 /mnt/...`) to read/write the data partition live. Adding files is
safe: writes land in free clusters, leaving the live root's `.img` extents intact.

### Resume checklist (next session)
1. `issues/001`: boot the staged netinst from the Ventoy menu, wipe the NVMe (still
   holds titan's old Proxmox LVM), plain single-disk Debian install on the NVMe.
2. `issues/011`: Ansible builds the btrfs **raid1** data pool across `sde`+`sdf`,
   addressed by their `ata-<serial>` ids, in one shot (no degraded window).

---

## 2026-06-29 (later still) — Debian installed on the NVMe (UEFI); `issues/001` done

**State at end of session:** **`issues/001` is complete.** helium runs a clean,
native-**UEFI** Debian 13.5 (trixie) off the NVMe and is reachable over key-auth
SSH. No installer media needed anymore. Next is `issues/002` (Ansible foundation).

### Access (changed)
- **IP is now `192.168.1.191`** — the installed OS pulled a *new* DHCP lease;
  `192.168.1.174` was the rescue OS's lease (now stale). **TODO:** pin a static
  lease/reservation for the Ansible inventory.
- **SSH:** `ssh ms@192.168.1.191`, key-auth working (the standard `stromdahl`
  ed25519, deployed via `ssh-copy-id` from krypton). `ms` is in `sudo`.
- The installed-system sudo password is the one set during install (NOT `rescue`).

### The UEFI install saga (and the fix)
First install came up **BIOS/legacy-only** — the NVMe was visible only after
enabling CSM. Diagnosed from the rescue OS: MBR (`dos`) table, `grub-pc` /
`/boot/grub/i386-pc`, **no ESP** — i.e. the Ventoy USB had been booted via the
firmware's *legacy* path, so d-i installed a BIOS GRUB. No in-place EFI fix was
possible (nothing to fall back to).

Fix: wiped `nvme0n1` clean from the rescue OS (`wipefs` + `sgdisk --zap-all` + zero
first 10 MiB), then **set firmware to UEFI-only (CSM/Legacy disabled)** and
reinstalled. d-i then ran in UEFI mode and laid down GPT + ESP + `grub-efi` (shim)
automatically.

**Lesson for any future bare-metal install here:** disable CSM / boot the install
media via its **UEFI** entry, or Debian silently installs `grub-pc` and the disk
only boots in legacy mode.

### Verification (all `issues/001` criteria pass)
| Check | Result |
|---|---|
| UEFI boot | `BootCurrent 000A → \EFI\DEBIAN\SHIMX64.EFI`; `/sys/firmware/efi` present |
| Disk layout | GPT: `nvme0n1p1` ESP (vfat→`/boot/efi`), `p2` ext4 `/`, `p3` swap |
| Bootloader | `grub-efi-amd64` 2.12; `/boot/grub/x86_64-efi`; no `grub-pc`/`i386-pc` |
| Disks enumerate | 4× SAS (sda–sdd) + 2× Kingston SSD (sde/sdf) + nvme0n1 |
| `pve-*` remnants | none — clean |
| Admin SSH | `ms` (sudo group), key-auth from krypton |

### Loose ends (non-blocking)
- **Stale UEFI NVRAM entries:** `efibootmgr` shows leftover `debian` entries
  (`000B`/`000C`) pointing at ESP GUIDs from the wiped installs. Harmless (live
  `000A` boots first); prune with `efibootmgr -B <id>` if tidiness is wanted.
- Static IP reservation still TODO (see Access above).

### Resume checklist (next session)
1. `issues/002`: scaffold the Ansible tree in the repo (inventory entry for helium
   @ `192.168.1.191`, host playbook, base-hardening + docker roles, sops/age wired
   in), then `ansible-playbook` from krypton → hardened, docker-ready host.
2. Then `issues/003` (HDD pool) and `issues/011` (SSD btrfs raid1, by `ata-<serial>`)
   unblock in parallel.

---

## 2026-06-29 (later) — Ansible foundation; `issues/002` done

**State at end of session:** **`issues/002` is complete.** A scoped `ansible/`
tree (pilot — helium only) brings the box from a bare Debian install to a
hardened, docker-ready host in one `ansible-playbook` run pushed from krypton.
All five acceptance criteria verified on the box. Next is `issues/003` (HDD
mergerfs/snapraid pool) and `issues/011` (SSD btrfs raid1), which now unblock.

### What was built (`ansible/` at repo root)
- `ansible.cfg` — inventory + `vars_plugins_enabled = host_group_vars,
  community.sops.sops`; galaxy deps land in gitignored `ansible/galaxy/`.
- `inventory/hosts.yml` — `helium` @ `192.168.1.191` (now a **pinned DHCP
  reservation** — done this session), user `ms`, group `nas`.
- `host_vars/helium/{vars.yml,secrets.sops.yml}` — plain vars + the sops-encrypted
  `ansible_become_password` (admin-key-only; helium has no per-host age key).
- `roles/base/` — fleet-consistent hardening, config content matched to the
  dotfiles `sshd`/`ufw`/`fail2ban`/`unattended-upgrades` modules; idempotent
  modules + handlers, `sshd -t` validation on the drop-in.
- `site.yml` — `base` + `geerlingguy.docker` (docker-ce + compose plugin from the
  official trixie repo) applied to `nas`.
- `.sops.yaml` gained an admin-key-only rule for `ansible/host_vars/**.sops.yml`.

### Secret handling (no age key on the box)
The become password is decrypted **on krypton** by the `community.sops` vars
plugin (admin key at `~/.config/sops/age/keys.txt`) and consumed in memory — it
never lands on helium. `ansible -b` reaching `root` proved decryption + consume.

### Verification (all `issues/002` criteria pass)
| Check | Result |
|---|---|
| Apply from krypton | 1st run `changed=16 failed=0`; 2nd run `changed=0` (idempotent) |
| sops secret | become→`root` works; no age key on box |
| sshd | `permitrootlogin/passwordauthentication/kbdinteractiveauthentication no` |
| ufw | active; deny (incoming); 22/80/443 allowed (v4+v6) |
| fail2ban | active; sshd jail loaded |
| unattended-upgrades | enabled |
| docker | `hello-world` works; `docker compose` plugin `5.2.0` (trixie repo) |
| keys | no GitHub/deploy private keys on the box |

### Notes
- `docker-compose-plugin` is `5.2.0-1~debian.13~trixie` — the current official
  `docker compose` plugin (v2-lineage subcommand, not legacy `docker-compose`).
- DHCP reservation for helium's NIC is now pinned, so `ansible_host` is stable.

### Resume checklist (next session)
1. `issues/003`: Ansible builds the HDD mergerfs + SnapRAID pool (2 parity +
   2 data) over the 4× SAS drives via the HBA.
2. `issues/011`: Ansible builds the SSD btrfs **raid1** data pool across
   `sde`+`sdf`, addressed by `ata-<serial>` ids, in one shot.

---

## 2026-06-30 — media stack deployed (Jellyfin + Traefik + NetBird); `issues/005` machine-side done

**State at end of session:** the keystone services slice is **deployed and
running** on helium. `docker-socket-proxy + traefik + jellyfin` are up
(Jellyfin healthy), reachable **privately only**, brought up by the
`compose_stack` Ansible role from krypton with all secrets from sops. The role
is **idempotent** (clean re-run `changed=0`). `issues/005` stays **in-progress**
— the remaining acceptance criteria all need the user's hands (DNS, off-box
clients, the Jellyfin UI). See the handoff list below.

### What unblocked it
Only the two on-box placeholder vars in `host_vars/helium/vars.yml`:
- `jellyfin_render_gid: 992` — helium's `render` group (owns `/dev/dri/renderD128`).
- `compose_lan_iface: eno2` — the active Intel I210 port / default route
  (`eno1`/I219 is down). This keys the DOCKER-USER LAN-drop rule.

All three stack secrets (NetBird setup key, Cloudflare DNS token, Traefik
dashboard basic-auth) were already in `host_vars/helium/secrets.sops.yml`.

### Deploy run
`cd ansible && ansible-playbook site.yml --tags compose,services`. First attempt
went **UNREACHABLE at Gathering Facts** — a transient LAN blip (ping showed ~33 %
loss / latency spike; box uptime unchanged, no reboot, nothing applied). Re-ran
with SSH keepalive + retries (`ANSIBLE_TIMEOUT=30`, `ANSIBLE_SSH_RETRIES=3`,
`ServerAliveInterval=15`) → clean `ok=25 changed=20 failed=0`.

### Verified (machine-side, from krypton)
| Check | Result |
|---|---|
| Containers | traefik, docker-socket-proxy, jellyfin all **Up**; jellyfin **healthy** |
| TLS cert | **real Let's Encrypt** (`issuer=Let's Encrypt CN=YR1`, `CN=jellyfin.home.stromdahl.tech`, exp 2026-09-28) via DNS-01/Cloudflare — **no self-signed fallback** |
| Jellyfin mounts | `/config`→`/data/ssd/appdata/jellyfin` (rw); `/media`→`/srv/media` **ro**; `/transcode`→`/data/ssd/transcode` (rw) — **AC#5 met** |
| iGPU plumbing | `renderD128` present in-container under gid 992, `RENDER_RW_OK` (actual QuickSync stream is the off-box UI check) |
| **AC#3 LAN-exposure** | from krypton (LAN host 192.168.1.170): `curl https://192.168.1.191/` and `:80` both **time out** (DROP, no RST); SSH still works → **AC#3 met** |
| NetBird | Management+Signal **Connected**; FQDN `helium.netbird.cloud`; **mesh IP `100.65.22.72`**; peers 0/4 connected |
| DOCKER-USER | `-i eno2 --ctstate NEW -j DROP` then RETURN for established / `-i wt0` / `-i lo` — LAN dropped, mesh+loopback+egress allowed (verified with `iptables -S`) |
| `.env` | `600 root:root` (sops-rendered, secrets not world-readable) — **AC#6 met** |
| Idempotence | clean re-run `ok=23 changed=0` (gated the `netfilter-persistent save` + dropped `force:true` on the netbird key fetch) |

### ❗ Remaining — needs the user's hands (`issues/005` stays in-progress)
1. **DNS: map `jellyfin`/`traefik.home.stromdahl.tech` → `100.65.22.72`.** NOT in
   the playbook — DNS-01 only creates the cert-validation TXT records. The name is
   NXDOMAIN today (neon used `jellyfin.stromdahl.tech` → a LAN IP). Options: a
   NetBird DNS record (keeps the mesh IP private; matches the issue's stated
   design) **or** a Cloudflare A record `*.home.stromdahl.tech → 100.65.22.72`
   (works everywhere; publishes the non-routable 100.64/10 mesh IP). **AC#1 gate.**
2. **Mesh-reachability (AC#1):** from a NetBird peer, `curl https://jellyfin.home.stromdahl.tech/`
   → 200/redirect. Needs (1) done + a peer online (currently 0/4 connected; approve
   the helium peer in the NetBird dashboard if pending).
3. **AC#2 (nothing public):** confirm the router has **no port-forward** for 80/443
   to helium. Nothing public by construction, but it's a user attestation.
4. **AC#4 (iGPU):** play a transcoded title and confirm **QuickSync** in Jellyfin's
   playback dashboard; set Dashboard ▸ Playback ▸ transcode temp path to `/transcode`.

The real media library is still empty (`/srv/media`) — populating it is `issues/008`.

### Exposure model decided: LAN + mesh, never public (DNS via OPNsense Unbound)
The keystone slice originally assumed strict mesh-only (DNS → mesh IP, DOCKER-USER
drops the LAN). On review the user chose **LAN + mesh, never public** so non-NetBird
home clients (TVs/HTPC) can reach Jellyfin:

- **DNS:** an **OPNsense Unbound host override** `*` `home.stromdahl.tech`
  → **`192.168.1.191`** (helium's LAN IP), TTL 600. Verified resolving from krypton
  via the OPNsense resolver (`192.168.1.1`). (Initial attempt pointed at the stale
  rescue-OS lease `.174` — corrected to `.191`.)
- **Firewall:** made the DOCKER-USER restriction a documented toggle
  `compose_restrict_to_mesh` (host_vars). Set **false** → the role keeps the four
  DOCKER-USER rules **absent** (and a re-run removes a drop left by a prior strict
  deploy). The public boundary is now solely OPNsense (no port-forward) + helium
  having no public IP. Flip the var to `true` to restore strict mesh-only.
- **Verified end-to-end from krypton (LAN host), no `-k`:** `https://jellyfin.home.stromdahl.tech/`
  → 302 → `/web/` **200**, `ssl_verify=0` (real LE cert); `http://` → 301→https;
  Traefik dashboard → 401 (basic-auth). DOCKER-USER chain now empty. Role idempotent
  (`changed=0`) in the new state.

### Remote access wired: Cloudflare split-horizon → mesh IP
For off-LAN devices, added a **public Cloudflare** record `*.home.stromdahl.tech`
A → **`100.65.22.72`** (helium's NetBird IP), DNS-only/unproxied, TTL 300, via the
existing DNS-01 token. Split-horizon now:
- **LAN clients** → OPNsense Unbound → `192.168.1.191` (local; OPNsense answers
  before forwarding, so the public record never reaches them).
- **Roaming clients** (NetBird up) → public DNS → `100.65.22.72` → over the mesh.
- The mesh IP is non-routable (`100.64/10`), so the public record exposes nothing.

Verified: public resolvers (1.1.1.1/8.8.8.8) return `100.65.22.72`; LAN still
returns `.191`; helium serves `https://jellyfin.home.stromdahl.tech/` on its mesh
IP with a valid LE cert (302, `ssl_verify=0`). The wt0 path was already allowed by
the firewall. Final remote check is the user's (a phone on cellular with NetBird up).

**Still open:** the iGPU/QuickSync UI check; the no-port-forward attestation; and
the real remote-peer test from a roaming NetBird device.

---

## 2026-06-30 (later) — storage fault drills: `issues/003` + `issues/011` CLOSED

**State at end of session:** both storage tiers are now **fully verified and their
issues closed**. The four manual ACs that had kept 003 + 011 `in-progress` /
`needs-human` were exercised as live fault drills — run now, while the pools are
empty, so zero real data was at risk and we validated the exact recovery runbooks
we'll lean on once `issues/008` pours in the real library. helium is left **healthy**:
both pools mounted, compose stack up, jellyfin healthy.

### Done in three risk-ramped phases (krypton-driven; reboots run by hand)
1. **Reboot reassembly (003-AC6 + 011 reboot survival).** One reboot; afterwards all
   four HDD ext4 mounts + the `/srv/media` mergerfs union returned, both snapraid
   timers `active`, status clean; all 5 btrfs subvols auto-mounted, `helium-ssd`
   still 2-device RAID1. The multi-device-btrfs boot race 011 warned about did **not**
   occur.
2. **snapraid parity recovery (003-AC5).** 50 MB random canary → `snapraid sync` →
   removed it (**no sync between loss and fix** — the classic footgun) →
   `snapraid fix -d disk1` = 200 errors / 200 recovered / **0 unrecoverable**; restored
   canary sha256 matched byte-for-byte. Cleaned up with `--force-empty sync`; array
   back to empty + `check` clean.
3. **btrfs degraded-mount drive-loss (011-AC4).** Hashed canary while healthy →
   stopped stack + unmounted → offlined one SSD (`echo 1 > /sys/block/sdX/device/delete`)
   → mounted **`-o degraded,ro`** from the lone device (`btrfs show` = *"Some devices
   missing"*, canary hash intact) → reboot re-added the device → `btrfs balance
   -dconvert=raid1 -mconvert=raid1` (5/5 chunks) → back to 2-device RAID1, device stats
   all-0. Read-only degraded mount was deliberate: a degraded *rw* mount writes
   non-raid1 `single` chunks.

### Notable: device-letter churn is a non-issue (validated, not assumed)
The Phase-3 reboot **reshuffled kernel enumeration** — the SSD that was `sde` came
back as `sdd`, bumping the SAS drives around. Both pools still mounted perfectly:
the SSD tier by fs-UUID (fstab) with the `ata-*` by-id links auto-repointing, the
HDD tier by `wwn-*` by-id with snapraid using `/mnt/*` paths. This is live proof the
stable-identifier design (011's UUID+`ata-*` rule, 003's `wwn-*` rule) survives
exactly the failure mode it was built for.

### Storage epic status now
- `issues/001` (OS), `002` (Ansible), **`003` (HDD pool)**, **`011` (SSD tier)** — all `done`.
- Still open in epic:storage — `004` (HDD spin-down), `012` (SSD scrub verify),
  `013` (timer failure alerting).

### Resume checklist (next session)
The storage foundation is trustworthy. Highest-value next build step is
**`issues/008` — migrate the real media library + *arr state from neon** so Jellyfin
serves actual content. New services (`006` Immich, `007` Paperless, `014` download
automation) are also unblocked off the keystone `005` slice.

---

## 2026-06-30 (later still) — media stack: library migration kicked off (008) + *arr stack deployed (014, VPN-gated)

**State at end of session:** `issues/008` + `issues/014` both **in-progress**.
The ~932 GB library bulk-rsync is **running detached** on helium; the 014 download
stack is **deployed** with the bridge *arr verified end-to-end, blocked only on the
gluetun Mullvad WireGuard credential (needs-human). Both run/overlap as planned.

### Corrected reality vs the task briefs
- neon's OS drive is now in helium, so **neon is bootless and runs the Ventoy
  rescue OS at `192.168.1.153`** (`ms`, sudo pw `rescue`; it reclaimed neon's old
  lease → its host key changed, expected). The 008 brief's `ssh helium→neon`
  against neon's normal OS no longer applies.
- helium holds **no private SSH key** and `/srv/media` is **root-owned**, so the
  copy is run write-side-root on helium, read-side `ms@neon-rescue`.

### issue 008 — library bulk rsync (RUNNING in background)
- **Source:** neon's Samsung 990 PRO 2 TB (`nvme0n1`, ext4) **mounted read-only**
  at `/mnt/neon-src` on neon-rescue. Library = `media/media/{movies,series}`,
  **exactly 932 GB** (movies 605 G / 17 files, series 327 G / 242 files), owned
  `1001:1003`. Verified **0 files unreadable by `other`** → reading as `ms` skips
  nothing (so root-on-read via `PermitRootLogin no` on rescue wasn't needed).
- **Mechanism:** ephemeral ed25519 key `/root/.ssh/neon_migrate` on helium,
  its pubkey appended to `ms@neon-rescue:~/.ssh/authorized_keys`. Migration script
  at **`/root/neon-migrate.sh`**, launched as transient unit **`neon-migrate.service`**
  (`systemd-run`), logging to **`/var/log/neon-migrate.log`**. Two sequential rsyncs,
  `-aHAX --numeric-ids --partial`, **no `--delete`**: `movies/ → /srv/media/movies/`
  and **`series/ → /srv/media/tv/`** (neon's `series` → Jellyfin's `tv`).
- **Prep done:** `chown 1001:1003 /srv/media/{movies,tv}` (so 014's *arr can write
  imports); **both snapraid timers STOPPED** (`snapraid-sync`/`-scrub`) so they don't
  fire mid-copy — **must re-enable + run one `snapraid sync` after the copy**.
  Installed `rsync` on helium (was missing).
- **Progress at handoff:** ~125 G+/932 G, ~83 MB/s, ETA ~2.5–3 h. Self-completing
  (detached); survives disconnect.
- **Still pending (gated):** bulk finish → Jellyfin scan → **cold final delta with
  `--delete`** (user signals a quiescent window) → re-enable snapraid + one sync →
  playback over mesh (user). Then close 008.

### issue 014 — download automation (DEPLOYED; VPN-gated)
- Extended `roles/compose_stack` (one role, both 005+014): added gluetun,
  qbittorrent, prowlarr, flaresolverr (all `network_mode: service:gluetun`),
  radarr, sonarr, bazarr, profilarr, jellyseerr (plain `media` bridge) to
  `docker-compose.yml.j2`; new vars in `host_vars/helium/vars.yml`; WireGuard
  secrets migrated from neon's `secrets.env` into `secrets.sops.yml` (sops, never
  stdout); per-app appdata dirs + downloads chown + a seeded `qBittorrent.conf` in
  `tasks/stack.yml`. Deployed `--tags compose,services` from krypton.
- **Verified (machine-side, from krypton/LAN):** radarr/sonarr/bazarr/profilarr →
  **HTTP 200**, jellyseerr → 307, **all valid per-host LE certs** at
  `*.home.stromdahl.tech`. **No LAN port leak** — every service port
  (7878/8989/6767/6868/5055/8080/9696) **refuses** direct connection; only Traefik
  80/443 listen (services publish zero host ports — deliberate, since
  `compose_restrict_to_mesh=false` has no DOCKER-USER drop).
- **❗ BLOCKED — gluetun WireGuard tunnel won't pass traffic.** Tunnel *sets up*
  and selects valid Malmö Mullvad endpoints, but every check (incl. raw-IP egress,
  bypassing DNS) times out → handshake never completes. **Ruled out:** gluetun impl
  (userspace `WIREGUARD_IMPLEMENTATION=userspace` fails identically), key/address
  format (44-char b64 key + valid CIDR, cleanly migrated), city parsing, local
  egress (LE/NetBird/pulls all work). → **The migrated Mullvad key is not being
  accepted** (likely a lapsed Mullvad subscription or the key was removed when neon
  was decommissioned; far less likely an OPNsense outbound-UDP-51820 rule specific
  to helium). **Needs the user** to confirm Mullvad is active / supply a fresh
  WireGuard key+address → drop into `secrets.sops.yml` → re-run the role.
- **VPN tier stopped** (`docker compose stop gluetun qbittorrent prowlarr
  flaresolverr`) to halt the 6 s reconnect loop; the next role run starts it.
- **Deviations from the 014 brief (intentional):** subdomain-per-service Traefik
  routing (brief showed neon's PathPrefix); **bazarr media mount RW not `:ro`**
  (bazarr writes sidecar subtitles); **zero host-published ports on gluetun**
  (brief's "publish on gluetun" = container port over the bridge, not a host
  publish — a host publish would leak on the LAN). TRaSH quality-profiles/custom-
  formats import is **post-deploy app config** (profilarr/in-app, first-boot API
  keys) — out of 014's ACs, not automated.

### Resume checklist (next session)
1. **008:** check `systemctl is-active neon-migrate` + `du -sh /srv/media/{movies,tv}`
   vs 605 G/327 G + `tail /var/log/neon-migrate.log` for `DONE rc_total=0`. Then
   Jellyfin scan, cold final-delta (`--delete`, user window), re-enable snapraid
   timers + one `snapraid sync`, playback sign-off → close 008.
2. **014:** get a working Mullvad WireGuard key+address → `sops` into
   `secrets.sops.yml` → re-run `--tags compose,services` → gluetun healthy →
   verify kill-switch + qbit/prowlarr reachable over Traefik → first-boot app
   config (qbit creds, prowlarr indexers, *arr root folders `/data/media/{movies,tv}`
   + download client `gluetun:8080`, profilarr TRaSH sync) → close 014.
3. **Cleanup when 008 closes:** unmount `/mnt/neon-src` on neon-rescue; remove the
   ephemeral key (`/root/.ssh/neon_migrate*` on helium + the line in neon-rescue's
   authorized_keys).

## 2026-07-01 — issue 014 unblocked: Proton WireGuard tunnel live (kill-switch verified)

**State at end of session:** the gluetun VPN tier is **up and healthy**. The dead
Mullvad credential is replaced with a **Proton WireGuard** key, and qBittorrent's
egress now runs through the Proton tunnel. issue 014 is **machine-side complete**;
only first-boot app config remains.

### Why this unblocked (and the cost/benefit call)
The prior "gluetun won't pass traffic" block was a **dead credential, not a config
fault**. Cost/benefit review with the user: keep the VPN (privacy insurance vs. the
Swedish copyright-troll settlement-letter mill; **~zero marginal cost** — a Proton
sub is already owned) but **drop the port-forwarding chase** — PF only buys seeding,
which 014 explicitly dropped, so a plain Proton WireGuard config (NAT-PMP OFF) is
all that's needed. The Mullvad->Proton migration was already the right direction.

### Wiring
- Proton WireGuard config generated (device "Helium", GNU/Linux, NAT-PMP OFF).
- `PrivateKey` + `Address` (`10.2.0.2/32`) -> `wireguard_private_key` /
  `wireguard_address` in `ansible/host_vars/helium/secrets.sops.yml` via
  `sops set --value-stdin` (key never hit a terminal/transcript). Commit `992916f`.
- `gluetun_vpn_provider: protonvpn` / `gluetun_server_countries: Sweden` were
  already set; the Proton key is **account-wide**, so gluetun roams within Sweden
  regardless of the server the downloaded config named (it was `CH-18-TOR` — a Tor
  server, irrelevant since gluetun selects by country).
- Deployed `--tags compose,services` from krypton: `ok=27 changed=3 failed=0`.

### Verified (read-only, from krypton)
| Check | Result |
|---|---|
| gluetun | **healthy** (healthcheck passes only once the tunnel carries traffic) |
| qbittorrent / prowlarr | **healthy**; flaresolverr health starting |
| Tunnel egress | qbit exits via a **Proton IP** (`31.13.191.67`), **distinct from helium's home WAN** — torrent traffic is masked |
| Kill-switch | **structural**: qbit uses `network_mode: service:gluetun`, so gluetun down = qbit has no network stack (Docker-guaranteed; not separately drilled) |

### Remaining (first-boot app config — out of 014's machine-side scope)
- qBittorrent WebUI creds; Prowlarr indexers (+ flaresolverr for CF-gated ones);
  *arr root folders `/data/media/{movies,tv}` + download client `gluetun:8080`;
  profilarr TRaSH sync. Then close 014.
- (008 library rsync tracked separately.)

## 2026-07-01 (later) — issue 014 app config wired via API; NetBird roaming access validated

**State at end of session:** the download-automation stack is **configured and
functional end-to-end** — qBittorrent, Radarr, Sonarr, Prowlarr, and Bazarr are
wired together via their REST APIs (idempotent, schema-driven). issue 014 is
**machine + plumbing complete**; only per-user config (accounts / quality profiles)
remains. Bonus: NetBird roaming-peer access validated live (issue 005 AC).

### NetBird roaming validation (issue 005 needs-human AC — DONE)
Mid-session krypton left the home LAN, so `192.168.1.191` went unreachable. Not a
helium outage — the exact roaming case NetBird exists for. After `netbird up` on
krypton (mesh IP `100.65.64.45`), helium was reachable at its mesh IP **`100.65.22.72`**
over the tunnel (SSH + container APIs); helium uptime (~15 h) confirmed it never went
down. The remaining app config was completed over the mesh. -> issue 005's roaming
NetBird-peer AC is verified.

### App configuration (all via REST API, on-box keys, idempotent)
Driver read each app's API key on the box (never to a terminal); the qBit password
streamed from sops via `sops exec-env` stdin. Field names were introspected from each
`/schema` endpoint first (caught `movieCategory`/`tvCategory`, not `category`).
- **qBittorrent:** permanent WebUI password set via API + stored in sops
  (`qbittorrent_webui_password`; seed conf is `force:false` so it survives redeploys).
- **Radarr:** root `/data/media/movies`; qBit download client (host `gluetun:8080`,
  category `radarr`) — POST 201 = live connectivity test passed.
- **Sonarr:** root `/data/media/tv`; qBit download client (category `sonarr`).
- **Prowlarr:** FlareSolverr proxy (`http://localhost:8191`, tagged); Radarr + Sonarr
  apps (`fullSync`, callback `http://gluetun:9696`, servers `http://radarr:7878` /
  `http://sonarr:8989`); 2 starter public indexers (The Pirate Bay, YTS).
- **Sync verified:** `ApplicationIndexerSync` -> Radarr got TPB+YTS, Sonarr got TPB
  (YTS is movies-only, correctly category-filtered out of Sonarr).
- **Bazarr:** linked to Radarr + Sonarr (`use_*` on, keys set) via settings API (204).

### Internal wiring reference (for future edits)
- qbit/prowlarr/flaresolverr share gluetun's netns: among themselves `localhost`;
  from the bridge *arr, reach them as `gluetun:<port>` (8080/9696/8191).
- bridge *arr resolve each other + `gluetun` by docker DNS name.
- No remote path mapping: qbit + *arr both mount downloads at `/downloads`.

### Remaining — per-user (accounts / preferences), not blocking the pipeline
- **Bazarr:** create a language profile (e.g. English + Swedish) + add a subtitle
  provider account (needs creds) — done together in the Bazarr UI.
- **Jellyseerr:** first-run wizard (links Jellyfin admin + Radarr/Sonarr) — UI/creds.
- **Profilarr/TRaSH:** import quality profiles + custom formats via profilarr's UI
  (deliberately NOT API-imported -- profilarr owns that state).
- **Indexers:** TPB/YTS are a smoke-test starter set; add private trackers (creds).

### (same session) Jellyseerr wired — full request loop closed; issue 014 ACs met
User completed the Jellyfin sign-in wizard (the one credential step, done in the UI so
the Jellyfin password stayed out of automation). Then over the mesh: read Jellyseerr's
API key on-box and added **Radarr** (HD-1080p -> `/data/media/movies`) + **Sonarr**
(HD-1080p -> `/data/media/tv`) via `/api/v1/settings/{radarr,sonarr}` (both HTTP 201;
Jellyseerr auto-detected Sonarr v4, no language profile). Request loop is now closed:
Jellyseerr -> *arr -> Prowlarr -> qBittorrent(VPN) -> import -> Jellyfin.

**issue 014 — all 4 ACs verified -> closing.** Remaining items are per-user prefs, not
ACs: Bazarr language profile + subtitle-provider account; profilarr/TRaSH quality
profiles (014 explicitly scoped TRaSH import out of its ACs); private-tracker indexers.

### (same session) Bazarr — Swedish-first subtitle language profile
Per user: Swedish primary, English fallback. Enabled `sv`+`en` and created profile 1
"Swedish/English" (items sv then en) directly in Bazarr's SQLite (`table_settings_languages`,
`table_languages_profiles` — no REST endpoint for profiles), then restarted Bazarr and set
it as the **default profile for series + movies** via the settings API. Bazarr re-saved the
profile on load (added its own `audio_only_include` field) = accepted/active. Not yet
subbing anything: (a) needs a subtitle-provider account, (b) Radarr/Sonarr libraries are
empty until the migrated media is imported — new items inherit the default profile.

### (same session) Library imported into Radarr + Sonarr (in-place, no re-download)
Imported the migrated `/data/media` library via API: **15 movies -> Radarr, 17 series ->
Sonarr**. Added under the **Any** quality profile (library has 2160p remuxes; HD-1080p
would flag them cutoff-unmet and a future "search cutoff-unmet" could try to replace 4K
with 1080p), each with its **exact on-disk path** (adopts existing files, no orphaning),
downloads disabled (`searchForMovie`/`searchForMissingEpisodes` false; Sonarr
`monitor=existing`). Folder->metadata matches all clean (year-matched; even
`The Martian ... [YTS.MX]` resolved). Verified after RefreshMovie/RefreshSeries:
**15/15 movies hasFile, 17/17 series = 249 episode files adopted, both queues empty
(zero accidental grabs).** Bazarr will sync these on its next run and apply the
Swedish-first default profile; Jellyseerr now dedupes requests against owned titles.
This completes the media-stack bring-up: acquire (014) + serve (Jellyfin/005) + the
migrated library (008) are all live and integrated.

## 2026-07-01 (later) — issue 018: Homepage single-pane dashboard, live end-to-end

Added **Homepage** (`ghcr.io/gethomepage/homepage:v1.13.2`) to the compose stack as
the stack's front door at **`homepage.home.stromdahl.tech`** — grouped links, live
health, and API-fed widgets. All four ACs verified; issue 018 **done**.

### What was added (all via the compose_stack role — config-as-code)
- **Service** in `docker-compose.yml.j2`: non-root (jellyfin uid/gid via PUID/PGID),
  on `media` + `socket_proxy` nets, Traefik router (LE cert, `security-headers@file`,
  port 3000), **no published ports**. HDD union bind-mounted `:ro` at `/mnt/media` for
  the disk widget. No container healthcheck (Homepage's `HOMEPAGE_ALLOWED_HOSTS` would
  reject a localhost-Host probe; the image ships its own healthcheck — reports healthy).
- **Config** `roles/compose_stack/files/homepage/{settings,services,widgets,docker,
  bookmarks}.yaml`, **copied verbatim** (never templated) so the `{{HOMEPAGE_VAR_*}}`
  placeholders survive Jinja and resolve at runtime from the container env.
- **Secrets**: `radarr_api_key` + `sonarr_api_key` added to `secrets.sops.yml` (read
  off the box via `docker exec <arr> cat /config/config.xml` piped into `sops set` —
  values never hit the terminal); qbit WebUI pass reused from 014. Rendered into the
  `.env` and injected as `HOMEPAGE_VAR_*`.

### Gotchas hit (both caught before reaching prod)
- **Jinja parses `#` comments.** A `{{HOMEPAGE_VAR_*}}` written in a *comment* in the
  compose **template** blew up Ansible's Jinja pass (`unexpected end of print
  statement`) even though `docker compose config` was happy (it skips Jinja). Fix: no
  `{{ }}` in the templated compose file's comments. The config *files* are `copy`, not
  `template`, so their `{{...}}` is fine. → run `--check` (it caught this), not just
  `docker compose config`.
- **BusyBox grep in the *arr containers** has no `-P`; extract the ApiKey with GNU grep
  on krypton (`docker exec … cat | grep -oP`), not inside the container.

### Verification (over the mesh, krypton roaming off-LAN)
- Reachable: `homepage.home.stromdahl.tech` → `100.65.22.72`; curl HTTP **200**, valid
  LE chain (`ssl_verify=0`). Container **healthy**, logs clean.
- **Widgets actually render** (probed Homepage's own client proxy, not just the upstream
  API): `/api/services/proxy` for Radarr → `have:15` + real titles; Sonarr → the 17-series
  list; `/api/widgets/resources?type=disk&target=…` → SSD tier `/app/config` (btrfs, 480G,
  10%) and HDD tier `/mnt/media` (mergerfs, 23.8T, 4%), plus cpu/memory. So the key
  substitution, widget config, and data path are all confirmed end-to-end — not asserted.
  (qBittorrent card not headlessly probeable — bespoke handler; confirm in the browser.)
- Docker status dots via the existing socket-proxy (CONTAINERS=1), reachable from the
  homepage container.

### Idempotency
- Homepage itself is **idempotent**: repeat `--tags compose` runs leave it untouched, and
  all config-file/template/.env tasks report `ok`.
- BUT every run reports `changed=1` on "Bring up the compose stack" because the three
  **gluetun-netns services (qbittorrent, prowlarr, flaresolverr)** are recreated on every
  `docker compose up` (`network_mode: service:gluetun` gets re-resolved each `up`). This
  is **pre-existing to the 014 stack, not introduced by 018** — but it breaks the
  README's "clean second run = no changes" invariant and briefly restarts qbit each
  deploy (kill-switch stays intact). Left as-is; a future fix would pin/quiet those three.

### Follow-ups (not AC blockers)
- **HDD spin-down (004):** the disk widget statvfs's `/mnt/media` on a 15-min poll
  (long by design). statvfs is normally superblock-cached, but confirm the two data
  drives stay in standby with Homepage running (`hdparm -C` needs sudo — not checked
  live). Bump `widgets.yaml` HDD `refresh` higher if it ever wakes them.
- Optional later: Jellyfin/Jellyseerr/Prowlarr/Bazarr widgets (each needs another
  on-box key into sops) — currently link + status only.

### (same session) SnapRAID sync raced a live import — pipeline proven, parity deferred to nightly timer
Manual `snapraid sync` after the library import ran 100% (874 GB in 3h55m, **0 io / 0 data
errors, HBA ioc_reset_count=0**) but exited non-zero with ~480k "file errors" +
"cannot modify data disk during a sync". Cause was **not** corruption: a Jellyseerr request
for the full *Agatha Christie's Poirot* series (13 seasons) was downloading through the stack
(VPN -> qBittorrent -> Sonarr) and Sonarr was importing episodes into the HDD pool *during*
the sync (27/70 eps landed, 43 more queued at 100%). Live writes to `/mnt/disk{1,2}` = files
changing mid-sync = expected file-error skips (re-caught next run), not data loss.
**Lesson:** never `snapraid sync` while the pool is being actively imported to; let the
scheduled timer handle it during a quiet window. The `snapraid-sync.timer` (re-enabled this
session) fires daily **03:00** (`Persistent=true`) — that quiet-window run completes clean
parity over the migrated library + new content automatically. Side note: this is the first
**end-to-end proof of the acquire pipeline via a real user request.**

### 2026-07-02 03:00 — nightly SnapRAID sync completed clean (parity resolved)
The quiet-window scheduled run resolved the prior race exactly as predicted: **`Everything OK`**,
405 GB delta in 2h43m (03:00->05:43; the stable bulk was already done by the 07-01 partial run).
Full HDD pool — migrated library + the Poirot series — is now dual-parity protected. Nightly
timer keeps it current. Parity-protection thread closed.
