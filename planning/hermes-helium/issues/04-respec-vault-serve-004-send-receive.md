# Re-spec vault-serve 004 to Send-Receive and cross-link both maps

Type: task
Status: resolved

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
3. ~~Leave a cross-reference on both maps.~~ **Already done while charting
   (2026-07-31, commit `5e74c59` + follow-up):** `planning/vault-serve/map.md` carries
   the coupling note and no longer claims to be decision-complete, and `004` itself
   carries a SUPERSEDED stop-sign at the top. What remains for this ticket is the
   **substantive amendment of `004`'s spec body and title** (still says
   "Receive-Only vault replica"), plus item 5 below.
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

## Answer

Done. `Receive Only` → `Send-Receive` is applied to vault-serve `004`, and the
posture flip turned out to touch **four** files, not the one the ticket named — a
grep for the old posture found two places that *reasoned from* Receive-Only rather
than merely mentioning it.

Grep scope, stated precisely: `grep -rniI "receive.only\|receiveonly\|sendreceive"`
run **repo-wide** (excluding `.git`) returned hits in **`planning/` only — zero
files elsewhere**. So nothing in `ansible/`, `host_vars/`, or `hosts/helium/`
specifies the folder type yet, and the flip is a planning-only edit: there is no
built role to correct.

### What was amended

| File | Change | Why |
|---|---|---|
| `vault-serve/issues/004-syncthing-role.md` | **Title** (`Receive-Only` → `Send-Receive` replica), Goal, the folder-type spec bullet, the `.stfolder` gotcha, **Done when**; SUPERSEDED stop-sign replaced with a ✅ RE-SPECCED banner; new **Consequences of Send-Receive** section | The ticket's substantive body, as this ticket's item 1 required. The stop-sign was removed because it existed only while the body was wrong — leaving it would now block a correct build. |
| `vault-serve/issues/02-syncthing-on-helium.md` | Inline ⚠️ amendment block after the Sync-safety paragraph. `Status: resolved` **left untouched** | 02 is the *resolved decision* that chose Receive Only. Its "the `.stfolder` trap is low-exposure here — nothing edits or reorganizes helium's copy" is now **flatly false**, and it's the sentence a future session would trust. |
| `vault-serve/issues/03-allowlist-enforcement.md` | Inline 📝 note; graduation line's "Receive-Only … role" → "Send-Receive" | 03's *conclusion* survives but its stated *reason* died (see below). |
| `vault-serve/map.md` | 02's decision gist, 004's execution gist, and the coupling note (now records the re-spec as landed) | The map is the index; leaving `Receive Only` in two gists reintroduces the footgun the stop-sign was for. |
| `hermes-helium/issues/08-vault-read-write-surface.md` | New **Inherited from ticket 04** section | The deletion-propagation finding is ground truth 08 depends on; better inherited than re-derived. |

`004` stays **`Status: open`** — it remains vault-serve's execution work (item 4:
*do not build it*). Only this ticket resolved. `005` untouched.

### Item 5 — is Perlite's read path affected? **No. Verified, not assumed.**

The expected answer was right, but for two independent reasons, and one of them
was *not* the one the ticket predicted:

1. **The boundary is the bind-mount surface** (vault-serve `03`), and folder type
   has no bearing on which host paths exist or get mounted `:ro`. As predicted.
2. **The perm mechanism also survives** — this is the part that actually needed
   checking, since Perlite's readability depends on `Ignore Permissions` +
   `UMask=022`, not on the mounts. Syncthing's docs define `ignorePerms` as: files
   are announced with the "no permission bits" flag and *"the remote devices will
   use whatever their default permission setting is when creating the files"* —
   **folder-type independent**. So helium still lands dirs `755` / files `644`
   under Send-Receive, and Perlite's uids 82/101 still read them.

### Three consequences the flip creates (all now written into `004`)

1. **Local deletions propagate upstream.** The docs are explicit that Send-Receive
   sends local changes *including deletions*, where Receive Only does not. This is
   the flip's real cost: a Hermes reorg on helium now destroys files on **krypton
   and the phone** — the exact v0.14 catastrophe, with a wider blast radius.
   Carried into ticket `08`. **The folder now has three read-write peers, not
   two** — krypton *and the phone* were already `Send & Receive` (vault-serve
   `02`), so helium is the third, and a phone-vs-helium conflict can occur with
   krypton uninvolved.
2. **First reconcile is still clean, but now conditionally.** helium's folder must
   be genuinely **empty** before first sync; under Receive Only pre-seeded content
   was quietly kept local, under Send-Receive it is pushed upstream. A provisioning
   hazard that did not previously exist.
3. **`Ignore Permissions` acquired a second job.** It now also prevents helium's
   `UMask=022` modes propagating *outbound*, so a file Hermes rewrites may not keep
   `recipes/`'s `770`/`660` tightness on krypton. Cosmetic drift on a single-user
   laptop — noted with an explicit "do not fix this by disabling Ignore
   Permissions", which would break Perlite.

### Correction to this ticket's own framing

Item 3 said the cross-referencing was already done and only `004`'s body remained.
That undercounted: `02` and `03` both *derived* from the Receive-Only premise, and
`map.md` carried it in two more gists. The urgency claim was sound but the blast
radius was larger than one file.

Note also that `03`'s anti-chmod-per-file argument now stands on **firmer** ground
than when written: it argued Syncthing would *revert* a chmod on a Receive Only
replica; under Send-Receive with `Ignore Permissions` on, permission bits aren't
tracked at all, so a chmod is neither reverted nor propagated — it simply has no
durable effect.

No new tickets, no fog graduated: this was mechanical follow-through, and it
surfaced no new decisions.
