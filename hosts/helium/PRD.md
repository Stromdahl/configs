# helium — NAS + services homelab (PRD)

> Build plan for `helium`, the consolidated NAS + services box on repurposed
> titan hardware. Crystallized from a grilling session; this is the durable
> spec the Ansible build follows. Decomposition into executable tasks is a
> separate step (`to-issues` / `to-tasks`).

## Problem Statement

neon — the current Debian docker host running Jellyfin and the *arr stack — is
out of disk: its 1.8 TB NVMe datastore is 100% full (~6 GB free), capping the
media library and leaving no room for new services. titan has been decommissioned
and its hardware is free to repurpose. The user wants a single consolidated
NAS + services box that (a) holds a large, growing media library on spinning
disks with fault tolerance, (b) adds self-hosted Immich (photos) and Paperless
(documents), (c) keeps the noisy, hot, 7200 RPM enterprise HDDs idle as much as
possible, and (d) is reachable only privately, never from the public internet.
The current setup also has no backups, and is provisioned by a bespoke dotfiles
module system the user wants to begin replacing with Ansible.

## Solution

Build `helium` as a bare-metal Debian box with a three-tier storage design: an
NVMe boot drive for the OS, a redundant SATA-SSD mirror carrying all hot/precious
data, and a large, dual-parity HDD tier carrying only the cold media library. All services run in
Docker behind an internal-only Traefik and are reached exclusively over a NetBird
mesh (nothing exposed to the internet). The box is provisioned by Ansible as a
pilot — run from krypton — with the rest of the fleet left on the existing
dotfiles modules. neon's library and *arr state migrate over, then neon retires.

## User Stories

1. As the operator, I want the media library on a pool that survives two
   simultaneous drive failures, so that used enterprise drives of mixed age don't
   cost me the library.
2. As the operator, I want the HDDs spun down except during streams and the
   nightly parity sync, so that the box is quiet, cool, and low-power.
   > **Update (2026-07-03, issue 004):** platter spin-down is **not achievable** on the
   > LSI SAS3008 HBA + these enterprise SAS drives (commands accepted but ignored; verified
   > exhaustively — see BUILD-LOG). This goal is met by the *architecture* (hot data on SSD,
   > HDD pool touched only by reads + the nightly sync) + HBA cooling + `IDLE_A` head-unload,
   > **not** by spun-down platters. Don't re-attempt spin-down on this hardware.
3. As a viewer, I want Jellyfin + Jellyseerr to keep working as they do on neon,
   with the full library history intact after migration.
4. As the user, I want Immich for my phone photos with on-box ML, so that I have
   a private Google-Photos replacement.
5. As the user, I want Paperless to ingest receipts, invoices, and legal
   documents, so that my records are searchable and private.
6. As the user, I want every service at a clean `*.home.stromdahl.tech` URL with
   valid TLS, reachable only over my private mesh, so that nothing sensitive is
   exposed to the internet.
7. As the operator, I want this box provisioned by Ansible from krypton, so that
   I can pilot a replacement for the custom dotfiles module system without
   disrupting the other hosts.
8. As the operator, I want secrets to keep using sops + age, so that I don't
   fragment secret management across the fleet.

## Implementation Decisions

### Hardware / physical layout
- Repurposed titan: Supermicro X11SCV-Q (Mini-ITX), i5-9400 with UHD 630 iGPU.
  RAM stays at 16 GB initially; a bump to the board maximum of 32 GB is planned
  later (both SO-DIMM slots get replaced, as both are populated).
- The board offers only two usable PCIe positions: one CPU-direct **PCIe 3.0 x16**
  slot and one chipset **M.2 M-key (x4)** slot (the second M.2 is a 2230 E-key,
  WiFi-only). That is one slot short of the three cards on hand, so the **RTX 2060
  is pulled** — Immich ML moves to the CPU and the local-LLM idea stays out of
  scope.
- The **LSI 9300-8i HBA** (SAS3, native IT-mode) goes in the **x16 slot**: native
  x8 lanes, full 75 W slot power, and normal card-position airflow. This deletes
  both M.2-adapter hacks the earlier plan required — an external power lead (the
  M.2 slot cannot feed an x8 HBA) and a bolted-on fan against the GPU's heat.
- The repurposed **970 EVO Plus 250 GB NVMe** goes in the M.2 M-key slot as the
  **boot/OS drive**. It was already titan's boot disk, so it is proven on this
  board; a SMART check is worthwhile since it is a used drive.

### Storage
- **Boot tier:** the 970 EVO Plus 250 GB NVMe carries the **OS/boot only**, kept
  lean. It is a single non-redundant drive — an acceptable trade because the OS is
  fully Ansible-reproducible: a failure means reinstall + re-run, with all data
  intact on the redundant tiers below.
- **Data tier:** the two 500 GB SATA SSDs as a **btrfs raid1** mirror, carrying all
  Docker appdata (configs + databases), the Immich library, Paperless, plus the
  lean downloads and transcode cache. btrfs is chosen for data checksumming (the
  board is non-ECC, so this guards against silent bit-rot) and cheap snapshots.
  The precious subvolumes keep full CoW + checksums; the **scratch subvolumes
  (downloads, transcode cache) get `chattr +C` / nodatacow** to avoid CoW
  fragmentation (important for torrents) and pointless checksumming of throwaway
  data. These workloads are not disk-bound — a SATA SSD is far faster than either
  needs — so they live here rather than on the boot NVMe, keeping the single used
  boot drive lean. Current hot data is small (~15 GB Immich, tiny Paperless)
  against 500 GB, so 500 GB usable is ample and redundancy is the better use of
  the second SSD than capacity.
- **HDD tier:** the four 12 TB SAS drives via the HBA, as **SnapRAID with
  2 parity + 2 data drives** (24 TB usable, dual-fault tolerant), pooled with
  **mergerfs** using a fill-one-drive-at-a-time create policy. Holds only the
  Jellyfin media library. Capacity is a non-issue (sub-1 TB library against
  48 TB raw), so the two parity drives cost nothing real.
- **Spin-down** is a best-effort bonus via sdparm / sg3utils (these are SAS;
  `hdparm` does not apply). The load-bearing mechanism is architectural: the HDDs
  are touched only by library reads and the nightly SnapRAID sync, so a single
  disk spins for a stream while the others sleep.

### Compute split
- iGPU (UHD 630) → Jellyfin QuickSync transcoding (unaffected by pulling the 2060).
- CPU (i5-9400, 6C/6T) → Immich ML, Paperless OCR, and the *arr stack. Immich ML
  on CPU is fine for a small personal library — a one-time bulk job on import plus
  trivial incrementals; only the initial run is slower.
- No discrete GPU. The 2060/CUDA path and the future local LLM are dropped (see
  Hardware / physical layout); re-adding the 2060 later would mean revisiting the
  slot allocation.

### Services & access
- Docker stack: Jellyfin, Jellyseerr, the *arr stack (radarr/sonarr/prowlarr/
  bazarr/profilarr), qBittorrent behind **gluetun** (retained for ISP privacy),
  Immich, Paperless, Traefik, NetBird client.
- **No public exposure and no router port-forward.** Traefik runs internal-only,
  obtaining real certificates via **Let's Encrypt DNS-01** using the existing
  Cloudflare token (DNS-01 validates over the API and needs no inbound
  connection).
- Access is **private but not internet-exposed**, reachable two ways: over the
  **NetBird mesh** (NetBird cloud control plane, free personal tier, clients only
  — the control plane is not self-hosted) for roaming and remote devices, and
  **directly over the trusted LAN** for appliance devices that cannot run a
  NetBird client (smart TV, Chromecast, consoles). "Private" means no router
  port-forward and no public DNS record — **not mesh-only**.
- All services are served at `*.home.stromdahl.tech`. The name resolves to
  helium's **mesh IP** for mesh clients (NetBird DNS) and to its **LAN IP** for
  on-LAN clients (a public A record returning the RFC1918 address, or local DNS);
  the Let's Encrypt wildcard certificate is valid by name regardless of which
  address is used.

### Configuration management
- **Ansible pilot.** A new Ansible tree inside the dotfiles repo (mirroring the
  archived homelab-stack layout: inventory, host playbook, roles); the custom
  bash modules stay the standard for krypton/argon/the PVE hosts. This box is the
  pilot only.
- Playbooks are **pushed from krypton over SSH** as the `ms` admin user — the box
  holds no GitHub key and no deploy key, and never runs the dotfiles installer.
  This **drops the prior deploy-user + bare-git/post-receive pull pipeline** for
  this host.
- Secrets remain **sops + age**, but decryption happens **on krypton**: the box
  never holds an age key, and — unlike the other servers — it has **no per-host
  key**, so only the admin key can decrypt its secrets. Two secret homes by
  consumer: Ansible-consumed values (the sudo/become password now; role tokens
  later) are sops-encrypted **YAML loaded as variables** and **consumed at
  run-time without ever landing on the box**; the Docker compose environment is a
  sops-encrypted **dotenv rendered to disk** (mode 0600) when the service stack
  is deployed. Making the become password a sops variable also keeps runs
  non-interactive and idempotent. **Drops the prior role that generated a
  per-host age key.**
- **Hardening matches the fleet.** The base role reproduces what the dotfiles
  hardening modules produce — key-only SSH with no root login, ufw default-deny
  allowing 22/80/443, a fail2ban sshd jail, and unattended security upgrades with
  no automatic reboot — so helium's posture stays consistent with the rest of the
  fleet. Docker is **docker-ce from the official repository** (current engine +
  compose v2), installed via the geerlingguy.docker role.
- helium is addressed by a **pinned DHCP reservation** (keyed to its NIC MAC) — a
  one-time manual router step the Ansible inventory depends on.
- **Bootstrap:** a plain single-disk Debian install on the NVMe. The boot drive is
  no longer a btrfs raid1 root, so the earlier "raid1 root can't be built from
  within the same Ansible run" constraint is gone — Ansible now does everything
  else, **including building the btrfs raid1 data pool** on the two SATA SSDs: base
  hardening, Docker, and the NAS-specific roles — the btrfs raid1 data filesystem
  (with the nodatacow scratch subvolumes); mergerfs; snapraid (with sync/scrub
  timers); SAS tooling (sdparm/sg3utils/smartctl) plus spin-down timers; NetBird
  client; and a compose-stack role that templates the env/secrets and brings the
  stack up.

### Migration & cutover
- **Parallel build:** stand up helium, rsync the ~932 GB media library to the HDD
  pool while neon keeps serving, and **migrate the *arr Docker volumes** so
  library history and quality profiles survive intact rather than being rebuilt.
- **Start lean:** the ~600 GB of old completed seeds are dropped (ratio is not a
  concern); only incomplete/recent downloads carry over and live on the data-tier
  mirror.
- **Final delta sync**, then point `*.home.stromdahl.tech` at helium and remove
  the old public `jellyfin.stromdahl.tech` record (the setup is now all-private).
  After verification, neon retires and its 1.8 TB NVMe is freed (a candidate
  local backup target).

## Testing Decisions

No meaningful unit-test surface — this is infrastructure/config. Validation is
operational:
- SnapRAID sync and scrub complete cleanly.
- HDDs spin down and wake correctly; a single stream spins only one disk.
- Each service is reachable at its `*.home.stromdahl.tech` URL over the mesh with
  a valid TLS certificate.
- Jellyfin transcodes on the iGPU; Immich ML runs on the CPU.
- Migrated *arr instances show intact library history after cutover.

## Out of Scope

- **Backups** (deferred). Syncthing to phone/laptop is interim redundancy, not
  backup. The planned offsite (a friend's storage) will be a **versioned
  restic/borg target — explicitly not another Syncthing peer** — plus a local
  restic repo on the HDD pool, scoped to Immich + Paperless + appdata. The media
  library is excluded (SnapRAID-protected and re-acquirable).
- The 32 GB RAM upgrade.
- Ratio-based / private-tracker seeding (would require revisiting download
  storage — a dedicated drive or accepting one HDD stays spinning).
- A discrete-GPU / local-LLM workload — the RTX 2060 is pulled (see Hardware /
  physical layout).
- Any public internet exposure.
- Self-hosting the NetBird control plane (rejected in favor of the cloud tier).
- Migrating the rest of the fleet off the custom dotfiles modules — this box is
  a pilot only.

## Further Notes

- neon's urgency driver: its datastore is 100% full.
- The drives are HPE-branded HGST Ultrastar He12 (MB012000JWDFD), 7200 RPM
  enterprise SAS, manufactured 2019–2022. The mixed age and used provenance are
  the rationale for dual parity.
- The seeding decision is revisitable: joining ratio-based trackers later would
  mean moving seed data to the HDD pool (accepting a spinning disk) or adding
  dedicated storage.
