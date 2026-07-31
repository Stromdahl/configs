# Add a Syncthing ansible role: helium as a Send-Receive vault replica

Type: execution
Status: open

> ✅ **RE-SPECCED 2026-07-31 — build as now written.** This ticket originally
> specced `Receive Only`; it is now **`Send-Receive`**, because the
> [hermes-helium map](../../hermes-helium/map.md) puts a *writing* agent (Hermes:
> files, captures, categorizes) on this same replica, and a receive-only folder
> would silently discard everything it writes. Everything else is unchanged
> (`/data/ssd/vault`, `ms`-owned, Ignore Permissions, `UMask=022`, krypton
> first-reconcile source). Amendment made by
> [hermes-helium ticket 04](../../hermes-helium/issues/04-respec-vault-serve-004-send-receive.md),
> which also records the verified consequences (see **Consequences of
> Send-Receive** below). Ticket [005](005-perlite-service.md) is **unaffected** —
> its boundary is the `:ro` bind-mount surface, not the folder type.

_Graduated from the vault-serve map once the way was clear (decisions in
tickets [02](02-syncthing-on-helium.md) + [03](03-allowlist-enforcement.md))._
This is implementation, not a decision — build it per the spec below.

## Goal

A new ansible `syncthing` role that makes **helium** a full Syncthing peer
holding the whole vault as a **read-write (`Send-Receive`) replica** of krypton,
with perms normalized so the Perlite container (issue
[005](005-perlite-service.md)) can read the allowlisted folders.

## Spec (all decided — do not re-litigate)

- **Install Syncthing** on helium as the **`ms` user service**
  (`systemctl --user`, lingering enabled for `ms`). helium is ansible-only, so
  this is a role under helium's play, not a dotfiles module.
- **Folder:** `/data/ssd/vault` (new SSD *precious* subvol, owned `ms`),
  shared with krypton.
  - **`Send-Receive`** (Syncthing folder `type: sendreceive`) — helium both
    receives from and pushes to krypton. *Why:* the hermes-helium map puts a
    writing agent on this replica; under `Receive Only` every file Hermes
    created or edited would sit as an undistributed "local change" that the next
    upstream edit silently overwrites. krypton remains the **first-reconcile
    source** (helium starts empty and fills from krypton) but is no longer
    *authoritative* — this is a two-writer folder by design.
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
  sync (`project_hermes_vault_sync`) — do not let provisioning clobber it. Under
  `Send-Receive` this trap is **high-exposure, not low** (see below).
- **Provisioning must leave the folder genuinely empty before first sync.** Under
  `Receive Only` any pre-seeded content would have been quietly kept local; under
  `Send-Receive` it is **pushed to krypton and the phone**. The role must create
  `/data/ssd/vault` empty and let Syncthing populate it — never pre-populate,
  never restore a backup into it as a provisioning step.

## Consequences of Send-Receive (verified 2026-07-31, hermes-helium ticket 04)

Checked against the Syncthing docs rather than assumed:

- **Local deletions now propagate upstream.** `Send-Receive` sends local changes
  *including deletions* to every peer; `Receive Only` did not. So an agent
  reorganizing or deleting on helium's copy now destroys the same files on
  krypton and the phone. This is precisely the v0.14 catastrophe
  (`project_hermes_vault_sync`), and it is why the hermes-helium map keeps
  Hermes' memory in `~/.hermes` (never the vault), keeps the write surface
  narrow ([hermes-helium 08](../../hermes-helium/issues/08-vault-read-write-surface.md)),
  and leans on `~/vault` being a **git repo** as the real undo. The `.stfolder`
  marker-guard prior art (`bin/hermes-vault-ensure-marker.sh`, recoverable per
  [hermes-helium 02](../../hermes-helium/issues/02-recover-briefings-branch-inventory.md))
  belongs to whoever builds this role — note it targeted the old `hermes-vault`
  folder id and was gated to hosts with `~/.hermes`, so both need updating for
  `personal-vault` on helium.
- **`.sync-conflict-*` files are now expected.** Two writers on one folder means
  occasional conflict copies. Accepted: the write surface is deliberately narrow
  and git is the safety net. Do **not** add conflict-resolution machinery to this
  role.
- **Perlite's read path is unaffected** — verified, not assumed. `Ignore
  Permissions` is documented as folder-type independent (receivers "use whatever
  their default permission setting is when creating the files"), so helium still
  lands `755`/`644` from `UMask=022` under `Send-Receive`; and ticket 03's
  boundary is the `:ro` **bind-mount surface**, which the folder type does not
  touch. Ticket [005](005-perlite-service.md) needs no change.
- **`Ignore Permissions` is now doing a second job.** Previously it stopped
  helium replicating krypton's inconsistent modes inbound. Now it *also* stops
  helium's `UMask=022` modes propagating **outbound**: files helium announces
  carry the no-permission-bits flag, so krypton recreates them at its own
  default. Consequence: a file Hermes rewrites may not keep `recipes/`'s current
  `770`/`660` tightness on krypton. Cosmetic mode drift on a single-user laptop,
  not a security change — but do not "fix" it by turning `Ignore Permissions`
  off, which would break Perlite's read path.

## Done when

- helium shows the vault folder **Up to Date**, **Send-Receive**, in sync with
  krypton.
- `/data/ssd/vault/recipes` and `/data/ssd/vault/learning` exist on helium with
  dirs `755` / files `644` (readable-by-other); root is `700`.
- Role is idempotent (re-run = no-op) and committed under helium's ansible tree.
