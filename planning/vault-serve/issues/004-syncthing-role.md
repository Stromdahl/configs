# Add a Syncthing ansible role: helium as a Receive-Only vault replica

Type: execution
Status: open

> ⚠️ **SUPERSEDED 2026-07-31 — do not build as written.** `Receive Only` →
> **`Send-Receive`**: the [hermes-helium map](../../hermes-helium/map.md) puts a
> *writing* agent on this same replica. Everything else below stands
> (`/data/ssd/vault`, `ms`-owned, Ignore Permissions, `UMask=022`). The re-spec is
> [hermes-helium ticket 04](../../hermes-helium/issues/04-respec-vault-serve-004-send-receive.md).

_Graduated from the vault-serve map once the way was clear (decisions in
tickets [02](02-syncthing-on-helium.md) + [03](03-allowlist-enforcement.md))._
This is implementation, not a decision — build it per the spec below.

## Goal

A new ansible `syncthing` role that makes **helium** a full Syncthing peer
holding the whole vault as a **passive, receive-only replica** of krypton, with
perms normalized so the Perlite container (issue
[005](005-perlite-service.md)) can read the allowlisted folders.

## Spec (all decided — do not re-litigate)

- **Install Syncthing** on helium as the **`ms` user service**
  (`systemctl --user`, lingering enabled for `ms`). helium is ansible-only, so
  this is a role under helium's play, not a dotfiles module.
- **Folder:** `/data/ssd/vault` (new SSD *precious* subvol, owned `ms`),
  shared with krypton.
  - **`Receive Only`** — krypton is authoritative; helium never pushes.
  - **Ignore Permissions = true** — helium writes synced files at its own
    filesystem default rather than replicating krypton's inconsistent modes
    (krypton has `learning/` `755`/`644` but `recipes/` `770`/`660`).
  - **`UMask=022`** pinned on the Syncthing service unit → synced dirs land
    `755`, files `644` (readable-by-other) deterministically. This is what lets
    the Perlite/nginx container uids (82 / 101) read the mounted folders, and it
    auto-covers any future allowlisted folder.
  - The vault **root `/data/ssd/vault` stays `700` `ms`** — sensitive folders
    sync in as world-readable *dirs* but sit behind the `700` traversal gate and
    are never mounted into any container.
- **Firewall:** open **22000/tcp** (sync) + **21027/udp** (local discovery) on
  helium's firewall path. Mind the ufw-vs-iptables-persistent hazard
  (`project_ufw_breaks_iptables_persistent`) — helium currently has no ufw.
- **Pairing:** add helium's device ID to krypton and share the vault folder;
  accept on helium. krypton + phone are the existing peers (titan is gone).
- **Syncthing gotcha:** an agent deleting `.stfolder` on reorg silently halts
  sync (`project_hermes_vault_sync`) — do not let provisioning clobber it.

## Done when

- helium shows the vault folder **Up to Date**, **Receive Only**, syncing from
  krypton.
- `/data/ssd/vault/recipes` and `/data/ssd/vault/learning` exist on helium with
  dirs `755` / files `644` (readable-by-other); root is `700`.
- Role is idempotent (re-run = no-op) and committed under helium's ansible tree.
