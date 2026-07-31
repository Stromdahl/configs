# Decide the Syncthing-on-helium approach & full-vault security posture

Type: grilling
Status: resolved
Blocked by: —

## Question

How should the vault land on helium via Syncthing, and is the resulting posture
acceptable? Resolve:

- **Deploy method:** a reusable dotfiles/ansible Syncthing setup (matches
  helium's IaC) vs a one-off manual pairing. Where does the vault live (which
  user's home, which path) and with what filesystem ownership/permissions?
- **Security posture:** confirm the full vault (incl. finance/health/people/
  journal) physically resting on helium — a LAN-reachable, household-accessible
  box — is acceptable, and decide any disk-level hardening (perms, dedicated
  user) beyond the serve-layer allowlist.
- **Sync-halt gotcha:** how to avoid the `.stfolder` deletion silent-halt failure
  mode (see `project_hermes_vault_sync`); which peer is authoritative on first
  reconcile.

The actual install/pairing is execution that follows this decision — this ticket
settles the approach, not the doing.

## Answer

**Deploy method → a new ansible `syncthing` role** (not the per-user dotfiles
module). helium is the ansible pilot — everything on it is a role in
`ansible/site.yml`; a hand-paired Syncthing would be the one snowflake a
bare-metal rebuild loses. The proven logic in `bin/setup-syncthing.sh` (apt
install, `enable-linger`, enable the user service, drop the auto-created
`default` folder) ports cleanly into idempotent tasks. Its `sudo ufw allow`
branch is a no-op on helium (no ufw — iptables-persistent from compose_stack;
see `project_ufw_breaks_iptables_persistent`), so the role must open Syncthing's
ports (22000/tcp, 21027/udp) via helium's actual firewall path, or rely on the
NetBird mesh / LAN reachability — a detail for the execution issue.

**Where the vault lives → `/data/ssd/vault`**, a new btrfs **precious**
subvolume (add to `ssd_subvolumes_precious` in `host_vars/helium/vars.yml`),
same tier/treatment as immich/paperless (CoW + checksums). Owned by **`ms`**,
with Syncthing running as the **`ms` user service** (systemd `--user` + linger),
deliberately separate from the stack's `1001:1003` service identity — the vault
is the user's data, not a stack service's.

**Security posture → plaintext-at-rest, `700` on the vault root, no dedicated
service user.** Affirmed with eyes open: the serve-layer allowlist (ticket 03)
protects the *website*, not the *files* — anyone with shell/file access to
helium reads the sensitive folders (finance/health/people/journal) in plaintext.
That is the same deal already accepted for Paperless; encryption-at-rest
(gocryptfs/age) was considered and rejected as over-engineering for a
single-admin box (it also fights the live-plaintext-render model and makes
Syncthing carry ciphertext). `700`/`ms` means only `ms` + root traverse the
vault. **Hand-off to ticket 03:** the two allowlisted subdirs (`recipes/`,
`learning/`) must be readable by Perlite's container uid (php-fpm/nginx, *not*
`ms`), so they get opened up (world-readable, or a shared group) while the `700`
root keeps everything else sealed — the **disk-layer echo of the include-list**:
the only dirs a container can reach on disk are the ones we publish. Exact perm
mechanism + the container's read uid are ticket 03's to pin.

**Sync-safety → helium is `Receive Only`; krypton authoritative.** helium starts
empty and fills clean from krypton (no merge, no conflict on first reconcile);
phone + krypton stay `Send & Receive`. Receive-only + Perlite's `:ro` mount make
helium a pure passive replica: it consumes the vault but can never push a change
back upstream. The `.stfolder` silent-halt trap
(`project_hermes_vault_sync`) is low-exposure here (nothing edits or reorganizes
helium's copy) but the rule stands — nothing on helium may delete `.stfolder`;
Perlite mounts the subdirs, not the vault root, so it never sees the marker.

> ⚠️ **This paragraph is partly overturned (2026-07-31,
> [hermes-helium ticket 04](../../hermes-helium/issues/04-respec-vault-serve-004-send-receive.md)).**
> helium is now **`Send-Receive`**, because the
> [hermes-helium map](../../hermes-helium/map.md) puts a *writing* agent (Hermes)
> on this replica. Three corrections, in order of how badly they bite:
> 1. **"low-exposure … nothing edits or reorganizes helium's copy" is now false.**
>    Something does: Hermes. This is the trap's *highest*-exposure host, and local
>    deletions now propagate to krypton and the phone.
> 2. **"pure passive replica … can never push a change back upstream" no longer
>    holds.** krypton stays the *first-reconcile source* but is not authoritative;
>    this is a two-writer folder, and `.sync-conflict-*` files are accepted.
> 3. **"no conflict on first reconcile" still holds, but is now conditional** —
>    helium's folder must be genuinely empty before first sync, since pre-seeded
>    content would be pushed upstream rather than kept local.
>
> The rest of this answer stands unchanged: the ansible-role deploy method,
> `/data/ssd/vault` as a precious subvol owned by `ms`, the `ms` user service, and
> the plaintext-at-rest + `700`-root posture. The re-spec lives in
> [`004`](004-syncthing-role.md); the reasoning is on the hermes-helium map.

**Graduation:** no new *decision* tickets — this answer is self-contained. The
Syncthing role's *execution* is now fully specified but is held to graduate into
real `issues/NNN` together with the rest of the deploy wiring once ticket 03 (the
last decision) lands, so the execution issues stay coherent.
