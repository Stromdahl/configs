# Re-spec vault-serve 004 to Send-Receive and cross-link both maps

Type: task
Status: open

## Question

Apply this map's **write-posture decision** to the still-open vault-serve ticket
that contradicts it, and cross-reference both maps so no session builds the wrong
thing.

Nothing to decide — the decision was taken while charting (see the map's Notes).
This is the mechanical follow-through, and it is **urgent relative to the rest of
the map**: `planning/vault-serve/issues/004-syncthing-role.md` is `status: open`
and any session that grabs it today will build a **Receive Only** replica.

### The conflict

`planning/vault-serve/issues/004-syncthing-role.md` specs helium's Syncthing
replica as:

- folder `/data/ssd/vault`, **Receive Only**, **Ignore Permissions**
- `UMask=022` on the `ms` user Syncthing service
- krypton authoritative, helium a *pure passive replica*

That was correct for vault-serve's purpose (Perlite serving a read-only
include-list). It is **incompatible** with this map: an assistant that files,
captures and categorizes is a **writer**.

### What to do

1. **Amend `004`'s spec to Send-Receive**, preserving everything else (path,
   ownership by `ms`, Ignore Permissions, `UMask=022` — vault-serve ticket `03`
   decided those and they still hold, though ticket `03`/`08` here may add to them).
   Record *why* inline, so the change reads as deliberate rather than as drift.
2. **Note the consequence** on `004`: two writers on one folder means occasional
   `.sync-conflict-*` files. That is accepted — the write surface is deliberately
   narrow (ticket `08`) and `~/vault` is a **git repo**, which is the real safety
   net.
3. **Leave a cross-reference on both maps** — `planning/vault-serve/map.md` and
   this one — so a fresh session working either effort sees the coupling.
   vault-serve's map currently declares itself *"decision-complete"*; that claim is
   no longer strictly true and should say so.
4. **Do not build `004`.** It stays execution work for vault-serve; this ticket
   only corrects its spec. Likewise leave `005` (Perlite) alone — Send-Receive does
   not change the serve-layer include-list, which remains vault-serve's spine.
5. Confirm whether Perlite's read path is affected by the posture flip. Expected
   answer: no — the boundary there is the **bind-mount surface**, not the folder
   type. Verify rather than assume.

### Worth flagging while in there

The **`.stfolder` marker-guard** prior art (`bin/hermes-vault-ensure-marker.sh`,
recoverable per ticket `02`) was written for exactly the disaster that a
writing agent on a Syncthing folder can cause. Whichever ticket owns the syncthing
role should carry it. Note it targeted the old `hermes-vault` folder id and was
gated to hosts with `~/.hermes` — both need updating for `personal-vault` on helium.
