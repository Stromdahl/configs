# Add a Syncthing ansible role: helium as a Send-Receive vault replica

Type: execution
Status: open
<!-- amended 2026-07-31 by hermes-helium 04 (Send-Receive) and 11 (vault undo) -->


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
>
> ⚠️ **AMENDED AGAIN 2026-07-31 — this replica has no undo unless you build one.**
> The re-spec above leaned on *"`~/vault` is a git repo"* as the safety net for the
> writing agent. **That is false for this replica**, and the two places below that
> said so are now corrected. helium's copy has **no git repo at all** (`.stignore`
> excludes `.git`), and Syncthing file versioning was found **off on every krypton
> folder** — so as specced, a bad agent write or delete propagates to krypton *and*
> the phone within seconds with **no point-in-time copy anywhere**. The replacement
> undo is **staggered versioning on krypton**, now specced in **Vault undo (required
> — the only undo there is)** below. Amendment made by
> [hermes-helium ticket 11](../../hermes-helium/issues/11-vault-undo-riders-to-vault-serve-004.md);
> reasoning in [hermes-helium ticket 03's Answer](../../hermes-helium/issues/03-deployment-shape-and-state.md#answer).

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
    *authoritative*. Note the peer count: krypton **and the phone** were already
    `Send & Receive` (ticket 02), so helium makes **three read-write peers**, not
    two — conflicts can arise between any pair of them.
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
  Hermes' memory in `~/.hermes` (never the vault) and keeps the write surface
  narrow ([hermes-helium 08](../../hermes-helium/issues/08-vault-read-write-surface.md)).
  ~~and leans on `~/vault` being a **git repo** as the real undo~~ — **struck
  2026-07-31: git is not the undo for this replica.** helium's copy has no `.git`
  (excluded by `.stignore`), and `.gitignore` untracks finance *data* even on
  krypton, so git never covered the highest-value area. See **Vault undo** below.
  The `.stfolder`
  marker-guard prior art (`bin/hermes-vault-ensure-marker.sh`, recoverable per
  [hermes-helium 02](../../hermes-helium/issues/02-recover-briefings-branch-inventory.md))
  belongs to whoever builds this role — note it targeted the old `hermes-vault`
  folder id and was gated to hosts with `~/.hermes`, so both need updating for
  `personal-vault` on helium. **The full change list is now in
  [hermes-helium 02's verdict table](../../hermes-helium/issues/02-recover-briefings-branch-inventory.md#answer)
  (inventoried 2026-07-31) — read it before porting.** One item from it must not be
  missed: **the script as written fails silent by construction.** It opens with
  `[[ -d "$VAULT" ]] || exit 0` on a hardcoded `$HOME/hermes-vault`, and also
  `exit 0`s on a missing Syncthing `config.xml` and on an empty GUI API key. Ported
  against a path that no longer exists, it reports success and guards nothing — on a
  Send-Receive folder where deletions propagate upstream. **Make every one of those
  three paths fail loudly.** Its packaging also has to change: it was a
  `--user` unit with `ExecStart=%h/.dotfiles/bin/…`, and helium has no dotfiles
  checkout — but an `ms`-user unit still fits, since Syncthing already runs that way
  here with lingering enabled. The mechanism itself is sound: read the API key and
  port out of Syncthing's own `config.xml`, then `POST /rest/db/scan?folder=<id>`.
- **`.sync-conflict-*` files are now expected.** **Three** read-write peers
  (krypton, phone, helium — the phone was already `Send & Receive` per ticket 02)
  means occasional conflict copies, and not only against krypton: a phone-vs-helium
  conflict can happen with krypton uninvolved. Accepted: the write surface is
  deliberately narrow, and the recovery path is **krypton's staggered versioning**
  (**not** git — struck above). Do **not** add conflict-resolution machinery to this
  role. Note that **conflicts are preserved by the conflict copy itself, not by
  versioning** — the two mechanisms are separate and it is worth not conflating them:
  *"The file with the older modification time will be marked as the conflicting file
  and thus be renamed"* to `<name>.sync-conflict-<date>-<time>-<modifiedBy>.<ext>`,
  so the loser is **renamed aside rather than overwritten** and the newer copy keeps
  the original filename. Nothing is silently discarded, including the
  modification-vs-deletion case (*"if the deletion wins the conflict resolution, the
  file is renamed to a conflict copy as above"*). Verified against
  [docs.syncthing.net/users/syncing](https://docs.syncthing.net/users/syncing.html#conflict-handling),
  2026-07-31.
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

## Vault undo (required — the only undo there is)

Added 2026-07-31 by [hermes-helium 11](../../hermes-helium/issues/11-vault-undo-riders-to-vault-serve-004.md).
**Do not treat this section as optional hardening.** With `Send-Receive` live and a
writing agent on the replica, these three items are the *entire* undo story for the
vault: `/data/ssd/vault` is outside restic (`restic_backup_source` is
`/data/ssd/appdata` only), helium has no git repo, and the owner declined adding one.
Build the role without this and a misfiring agent has no recovery path on any peer.

**1. Enable staggered file versioning on krypton's `personal-vault` folder,
`maxAge` 365 days — krypton only.**

The krypton-only part is the non-obvious bit, so carry the reasoning, not just the
setting. Syncthing's docs are explicit that versioning fires only on *incoming*
changes: *"Versioning applies to changes received from other devices… If Alice
changes a file locally on her own computer Syncthing will not and can not archive
the old version."* (verified against
[docs.syncthing.net/users/versioning](https://docs.syncthing.net/users/versioning.html),
2026-07-31.) So:

- Hermes' writes happen **locally on helium** → helium *sends* them → versioning on
  helium would archive **nothing** about them. It would only protect helium from
  krypton's edits, while growing a `.stversions` tree on the SSD that is outside
  restic. Wrong side.
- Those same writes arrive on **krypton** as incoming changes → krypton's versioning
  archives krypton's previous copy. Right side, and krypton holds the authoritative
  copy. Deletions count too: an agent delete on helium lands on krypton as an
  incoming delete and is archived rather than simply vanishing.
- **Staggered, not Trash Can:** Trash Can keeps only the newest superseded version,
  and the realistic failure here is an agent misfiring *unnoticed for days* — by
  which time Trash Can holds only the corrupted state. Staggered thins with age
  (30 s → hourly → daily → weekly) and keeps a year of it.
- ⚠️ **`maxAge` is in seconds, not days** — a role templating `config.xml` must write
  **`31536000`**, not `365`. (The GUI takes days and converts; the config file does
  not. `365` there means six minutes of history — a silent, plausible-looking
  near-miss of exactly the class the hermes-helium map exists to design out.)
- No ignore-file change is needed on krypton: `.stversions` is already in both
  `~/vault/.gitignore` and `~/vault/.stignore` (verified 2026-07-31), so it is
  neither committed nor synced onward.
- Sizing, for the disk budget: `~/vault` is **53 MB / 1158 files** today, so a year
  of staggered history on a markdown vault is negligible on krypton.
- The **phone** stays unversioned and that is accepted — it is a third read-write
  peer, not a recovery source. Recovery is from krypton.

**2. Add `.git` to helium's Syncthing ignore patterns.**

Belt-and-braces, and cheap. Ignore patterns are **per-device**: *"The `.stignore`
file itself will never be synced to other devices"* (verified against
[docs.syncthing.net/users/ignoring](https://docs.syncthing.net/users/ignoring.html),
2026-07-31), so krypton's existing `.git` exclusion does **not** travel with the
folder — helium needs its own. Today helium has no `.git` to send, so this is not
load-bearing on day one; but under `Send-Receive` anything that ever creates one
there would propagate it upstream and recreate precisely the `.sync-conflict` churn
that krypton's exclusion exists to prevent (see the comment at the top of
`~/vault/.stignore`). Mirror krypton's line rather than inventing a pattern.

**3. Cross-link, so this doesn't get read as a nicety.**

The versioning setting is the vault's *only* undo now that git is ruled out for this
replica. Whoever builds this role should read
[hermes-helium ticket 03's Answer](../../hermes-helium/issues/03-deployment-shape-and-state.md#answer)
for why git died here (`.stignore` excludes `.git`; `.gitignore` untracks finance
data; owner declined a helium audit repo) before deciding this is skippable.

**Scope note:** item 1 is a change on **krypton**, which is outside helium's ansible
play. Whether it lands as a manual GUI change, a krypton-side dotfiles change, or a
new ticket is the builder's call — but it is *this* ticket's responsibility that it
happens, because the replica is unsafe without it. Item 2 is inside the role.

## Done when

- helium shows the vault folder **Up to Date**, **Send-Receive**, in sync with
  krypton.
- `/data/ssd/vault/recipes` and `/data/ssd/vault/learning` exist on helium with
  dirs `755` / files `644` (readable-by-other); root is `700`.
- Role is idempotent (re-run = no-op) and committed under helium's ansible tree.
- **krypton's `personal-vault` folder shows staggered versioning with `maxAge`
  `31536000`** (seconds — see the warning above), and a deliberate test proves it:
  edit a file on helium, confirm the previous version appears in
  `~/vault/.stversions/` on krypton. An unverified versioning setting is not an undo
  — the same argument hermes-helium `03` makes about unrestored backups.
- helium's ignore patterns contain `.git`.
