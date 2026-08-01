# Hand the vault-undo riders to vault-serve 004

Type: task
Status: resolved
Blocked by: 03

## Question

Apply ticket `03`'s **undo decision** to vault-serve's still-open Syncthing ticket,
and cross-reference both maps so no session builds the replica without it.

Nothing to decide — the decisions were taken in `03` (see its Answer). This is the
mechanical follow-through, and it is the same shape as
[ticket 04](04-respec-vault-serve-004-send-receive.md): a decision in *this* map that
changes an open, takeable ticket in *another* one.

**It is urgent relative to the rest of this map** for the same reason `04` was:
`planning/vault-serve/issues/004-syncthing-role.md` is open execution work, and a
session that grabs it today will build a replica with **no undo at all**.

## Why this exists

Ticket `03` set out to give Hermes a git-authored audit trail in the vault. That
died on contact with three facts, and what replaced it lands in vault-serve's
territory rather than this map's:

- `~/vault/.stignore` excludes `.git` — helium's replica has no repo, so Hermes
  cannot commit into the synced tree.
- `.gitignore` deliberately untracks finance *data*, so git never covered the
  highest-value area anyway.
- **Syncthing file versioning is off on every folder on krypton** (`config.xml`:
  `versioning=''` for `personal-vault`, `Notes`, and the camera folder).

Net: with Send-Receive live (ticket `04`) and Hermes writing, a bad write or delete
to an untracked path propagates to krypton *and* the phone within seconds with **no
point-in-time copy anywhere** — `/data/ssd/vault` is outside restic too
(`restic_backup_source` is `/data/ssd/appdata` only). The owner declined git for the
vault; versioning is the replacement, and it covers strictly more (finance data,
new files, deletions).

## The change list for vault-serve `004`

1. **Enable staggered file versioning on krypton's `personal-vault` folder**,
   `maxAge` 365 days. **krypton only** — the reasoning matters, so carry it across
   rather than restating the conclusion: Syncthing versioning fires when *Syncthing*
   replaces or deletes a file, i.e. on **incoming** changes. Hermes' own writes on
   helium are *sent*, not versioned, so versioning on helium would archive nothing
   about them; it would only protect helium from krypton's edits, and would grow a
   `.stversions` tree on the SSD outside restic. krypton is the receiving side for
   everything Hermes does and holds the authoritative copy.
   - Staggered, not Trash Can: Trash Can keeps only the newest version, and the
     realistic failure is an agent misfiring unnoticed for days.
   - Note `.stversions` is already in both `.gitignore` and `.stignore`, so enabling
     it needs no ignore-file change on krypton.
2. **Put `.git` in helium's Syncthing ignore patterns** — belt-and-braces, and cheap.
   Ignore lists are **per-device, not synced**, so krypton's exclusion does not come
   along with the folder. Today helium has no `.git` to send (the audit repo was
   declined), so this is not load-bearing; but under **Send-Receive** anything that
   ever creates one there would propagate it upstream and recreate exactly the
   `.sync-conflict` churn krypton's exclusion exists to prevent.
3. **Cross-link**: note in `004` that its versioning setting is the vault's *only*
   undo now that git is ruled out, so it is not an optional nicety, and link back to
   ticket `03`'s Answer for the reasoning.

## Done when

- `004` carries all three items and no longer implies the replica is safe without them.
- This map's Decisions-so-far records the handoff.
- No behaviour is changed on either box — this is a planning-artifact edit only
  (`004` stays open execution work, as `04` left it).

## Answer

Applied 2026-07-31. `004` now carries all three items in a new **Vault undo
(required — the only undo there is)** section, plus a second ⚠️ banner at the top so
a session that grabs the ticket meets the gap before the spec. `004` stays open
execution work. **No behaviour changed on krypton or helium** — versioning is still
off; this ticket only specified it.

**Every claim was re-verified rather than propagated on trust**, and doing so turned
up one defect and two corrections that the hand-off would otherwise have carried
into a build.

### The defect: `maxAge` is in seconds, not days

This ticket said *"`maxAge` 365 days"*. That is the **GUI's** unit; the GUI converts
before writing. A role templating `config.xml` — which is how this will actually be
built — must write **`31536000`**. Writing `365` there yields **six minutes** of
version history on a folder whose stated purpose is surviving *"an agent misfiring
unnoticed for days"*.

Note what that failure would have looked like: versioning enabled, `.stversions/`
present and non-empty, a GUI showing "Staggered File Versioning" — and no recoverable
history at the moment it was needed. A plausible-looking half-success, indistinguishable
from working until the disaster. That is the map's own enemy class, reached via its
own undo mechanism, so `004`'s **Done when** now demands the seconds value *and* a
deliberate round-trip test (edit on helium → confirm the prior version lands in
krypton's `.stversions/`), on hermes-helium `03`'s argument that an unrestored backup
is not a backup.

### The two claims that were right, now sourced

Both are load-bearing for the *krypton-only* recommendation, which is the part most
likely to be second-guessed by whoever builds it — so `004` now quotes the docs
inline rather than asserting:

- **Versioning fires only on incoming changes.** *"Versioning applies to changes
  received from other devices… If Alice changes a file locally on her own computer
  Syncthing will not and can not archive the old version."* This is exactly why
  helium is the wrong side: Hermes writes *locally* there.
- **Ignore patterns are per-device.** *"The `.stignore` file itself will never be
  synced to other devices."* So krypton's `.git` exclusion genuinely does not travel,
  and item 2 is not redundant.

Verified locally on krypton, 2026-07-31: all three `<versioning>` blocks in
`config.xml` (`personal-vault`, `Notes`, camera) contain **no `<type>` element** —
which is how "off" is spelled — confirming this ticket's `versioning=''` reading;
`.stversions` is present in both `~/vault/.gitignore` and `~/vault/.stignore`; and
`~/vault` is **53 MB / 1158 files**, so a year of staggered history costs nothing.

### Scope seam surfaced (not resolved — deliberately)

**Item 1 is a change on krypton, which is outside helium's ansible play.** `004` is a
helium role ticket, so its owner cannot straightforwardly execute the one item that
actually creates the undo. Rather than invent a home for it, `004` records the seam
and assigns *responsibility* (the replica is unsafe without it) while leaving the
*mechanism* — manual GUI change, krypton-side dotfiles change, or its own ticket — to
the builder. Flagged here because it is the item most likely to be quietly dropped.

### Two stale claims corrected in `004` while there

`004` asserted twice that *"git is the safety net"* / *"`~/vault` is a git repo… the
real undo"* — inherited from ticket `04`, before `03` falsified it. Both are struck
in place (visibly, not silently deleted, so a reader who remembers the old reasoning
sees it was retracted rather than lost) and redirected to the new section. One
addition of my own: a `.sync-conflict-*` copy is a **new file**, not a replacement,
so versioning does not archive it — worth stating next to the conflict paragraph so
nobody reads versioning as conflict machinery.
