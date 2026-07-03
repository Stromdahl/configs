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

### 2026-07-02 — health check + two fixes (SSD scratch retention, flaresolverr healthcheck)
Full health pass: host clean (no failed units, load ~0.3), btrfs SSD raid1 0 device errors,
HDD mergerfs+snapraid parity clean (HBA ioc_reset_count=0), VPN egress masked. Two issues
found and fixed:
1. **SSD scratch 92% full (409 GB).** qBittorrent had *no* seeding limits, so every imported
   torrent kept seeding in `/data/ssd/downloads` forever. Set ratio=1.0 / seeding-time=1440min
   -> pause (`max_ratio_act=0`); the *arr already have `removeCompletedDownloads=on`, so paused
   torrents are now removed+deleted post-import (chain works). Explicitly deleted the 19
   already-imported completed torrents (`deleteFiles=true`, hash absent from every *arr queue)
   -> freed 413 GB; **SSD 92% -> 7%**. In-flight download (Poirot S13) left untouched.
   Note `max_ratio_act` only reliably supports 0=pause/1=remove (no cross-version delete-files),
   which is why the *arr handle file deletion, not qBit.
2. **flaresolverr perpetually "unhealthy" = false alarm.** Compose healthcheck called `wget`,
   absent from the image; service itself fine (`/health`->200). Switched healthcheck to a
   python3 urllib probe (python3 is in the image); redeployed --tags compose,services over the
   mesh (`ansible_host=100.65.22.72`) -> **healthy, 0 unhealthy containers**.

## 2026-07-02 (later) — issue 006: Immich IaC written (v3.0.0, CPU ML, mesh-only); deploy gated on DB_PASSWORD

Added the full Immich service group to the `compose_stack` role, mirroring the OFFICIAL
immich-app **v3.0.0** release compose. Machine-side IaC is done + validated; the deploy is a
needs-human gate (one secret + phone-app auth + the slow first bulk index). helium was
unreachable on its LAN IP (krypton roaming off-LAN) but reachable on the mesh (`100.65.22.72`).

### What was added (config-as-code, on branch `immich-006`)
- **4 services** in `docker-compose.yml.j2`: `immich-server`, `immich-machine-learning`,
  `immich-redis` (valkey), `immich-database` (postgres). New internal `immich` bridge +
  `immich_model_cache` named volume.
- **vars** (`host_vars/helium/vars.yml`): `immich_version: v3.0.0`, upload/DB locations on the
  SSD `immich` precious subvol, DB user/name. The secret `immich_db_password` → sops (NOT
  minted — needs-human).
- **.env** (`stack.env.j2`): `IMMICH_*` vars (namespaced to avoid collisions in the shared
  .env); the password has no default → the render/deploy fails closed until the secret exists.
- **dirs** (`stack.yml`): create `/data/ssd/immich/{library,postgres}` root-owned (not
  pre-chowned — see below).

### Decisions (deliberate deviations from the task brief)
- **v3.0.0, not v2.7.5.** Brief predated v3; v3.0.0 is current stable. Fresh install → v3's
  breaking changes (API, pgvecto→VectorChord) don't apply. Pinning matured v2.x instead is the
  user's call (needs a different postgres image).
- **No pre-chown.** v3 `immich-server` runs as ROOT (no PUID/PGID) → writes the library as
  root; the postgres image self-chowns its data dir on init. The brief's "chown to the
  container uid" assumed a non-root model; corrected to root-owned empty dirs.
- **No published ports.** Upstream publishes `2283:2283`; here Traefik-only (the LAN-leak rule
  from issue 014 under `compose_restrict_to_mesh=false`).
- **redis/database renamed** `immich-redis`/`immich-database` (frees the generic names for
  Paperless, issue 007); `DB_HOSTNAME`/`REDIS_HOSTNAME` on the server set to match.
- **`env_file: .env` dropped** off server + ML (upstream sets it): the shared `.env` holds
  every stack's secrets, and `env_file` would inject them all into the Immich containers.
  `immich-server` gets an explicit `environment:` block with only its own vars.
- **Dedicated `immich` network** for db/redis/ML; `immich-server` dual-homed on `media` for
  Traefik. (socket_proxy is the precedent for isolating a sensitive backend.)
- valkey + postgres **digest-pinned** exactly as upstream (the tested pair).

### Verified (no deploy run — needs the secret first)
- `docker compose config` on the rendered stack → schema valid; **20/20 Immich structural
  assertions pass**: v3.0.0 images, no published ports, correct network membership (server on
  media+immich; backends immich-only), Traefik router/host/port 2283/security-headers, DB &
  REDIS hostnames → renamed services, CPU ML (plain image, no `extends`), valkey/postgres
  digest pins, model-cache volume, no `env_file` secret leak.
- Edited YAML parses. `ansible-playbook --syntax-check` is blocked only by the gitignored
  `geerlingguy.docker` galaxy role being absent in a fresh worktree checkout (unrelated to
  this change; resolves after `ansible-galaxy install -r requirements.yml`).

### Remaining — needs-human (the deploy is one secret away)
1. **Mint `immich_db_password`** (`[A-Za-z0-9]` only) into `host_vars/helium/secrets.sops.yml`.
2. **Deploy:** `ansible-playbook site.yml --tags compose,services` (target the mesh IP
   `100.65.22.72` while krypton roams off-LAN).
3. **Phone app** over the mesh: add `https://immich.home.stromdahl.tech`, log in, enable
   auto-backup (AC #2).
4. **First CPU bulk index** (faces + CLIP) is slow; confirm it finishes + incrementals keep up
   (AC #3, over time).

Landed on branch `immich-006` (draft PR), not `main` — the worktree is enforced for this
background job. Merge to `main` however you prefer.

### (same session) Immich deployed over the mesh — all 4 containers healthy on v3.0.0
User approved minting the secret + deploying. Minted `immich_db_password` (40× `[A-Za-z0-9]`)
into `secrets.sops.yml` via `sops set` (value never hit stdout). Installed the pinned galaxy
deps into the worktree (gitignored tree), then `ansible-playbook site.yml --tags
compose,services -e ansible_host=100.65.22.72` (helium's mesh IP; LAN IP dead while krypton
roams). First run: `ok=30 changed=4` (Immich dirs, `.env`, compose, stack up).

**Verified (runtime, over the mesh):**
- 4 containers `Up (healthy)`: `immich_server` + `immich_machine_learning` (v3.0.0),
  `immich_postgres` (vectorchord), `immich_redis` (valkey:9).
- `https://immich.home.stromdahl.tech/api/server/ping` → `{"res":"pong"}` on a **real
  Let's Encrypt cert** (issuer `Let's Encrypt CN=YR2`, subject `CN=immich.home.stromdahl.tech`).
- Storage: `/data/ssd/immich` on the btrfs SSD raid1 subvol; `library` root-owned; **PGDATA
  self-chowned to `999:999 0700`** on init (confirming the no-pre-chown decision).
- ML on CPU: plain image, gunicorn up, **no CUDA/GPU refs**; server logs
  `Immich ... running [v3.0.0] [production]`.
- server→ML wiring: `immich_server` resolves `immich-machine-learning` (172.20.0.4 on the
  `immich` net) and its `/ping` returns `pong` — the ML job path works across the network
  (the substance of AC #3; "jobs complete on a real library" is still over-time).

**Bug found + fixed during the idempotence check.** The dir task set PGDATA to `root:root
0755` every run, overwriting postgres's `999:999 0700` → a latent break (postgres refuses to
start on a `0755`/root PGDATA at next restart). Fixed: the task now only *ensures the dir
exists* and leaves ownership to postgres (`state: directory`, no owner/mode). Restored the
live dir to `999:999 0700` and **restarted `immich_postgres` to prove it — came back healthy**
(`database system is ready to accept connections`). Re-run now `changed=1`, and my two Immich
dir tasks report `ok`.

**Pre-existing, NOT from this change (flagged):** the remaining `changed=1` is "Bring up the
compose stack" — `docker compose up` recreates `qbittorrent`/`prowlarr`/`flaresolverr` (all
`network_mode: service:gluetun`, issue 014) on every run. The Immich containers are stable.
Worth a separate idempotence pass on the gluetun-attached services.

**Still needs the user's hands (AC #2, #3):** create the admin user + add the instance in the
phone app over the mesh + enable auto-backup; then confirm the first CPU bulk index (faces +
CLIP) finishes and incrementals keep up (slow first run). Issue 006 stays `in-progress` until
those two land.

## 2026-07-02 (later) — issue 006 CLOSED: phone backup live; a NetBird DNS nameserver group was hijacking roaming resolution

Immich's last human ACs landed: admin user created, instance added in the phone app over the
mesh, auto-backup enabled, photos landing in `/data/ssd/immich/library`. The CPU bulk index
(faces + CLIP) is running as designed. **Issue 006 → `done`.**

### The phone-reachability blocker (root cause + fix)
Symptom: the laptop reached every `*.home.stromdahl.tech` service over NetBird, but the phone
reached **none** — Immich, Jellyfin, *arr all timed out. Not Immich-specific → a mesh/DNS-layer
problem, not a service problem.

- **Mesh path was fine.** From the phone on cellular, NetBird showed `helium 100.65.22.72
  connected`, and `https://100.65.22.72/` (the raw mesh IP) returned Traefik's **404 page not
  found** — so TLS + Traefik are reachable from the phone.
- **The failure was DNS.** The phone resolved `*.home.stromdahl.tech` to helium's **LAN IP
  `192.168.1.191`** (unreachable off-LAN), not the mesh IP.
- **Cause: a NetBird account nameserver group** matching `home.stromdahl.tech` and forwarding it
  to the home LAN resolver. The laptop dodged it — `netbird status → Nameservers: 0/1 Available`
  (couldn't reach that nameserver off-LAN) → fell through to public DNS. The public Cloudflare
  wildcard `*.home.stromdahl.tech → 100.65.22.72` (verified on 1.1.1.1 + 8.8.8.8) is the intended
  roaming path.
- **Fix: disabled the NetBird nameserver group** (app.netbird.io → DNS → Nameservers). Roaming
  devices now resolve via the public record → mesh IP for every service. Short-term phone
  workaround that also worked: Android Private DNS → `one.one.one.one` (forces public DoT,
  bypassing the group).

**Gotcha for future work:** the exposure design is split-horizon — **public Cloudflare wildcard →
mesh IP** for roaming, **OPNsense Unbound → LAN IP** for on-LAN. A NetBird nameserver group that
claims `home.stromdahl.tech` breaks the roaming half on any client that honours it (notably
mobile). Don't re-add one for that domain. It's a NetBird-account setting, not in this repo.

## 2026-07-02 (later) — issue 007: Paperless-ngx IaC written + secrets minted (deploy gated: helium down)

Added the **Paperless-ngx** stack to the `compose_stack` role, mirroring the Immich block's
discipline. **Not deployed** — helium is unreachable this session (`ssh: connect to
192.168.1.191 port 22: No route to host`; powered off or moved), so the two on-box ACs
(reachable/cert/not-public; ingest→OCR→search) are unverified. Deliverable = **reviewed IaC +
staged secrets + in-progress claim**, not a closed issue.

### What landed (committed on `main`)
- **5-service group** in `docker-compose.yml.j2`: `paperless` (webserver) + namespaced
  `paperless-redis` / `paperless-db` / `paperless-gotenberg` / `paperless-tika` on a dedicated
  internal `paperless` bridge; webserver dual-homed on `media` for Traefik. **No published
  ports.** Traefik router (webserver only) → `paperless.home.stromdahl.tech`, port 8000,
  `security-headers@file`. `env_file` dropped; explicit `environment:` block.
- **Vars** (`host_vars/helium/vars.yml`) + **`.env`** (`stack.env.j2`): data/media/consume/
  export/pgdata all on the SSD *precious* `paperless` subvol (already provisioned by
  storage_ssd); webserver runs as USERMAP_UID:GID = jellyfin uid/gid (1001:1003) and owns
  those dirs; pgdata left for postgres to self-chown (issue-006 pattern). `PAPERLESS_URL` set
  → drives ALLOWED_HOSTS + CSRF for the reverse proxy.
- **Dir tasks** (`stack.yml`): chown data/media/consume/export to 1001:1003; pgdata `state:
  directory` only.
- **Homepage**: a "Documents" group with Paperless (stats widget commented — needs an API token).
- **Secrets** (`secrets.sops.yml`): machine-minted `paperless_secret_key` (base64/64) +
  `paperless_db_password` (hex/24), encrypted, never echoed. `paperless_admin_user` /
  `paperless_admin_password` deliberately **absent** (optional; see below).

### Image pins (verified live against the registries, 2026-07-02, not stale search)
- paperless `2.20.15` (latest stable v2; **v3.0.0 is beta-only** → stay on v2)
- postgres **`17.10`** with the **classic `/var/lib/postgresql/data` mount** — deliberately
  NOT upstream main's pg18 + `/var/lib/postgresql` (version-specific `.../18/docker` PGDATA
  path is a footgun); keeps issue-006's PGDATA-ownership pattern applicable
- redis `8.8.0`, gotenberg `8.34` (with paperless's `--chromium-disable-javascript` +
  `--chromium-allow-list=file:///tmp/.*` flags), tika `3.3.1.0` (non-`-full`)
- OCR (CPU): `eng` bundled + `swe` auto-installed at container start via `PAPERLESS_OCR_LANGUAGES`

### Verified offline
- `ansible-playbook site.yml --syntax-check` clean.
- Rendered the compose template with a dummy `.env` and ran `docker compose config -q` locally
  → **valid**; all five paperless services present.
- sops file re-encrypted; both new keys extract cleanly; existing keys intact; diff shows only
  `ENC[AES256_GCM,…]` (no plaintext leak).

### Still needs the user's hands (deploy + AC verification, when helium is back)
1. Bring helium up (confirm its address — `192.168.1.191` gave *No route to host*; the earlier
   log has it at `.174`, so re-check the DHCP reservation / inventory before deploying).
2. `cd ansible && ansible-playbook site.yml --tags compose,services` (re-run for idempotence).
3. **Admin superuser:** either populate `paperless_admin_user` + `paperless_admin_password` in
   sops (auto-create on first boot), or `docker exec -it paperless document_create_superuser`.
   Left as a deploy-time choice so no admin password is forced into git/transcript.
4. **AC verify:** `curl -v https://paperless.home.stromdahl.tech/` from a mesh peer → real LE
   cert + login page, not public; drop a PDF into the consume folder (or upload in the UI) →
   confirm OCR completes and a word from its text is full-text searchable.
5. First boot is slow (DB migrations + `swe` tesseract install) — give it a minute before judging.

## 2026-07-02 (later still) — issue 007: Paperless DEPLOYED over the mesh; AC1 cert stuck on a transient ACME failure

Correction to the entry above: helium was **not down** — it was unreachable only at the stale
LAN IP `192.168.1.191` (inventory). It answers fine over the **NetBird mesh at
`100.65.22.72`** (issue-006's address; Traefik 404 = alive). Deployed with an ansible_host
override:
```
cd ansible && ansible-playbook site.yml --tags compose,services -e ansible_host=100.65.22.72
```
`PLAY RECAP: ok=33 changed=6 failed=0`. (Inventory still points at the LAN IP — a future
session should reconcile helium's DHCP reservation / LAN NIC before relying on `site.yml`
without the override.)

### AC status after deploy
- **AC3 (data on SSD): PASS.** `/data/ssd/paperless` is the btrfs `@paperless` precious subvol.
  `data/media/consume/export` = `1001:1003` 0750 (the webserver uid/gid); `pgdata` = `999:root`
  0700 (postgres self-chowned) — exactly as designed.
- **AC4 (Ansible role + sops): PASS.** Deployed by the compose_stack role; secret_key + DB
  password sourced from sops.
- **AC1 (mesh reachable / valid cert / not public): PARTIAL.** All 5 containers up; webserver
  **healthy**; `tesseract-ocr-swe` installed at startup; migrations applied; gunicorn listening
  on :8000. `https://paperless.home.stromdahl.tech/` over the mesh returns **302 →
  /accounts/login/** (app + routing work, not public). BUT the TLS cert is still **"TRAEFIK
  DEFAULT CERT"**, not Let's Encrypt.
  - **Why:** Traefik made ONE ACME order for paperless that failed transiently
    (`Post .../acme/new-order: EOF`) and has not retried since (0 retries in the following
    minutes). The resolver itself is fine — immich holds a real LE cert (issuer `YR2`), and
    existing certs are cached in the `traefik_certs` volume.
  - **Fix (user-gated):** `docker restart traefik` on helium forces one fresh ACME order for
    paperless only (cached certs are untouched → no re-issuance storm, no rate-limit risk).
    The agent's attempt to restart the shared proxy was correctly blocked as out-of-scope for
    the paperless deploy. A brief (~seconds) routing blip for all services; auto-recovers.
- **AC2 (ingest → OCR → searchable): PENDING (human).** Pipeline is ready (celery worker
  connected to redis; gotenberg + tika up; swe+eng OCR). Blocked on admin creation + a test doc.

### Remaining human steps
1. `docker restart traefik` (or wait for Traefik to retry) → confirm `paperless.home.stromdahl.tech`
   serves a real Let's Encrypt cert. Closes AC1.
2. Create the admin (chosen approach: interactive): `docker exec -it paperless document_create_superuser`.
3. Log in; drop a PDF into `/data/ssd/paperless/consume` (or upload in the UI); confirm it OCRs
   and a word from its text is full-text searchable. Closes AC2.

### AC1 update: cert obtained after the Traefik restart → AC1 PASS
`docker restart traefik` (user-authorized) forced a fresh DNS-01 order that succeeded within
~20s. `paperless.home.stromdahl.tech` now serves a real Let's Encrypt cert (subject
`CN=paperless.home.stromdahl.tech`, issuer `YR1`, valid 2026-07-02 → 2026-09-30); full-chain
`curl` (no `-k`) → 302 to the login page. DNS → `100.65.22.72` (mesh, non-routable off-mesh).
**AC1 PASS.** Confirms the transient `new-order: EOF` was the whole story. Now 3/4 ACs green
(AC1/AC3/AC4); only **AC2** (admin creation + ingest→OCR→search) remains — a human step.

### AC2 pipeline verified (throwaway doc, then cleaned up) → OCR + search confirmed
Dropped an **image-only** PDF (no text layer — `pdftotext` → 0 chars, so OCR is mandatory)
into `/data/ssd/paperless/consume`, owned `1001:1003`. Paperless consumed it: `ocrmypdf` ran,
"consumption finished", "New document id 1 created" (5.8s). Read the OCR output back from
Postgres — extracted content was exact: `Paperless OCR test OCRVERIFY7391ZEBRA Swedish:
raksmorgas aeoo safe to delete` (token incl. digits + Swedish line read correctly), and an
`ILIKE '%OCRVERIFY%'` query matched (count=1) → **ingest → OCR (eng+swe) → searchable text
confirmed**. Cleaned up via soft-delete + `empty_trash([1])`: DB back to 0 documents, all
archive/original/thumbnail files removed, consume dir empty. Instance left pristine.

**Net: all 4 ACs technically met (AC1/AC3/AC4 + AC2 pipeline).** The only outstanding
operational step is creating the admin account for interactive use:
`docker exec -it paperless document_create_superuser` (no admin exists yet — the instance has
zero users). Not an AC, but required before anyone can log in / search in the UI.

## 2026-07-02 (later) — issue 016: restic appdata backup — new role, deployed, all 5 ACs verified live

Added a new **`restic_backup`** Ansible role (mirroring `storage_ssd`'s btrfs-scrub
shape: static systemd unit files + a guarded idempotent init + a timer) that backs
up the SSD **`appdata`** precious subvolume to the HDD pool with restic. Deployed
from krypton over the mesh, verified end-to-end including a real test restore and
a deliberately-induced failure. **Issue 016 → `done`**, all 5 ACs green.

### Scope (deliberate, stated per the issue's own wording)
Source is **`/data/ssd/appdata` only** — the *arr databases/quality profiles,
Bazarr's language profile, Jellyseerr history, Jellyfin watch state. The issue's
"full-box backup" note lists Immich + Paperless + appdata as the eventual target,
but explicitly scopes *this* issue to "the appdata slice and the local repo" —
Immich and Paperless live on separate SSD precious subvols (`/data/ssd/{immich,
paperless}`) and are deferred to a later issue, which can reuse the same repo
with an independent `--tag`. The HDD media library stays excluded throughout
(different filesystem entirely — `/srv/media`, SnapRAID-protected, never a restic
source).

### What was built (`ansible/roles/restic_backup/`)
- **`packages.yml`** — `apt install restic` (trixie ships `0.18.0-1+b4`).
- **`secrets.yml`** — the repo passphrase (sops `restic_repository_password`,
  machine-minted via `openssl rand -base64 32`, set with `sops set --value-stdin`
  fed a JSON-encoded string — never hit stdout) written to `/etc/restic/appdata.pass`,
  root:root `0600`, `no_log: true` on the task.
- **`repo.yml`** — `restic init` guarded by a `stat` on `<repo>/config` (restic
  errors on a re-init; the stat makes the task genuinely idempotent, mirroring
  storage_ssd/storage_hdd's "detect existing state, never redo it" mkfs idiom).
  Repo path: **`/mnt/disk1/backups/restic-appdata`** — a dedicated dir written
  directly to one HDD pool member's raw ext4 mount, *not* addressed through the
  mergerfs `/srv/media` union, so it's pinned to a deterministic disk and never
  subject to mergerfs's create/least-free-space or `moveonenospc` policies
  (those only govern writes made *through* the union). It still lands on a
  SnapRAID data disk, so it inherits SnapRAID's parity protection as a side
  benefit — `snapraid.conf` indexes the whole `disk1`/`disk2` mounts, not just
  the media folders.
- **`timer.yml`** — installs 3 static unit files, enables+starts the timer only
  (service is oneshot, timer-triggered). `restic-backup.timer`: daily `02:00`,
  ahead of SnapRAID's nightly sync (`03:00`) and off the SnapRAID scrub
  (Sun `04:00`) / btrfs scrub (1st-of-month `05:00`) windows — no two
  maintenance jobs ever touch a pool at once. `restic-backup.service`: two
  `ExecStart` lines — `restic backup` (tag `appdata`, `--exclude-caches` plus
  explicit `cache`/`log`/`logs` dir excludes) then `restic forget --prune`
  (`--keep-daily 7 --keep-weekly 4 --keep-monthly 6`) — the retention bound is
  hardcoded directly in the unit, matching the SnapRAID-scrub unit's
  hardcoded-percentage convention.
- **Failure seam (AC5):** `OnFailure=restic-backup-alert.service` on the backup
  unit, pointing at a small placeholder alert unit (`logger -p daemon.alert` +
  `wall`). issues/013 (the real notification channel — ntfy vs. healthchecks vs.
  email is still an open decision there) only needs to swap that one unit's
  `ExecStart`; nothing about `restic-backup.service` changes. This meets 016's
  explicitly-lowered bar ("at minimum a non-silent failure") — it does **not**
  yet page/email anyone.
- **Wiring:** one line in `site.yml` (`tags: [backup, restic]`); new vars in
  `host_vars/helium/vars.yml` (`restic_backup_source`, `restic_repo_path`,
  `restic_password_file`); `restic_repository_password` in `secrets.sops.yml`.

### Deploy + verification (over the mesh, `-e ansible_host=100.65.22.72` —
krypton was off the home LAN this session, `.191` unreachable)
| Check | Result |
|---|---|
| 1st `--tags backup` run | `ok=10 changed=7 failed=0` |
| 2nd `--tags backup` run (idempotency) | `ok=8 changed=0 failed=0` (AC4) |
| Repo init | `/mnt/disk1/backups/restic-appdata/config` created, mode `0400` root:root |
| Passphrase file | `/etc/restic/appdata.pass`, mode `0600` root:root — never world-readable (AC1) |
| Manual trigger (`systemctl start restic-backup.service`) | both `ExecStart`s `0/SUCCESS`; snapshot `4078b7d4`, 807 MiB, tag `appdata` (AC2) |
| Excludes | confirmed via `restic ls latest`: no `.../{jellyfin,prowlarr,radarr,sonarr,bazarr,profilarr,jellyseerr,homepage}/{cache,log,logs}` paths present |
| `restic check --read-data-subset=5%` | `no errors were found` |
| **Test restore (AC3)** | sha256 of live `/data/ssd/appdata/radarr/config.xml` vs. `restic restore latest --include .../config.xml` output — **identical hash**, byte-for-byte |
| **Induced-failure test (AC5)** | renamed away `appdata.pass` → `systemctl start` → unit `is-failed` = `failed` → `restic-backup-alert.service` fired, journal shows the `daemon.alert` line + `wall` attempt → password file + failed-state restored via a `trap`, a follow-up real run succeeded (2nd snapshot `d879a127`) |

Both snapshots (`4078b7d4`, `d879a127`) are genuine backups of live appdata, not
synthetic test artifacts — left in the repo (retention will roll them off
naturally per the keep-daily policy), unlike the Paperless throwaway-PDF case.

### Boundaries respected
No media-library path was ever a restic source (different filesystem). No
offsite repo (explicitly deferred). No other role touched beyond the one-line
`site.yml` addition. No compose stack restart/redeploy — only read existing
appdata files.

### Resume checklist (next session)
- `issues/013` (storage alerting): when a real channel is picked, point
  `restic-backup-alert.service`'s `ExecStart` at it (and do the same for the
  SnapRAID/btrfs-scrub `OnFailure=` seams those units already comment about).
- A later issue can extend `restic_backup` (or add a sibling role sharing the
  same repo) to cover Immich + Paperless, each under its own `--tag` so
  retention/`forget` stays independent per app.
- Offsite copy of the local repo (`restic copy` to a second repo, or a cloud
  backend) is still deferred per the PRD.

## 2026-07-02 — issue 005 closed: QuickSync verified + no-public-exposure attested

**State:** issue 005 (Jellyfin over the mesh) is **done** — the last two `needs-human`
ACs landed, so the keystone services slice is fully closed.

- **AC#4 (iGPU QuickSync):** HW accel was never enabled in the Jellyfin UI (no
  `encoding.xml`), though the machine side was already correct: `/dev/dri` passed
  through (cgroup `rwm`), `renderD128` RW to the container process (in the render
  gid), `/transcode` mounted from the SSD tier. User enabled Intel QSV + forced a
  downscale stream. Verified from the **live ffmpeg invocation** in the Jellyfin logs
  (23:07): `-init_hw_device vaapi=va:/dev/dri/renderD128,driver=iHD -init_hw_device
  qsv=qs@va -hwaccel vaapi -hwaccel_output_format vaapi`, `-codec:v h264_qsv`,
  `scale_vaapi` + `hwmap=derive_device=qsv,format=qsv`, segments written to
  `/transcode/*.mp4` — full VAAPI→QSV hardware pipeline, **not** the CPU `libx264`
  path (a stale `libx264` from before the toggle was also in the log). Bonus: the
  title transcoded was a **migrated-library** episode (Poirot S01E01), so this also
  demos issue 008's library serving + HW-transcoding end to end.
- **AC#2 (no public exposure):** user attested OPNsense carries no 80/443 port-forward
  to helium. Consistent with the design — public `*.home.stromdahl.tech` resolves only
  to the non-routable mesh IP (100.65.22.72) and helium has no public IP.
- **Remote-peer test** (hanging off AC#1) was already validated live 2026-07-01.

Checks run read-only from krypton over the mesh (LAN dark from krypton's current
network; helium up 2d, reachable at 100.65.22.72).

## 2026-07-02 — issue 012 closed: SSD-tier btrfs scrub deployed + verified

**State:** issue 012 is **done** — the monthly `btrfs scrub` timer for the
`helium-ssd` raid1 pool is live on helium. The Ansible code for this
(`storage_ssd/tasks/scrub.yml` + the `btrfs-scrub.{service,timer}` unit pair) was
already written and committed by a prior session (`8d2e372`, 2026-06-30) but never
claimed, deployed, or verified — the issue was still `open` and the units did not
exist on the host. This session was deploy + verify + close; no role code changed.

### Deploy (over the mesh, `-e ansible_host=100.65.22.72` — krypton off the home
LAN this session, `.191` unreachable)
| Check | Result |
|---|---|
| 1st `--tags storage_ssd` run | `ok=13 changed=3 failed=0` |
| 2nd `--tags storage_ssd` run (idempotency, AC4) | `ok=12 changed=0 failed=0` |

The 3 first-run changes were the unit-install + timer-enable tasks from this
issue, plus pre-existing host drift on the `downloads`/`transcode` subvolume
mountpoints (unrelated to scrub, not part of this issue's scope) — all three
converged to `changed=0` on the second run.

### Verification
- `btrfs filesystem show /data/ssd/appdata`: label `helium-ssd`, 2 devices
  (`/dev/sdd`, `/dev/sdf`), confirming the raid1 mirror this scrubs.
- `systemctl is-enabled btrfs-scrub.timer` → `enabled` (survives reboot, AC2);
  `list-timers` shows next run `2026-08-01 05:00` — off both SnapRAID windows.
- Manually triggered (`systemctl start btrfs-scrub.service`): completed
  `0/SUCCESS` on both devices, **"Error summary: no errors found"** for
  `/dev/sdd` and `/dev/sdf` — 0 uncorrectable errors on the healthy pool (AC3).
- Unit files confirm low-IO (`Nice=19`, `IOSchedulingClass=idle`) and the
  unmount guard (`RequiresMountsFor=/data/ssd/appdata`) — AC1.
- Checked the sibling `storage_hdd` SnapRAID-scrub unit for an `OnFailure=`
  seam to mirror per the issue's suggestion: it has none yet either, so there
  was nothing to mirror — `issues/013` owns wiring that on both tiers.

### Boundaries respected
No HDD/snapraid scrub or media pool touched. No compose stack restart. No
`site.yml` change (role was already registered from issue 011).

## 2026-07-03 — issue 017: Cleanuparr deployed + wired; stalled-download removal proven end-to-end; all 4 ACs green

**State:** issue 017 → **done**. Cleanuparr (download hygiene for the issue-014
stack) is deployed as a compose service, reachable over the mesh with a real LE
cert, connected to qBittorrent + Radarr + Sonarr using the **existing** issue-014
credentials (no re-key), and its QueueCleaner runs unattended on a 5-minute cron.
The core AC — a deliberately-stalled download being removed from qBittorrent AND
the *arr queue, with the release blocklisted — was **exercised live**, not assumed.

### What was added (all via the compose_stack role — config-as-code)
- **`docker-compose.yml.j2`** — a `cleanuparr` service (`ghcr.io/cleanuparr/
  cleanuparr:2.9.14`): SSD appdata volume (`${APPDATA_DIR}/cleanuparr:/config`),
  the `media` bridge, Traefik labels for `cleanuparr.${DOMAIN}` (websecure + LE
  resolver + `security-headers@file`), a `/health` healthcheck, **no published
  port** (Traefik-only, same LAN+mesh-never-public boundary as every sibling).
  No `/downloads` mount — DownloadCleaner (orphaned-file pruning) is deliberately
  left disabled (real blast radius on the live downloads dir, and not an AC), so
  only the QueueCleaner runs.
- **`host_vars/helium/vars.yml`** — appended `cleanuparr` to `arr_appdata_apps`
  (reuses the existing dir-create+chown loop → `/data/ssd/appdata/cleanuparr`,
  owned 1001:1003); added `cleanuparr_admin_username: admin` + a header note.
- **`secrets.sops.yml`** — `cleanuparr_admin_password` (machine-minted, `sops set
  --value-stdin`, never to stdout). This is Cleanuparr's **own** admin identity
  (like the Immich/Paperless admin), NOT a stack `.env` var — Cleanuparr has no
  ADMIN_* env; the account is created once via its `/api/auth/setup/account`.
- **`homepage/services.yaml`** — a Cleanuparr tile under the Downloads group
  (link + docker status dot; no widget — Homepage has no cleanuparr widget type).

### Config schema note (why the connections are API-driven, not env/seed-file)
Cleanuparr v2.9 keeps ALL business config in its own sqlite db under `/config`
(verified against the v2.9.14 source: `api/configuration/*` + `api/queue-rules/*`
controllers, `[Authorize]`, enums serialized as strings). There is no env-var or
config-file path for download-client / arr-app connections — so, mirroring the
issue-014 app-config discipline, they were set once post-deploy over the mesh via
the REST API (`jq`-built JSON bodies; the qbit password streamed from sops via
`sops exec-env`; the Radarr/Sonarr keys read from each app's `config.xml` on-box
into files, never echoed to a terminal). Setup order is enforced by the code:
`setup/account` → `setup/complete` → `login` (login 401s until setup is complete).

### What was wired (REST API, over `https://cleanuparr.home.stromdahl.tech`)
- **Download client:** qBittorrent, host `http://gluetun:8080` (qbit shares
  gluetun's netns), user `admin`, existing sops password → test **200 "successful"**.
- **Arr apps:** Radarr `http://radarr:7878` + Sonarr `http://sonarr:8989`, each
  with its existing `config.xml` API key, version 3 → both test **200 "successful"**.
- **QueueCleaner:** enabled, cron `0 0/5 * * * ?` (every 5 min, unattended).
  All three paths the issue names are on: **stalled** (a `stalled-public` StallRule,
  3 strikes, Public), **metadata-stuck** (`DownloadingMetadataMaxStrikes: 3`), and
  **failed imports** (`FailedImport.maxStrikes: 3`, `PatternMode: Exclude` with an
  empty list = match-all — the "malformed release the *arr keeps retrying" case; note
  the validator rejects `Include` mode with zero patterns, so Exclude/match-all is the
  way to enable it broadly). Cleanuparr's queue-delete hardcodes
  `blocklist=true&skipRedownload=true` and triggers a fresh search, so
  removal → blocklist → re-search is one action. DownloadCleaner (orphaned-file
  pruning / seeding rules) stays deliberately OFF — real blast radius, not an AC.

### Verified (over the mesh, `-e ansible_host=100.65.22.72` — krypton off the home LAN)
| Check | Result |
|---|---|
| 1st `--tags compose,services` run | `ok=33 changed=5 failed=0` |
| 2nd/idempotency run | `ok=33 changed=1` — the ONLY change is "Bring up the compose stack" (the known gluetun-netns tier `flaresolverr/prowlarr/qbittorrent` Recreate churn); my `.env`/compose/homepage/dir tasks are all `changed=0`, cleanuparr not recreated |
| Cert (AC1) | real LE cert at `cleanuparr.home.stromdahl.tech` (issuer `Let's Encrypt CN=YR2`, valid), `/health` **HTTP 200** over the mesh. Cert issued first try — no Traefik-restart quirk this time |
| Not public (AC1) | no published port; same boundary as all siblings — public `*.home.stromdahl.tech` resolves only to the non-routable mesh IP, no OPNsense port-forward (issue-005 attested) |
| Connections | qbit + Radarr + Sonarr all "health changed: Healthy" in the logs; no auth errors |
| Schedule (AC3) | `Job QueueCleaner scheduled with cron expression '0 0/5 * * * ?'` — runs with no manual trigger |
| Config on SSD (AC4) | `/data/ssd/appdata/cleanuparr` (SSD precious appdata subvol). The only sops entry added is Cleanuparr's OWN admin password; the arr/qbit connection secrets live in Cleanuparr's sqlite (API-set), NOT templated from sops — so a `/config` wipe recovers by **restore, not `ansible-playbook`**. That dir sits under `restic_backup_source` (`/data/ssd/appdata`, issue 016), so it IS backed up. Same model as issue-014's app config. |

### Stalled-download removal — exercised live (AC2), three-part evidence
First attempt used a real TPB magnet grabbed via Radarr; it found peers and began
crawling (0.1%), so `ResetStrikesOnProgress` correctly kept it from striking out —
not a valid stall test. Replaced with a **deterministic dead download**: a
fabricated magnet with a random infohash (no peers → stuck in qBittorrent `metaDL`
forever), pushed into Radarr's queue via `/api/v3/release/push` against a throwaway
unmonitored "Nosferatu (1922)" movie. Cron temporarily set to 1-minute for a
bounded test.
- Strikes accrued **1 → 2 → 3** (reason `DownloadingMetadata`) on consecutive runs,
  then: `Removing item with max strikes` → `item marked for removal` → `queue item
  deleted`.
- **(a)** torrent **gone from qBittorrent** (info API `length=0` for the hash);
  **(b)** item **gone from the Radarr queue** (`totalRecords=0`); **(c)** release
  **present in Radarr's blocklist** (`Nosferatu.1922.1080p.BluRay.x264-CLEANUPARRTEST`,
  movieId 17). All three captured before/after.
- The movie was kept unmonitored so Cleanuparr's post-removal search couldn't grab
  a real release.

Honest scope of the drill: the live removal was exercised on the **stalled/metadata
path against Radarr**. The **failed-import** path and the **Sonarr** instance were
not separately drilled — both ride Cleanuparr's identical strike → remove →
blocklist mechanism (same code, `InstanceType` switch only), and both are
configured + health-green, but only the Radarr metadata case was end-to-end proven.
Heads-up: the QueueCleaner is now **live on the real download stack** (5-min cron) —
a genuinely-stalled real grab will be removed + blocklisted after ~3 strikes (~15 min).

### Cleanup (left pristine, mirroring the Paperless/016 throwaway discipline)
Removed the blocklist entry, deleted the throwaway movie (deleteFiles=true), and
restored the cron to 5-minute. Confirmed: movie 17 → 404, Radarr queue 0, blocklist
0, no radarr-category torrents in qBittorrent, no leftover files in `/data/ssd/
downloads`. (The lone remaining qbit torrent, `Poirot.S13`, is a pre-existing real
sonarr download from an earlier session — not a test artifact, left untouched.)

### Boundaries respected
Only Cleanuparr added. No re-key of the *arr/qBittorrent creds (reused the issue-014
keys). No change to gluetun/VPN or qBittorrent settings. No `site.yml` change
(compose_stack already registered). No full-stack restart — only `docker compose up`
added the one container (the gluetun-netns tier recreates on any compose run by
design). Did not `git push`.

## 2026-07-03 — issue 008 closed: library migration complete (final delta waived by construction)

**State:** issue 008 (migrate the media library from neon) is **done**. This unblocks
`issues/009` (DNS cutover → retire neon) — all of 009's dependencies are now met.

Current pool state (read-only over the mesh from krypton, `ssh 100.65.22.72`):
- `/srv/media` (mergerfs over `/mnt/disk1`+`/mnt/disk2`): **611 G movies + 734 G tv**.
- `neon-migrate` log ends `=== DONE rc_total=0 ===` (2026-06-30 19:40 UTC) — first pass
  complete. Service inactive; snapraid-sync/scrub timers enabled.

**Why closed without a final delta rsync (AC2):**
- The library is *larger* than the ~932 GB migrated — the live 014 download stack has
  been acquiring on helium since (Sonarr/Radarr active; a real `Poirot.S13` grab was
  seen during the 017 run). So **helium has diverged from and now supersedes neon.**
- User confirmed 2026-07-03 that **neon's download side is stopped and all new content
  lands on helium** — neon has been frozen since before the first pass finished
  (`rc_total=0`). So there are **no neon-side changes to reconcile**; a from-neon delta
  could only be empty.
- The documented resume-checklist delta used `rsync --delete` — which is now a
  **foot-gun**: a `neon→helium --delete` would delete helium's newer content. Any real
  reconcile would have to be additive (no `--delete`), and it would transfer nothing.
- Driving it was also blocked at the access layer: helium `sudo` is password-gated
  (non-interactive), the migration source was a **root-only ephemeral key**
  (`/root/.ssh/neon_migrate*`), and neon-rescue is unreachable as `ms`. So a proof-only
  dry-run would need hands on a rescue host that may already be torn down.

AC1 (present + in Jellyfin) and AC3 (migrated title plays over the mesh — Poirot
S01E01 transcoded via QSV during the 005 check on 2026-07-02) were both already met.

**Cleanup folded into `issues/009`:** unmount `/mnt/neon-src` on neon-rescue + remove
the ephemeral key (helium `/root/.ssh/neon_migrate*` and neon-rescue's `authorized_keys`
line) — it's root/neon-side teardown that belongs with the neon decommission.

## 2026-07-03 — issue 009 (in-progress): DNS cutover verified, Immich routing regression fixed, helium-side teardown done

**State:** `issues/009` claimed. The machine-side of the cutover is done + verified over
the mesh; what remains is the **physical** neon power-off/retire (AC#3/#4) + its RAM-only
teardown, which needs the user's hands. A **live Immich outage** was found and fixed in the
process.

### AC#1 (all services resolve to helium + reachable over the mesh with valid certs) — MET
Full over-the-mesh sweep from krypton (roaming, so LAN `.191` dark; helium reached at mesh
`100.65.22.72`). All 12 routed hosts resolve publicly to `100.65.22.72` (the split-horizon
roaming path: public Cloudflare wildcard `*.home.stromdahl.tech` → mesh IP) and serve valid
Let's Encrypt certs (`ssl_verify_result=0`, no `-k`): jellyfin, jellyseerr, radarr, sonarr,
bazarr, prowlarr, **immich**, paperless, homepage, cleanuparr, traefik.

### The Immich regression (found while verifying AC#1; fixed under 009)
Immich alone was **unreachable over the mesh** (`immich.home.stromdahl.tech` → TLS ok but the
HTTP request hung, 0 bytes) for ~10–15 h — so **phone photo auto-backup had been silently
failing** since `immich_server` was last recreated. Nothing alerts on service reachability.
- **Not** a mesh or Immich-app fault: the container was `healthy` and answered directly
  (`localhost:2283/api/server/ping → pong`); from the *box's own* localhost, via Traefik it
  still hung, while jellyfin-via-Traefik returned 302.
- **Root cause:** `immich_server` is **dual-homed** (`helium_media` 172.18.0.11 + `helium_immich`
  172.20.0.5). Traefik is on `helium_media`+`helium_socket_proxy` only. With **no
  `traefik.docker.network` label**, Traefik's docker provider picks one of the container's two
  IPs non-deterministically on recreate; it had latched onto the **immich-net IP 172.20.0.5**,
  which Traefik can't route to → silent hang (proved: from the traefik container, `wget`
  172.18.0.11:2283 → pong, 172.20.0.5:2283 → timeout). `paperless` has the identical latent
  flaw but happened to pick the routable IP.
- **Fix (config-as-code):** added `traefik.docker.network={{ compose_stack_dir | basename }}_media`
  (renders `helium_media`) to **immich-server AND paperless** in `docker-compose.yml.j2`. Value
  must be the *real* (project-prefixed) docker network name — Traefik does not strip the compose
  prefix. Deployed `--tags compose,services` (`changed=2`, tight blast radius: only immich_server
  + paperless recreated for the label + the known gluetun-netns churn; **traefik untouched**, no
  restart needed). Re-verified from krypton: **immich `/api/server/ping → pong`, http 200, valid
  cert.** Commit `639af68`.
- **Ansible gotcha (unrelated to the change):** passing SSH opts as `-e 'ansible_ssh_common_args=-o …'`
  **crashes the ansible-core 2.19 worker** ("A worker was found in a dead state") — the `-o` leaks
  into the worker's argv re-parse (`argparse: argument -o: expected one argument`). Set SSH opts via
  the `ANSIBLE_SSH_ARGS` **env var** instead (not on the CLI). Cost me a long false-trail into
  /dev/shm / fork limits before `ANSIBLE_DEBUG=1` surfaced the real traceback.

### AC#2 (public `jellyfin.stromdahl.tech` removed; nothing public) — MET
`dig jellyfin.stromdahl.tech @1.1.1.1` (A/AAAA/CNAME) → **NXDOMAIN** on public resolvers. A
lingering LAN-IP record would have *resolved*, not NXDOM'd, so nothing is publicly reachable.
(Optional user tidiness: confirm no dangling record remains in the Cloudflare zone dashboard.)

### helium-side migration teardown — DONE
Enumerated (avoids the `file`-module no-glob trap) then removed both ephemeral migration-key
files over the mesh via `become`: `/root/.ssh/neon_migrate` + `/root/.ssh/neon_migrate.pub`
(`changed=true` ×2; re-`find` → `matched:0`). This was the only *persistent* teardown artifact.

### Remaining — needs the user's hands (AC#3/#4 + neon-side teardown)
neon has been **bootless since 2026-06-29** (its OS SSD is in helium) and has served nothing
since; helium has been the sole server for days, so AC#3 ("services work with neon off") holds
functionally. To close AC#3/#4 the user must **physically power off + retire neon** (the Ventoy
rescue OS at `192.168.1.153`). Powering it off also completes the **neon-side teardown**: the
`/mnt/neon-src` bind mount and the `neon_migrate` line in `authorized_keys` live only in neon's
RAM-based rescue OS and vanish on shutdown (I'm off-LAN and can't reach `.153` to verify). neon's
Samsung 990 PRO 2 TB NVMe (old media + Steam) stays in the box — a candidate local backup target,
deferred to the backup work, not part of 009. Repo hygiene (`servers/neon/`, the now-dead
`git push neon` deploy path) can be dropped in a separate cleanup commit — not a 009 close blocker.
