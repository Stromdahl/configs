# Decide the concrete vault read/write surface

Type: grilling
Status: open
Blocked by: 03, 07

## Question

The posture is settled — **Send-Receive, narrow write surface, Hermes' memory out
of the vault** (map Notes). **Now make "narrow" concrete:** exactly which paths may
Hermes write, how are conflicts and git history used as the safety net, and how is
the boundary enforced rather than merely intended?

### Inherited from ticket `04` (verified 2026-07-31 — don't re-derive)

Send-Receive was applied to `vault-serve` 004, and checking the Syncthing docs
turned up the fact this ticket most needs: **local deletions propagate upstream.**
`Send-Receive` distributes local changes *including deletions* to every peer;
`Receive Only` did not. So a Hermes reorg or delete on helium's copy destroys the
same files on **krypton and the phone** — the blast radius of item 2's
"capability, not motive" is the whole cluster, not one replica. Two corollaries:

- The `:ro`-mount option in item 2 is not merely tidy — it is the only thing that
  makes deletion of non-`inbox/` paths *impossible* rather than *discouraged*.
- Item 5's git question is load-bearing for the same reason: an uncommitted write
  that Syncthing has already pushed is gone everywhere at once.

Also settled there: `.sync-conflict-*` files are **accepted** (item 4 is about
noticing them, not preventing them), and `Ignore Permissions` must stay on —
turning it off to tidy modes would break Perlite's read path.

One correction to item 4's framing: the folder has **three** read-write peers, not
two. krypton *and the phone* were already `Send & Receive` (vault-serve `02`), so
helium is the third — meaning a phone-vs-helium conflict can occur with krypton
uninvolved, and whatever notices conflicts cannot assume krypton is one side of them.

### Why this needs its own ticket

"Narrow write surface" is currently a *principle*, and principles do not survive
contact with an autonomous agent. The last one **deleted `.stfolder` while
reorganizing** and silently halted sync for up to an hour, diverging both sides
badly. The redesign (memory in `~/.hermes`, vault as data source) removes the
*motive* for that, but not the *capability*.

### What the answer must settle

1. **The write allowlist.** Concretely which paths. Starting proposal, given board
   ownership is out of scope: **new files in `inbox/` only** — one file per note,
   `<YYYY-MM-DDThhmm>-<source>-<slug>.md`, matching the convention the `note` skill
   and the global cross-session rules already use (one file per note specifically to
   avoid clobbering and Syncthing conflicts — that rationale applies doubly here).
   Then decide what else, if anything, earns write access now vs. later.
2. **Enforcement vs. instruction.** Is the boundary a *prompt* (Hermes is told), a
   *mount* (only `inbox/` is writable, the rest `:ro` — the bind-mount pattern
   vault-serve chose as its actual boundary), or *both*? Note vault-serve ticket
   `03` concluded the mount surface **alone** was the real boundary and a
   configured denylist was explicitly *not* trusted. Same reasoning applies:
   prompt-level restraint is not a boundary.
3. **The read surface.** Full-egress is accepted, so this is about *utility and
   cost*, not secrecy: sending the entire vault on every turn is expensive and
   noisy. Decide how Hermes finds what it needs — full read + retrieval, or a
   curated set of always-loaded entry points. The vault's own `AGENTS.md` is
   deliberately structured for this ("a thin always-on core + routers", "load a
   topic's own doc only when the task needs it"), which is a ready-made answer worth
   reusing rather than reinventing.
4. **Conflict handling.** Two writers on `personal-vault` will produce
   `.sync-conflict-*` files. Who notices, and how? (Ticket `05` owns the alerting
   mechanism; this ticket owns *whether it's a condition worth alerting on*.) Also:
   does Hermes ever *resolve* conflicts, or only report them? Recommended: report
   only.
5. **git as the safety net — made real.** `~/vault` is a git repo, but an
   uncommitted agent write is not revertable, and Syncthing will happily sync
   `.git/` into a race between peers. Settle: who commits, when, and whether `.git/`
   is excluded from Syncthing via `.stignore`. This is the difference between "git
   is the safety net" and "there happens to be a git repo here".
6. **The `.stfolder` marker guard.** Carry the prior-art unit forward (ticket `02`),
   updated for `personal-vault` on helium. Cheap insurance; should never fire.
7. **`~/vault/AGENTS.md` must be rewritten.** It currently says the vault is synced
   to `titan` and "worked on by … Hermes agent (titan)" — stale on both counts, and
   other agent sessions read it as ground truth. This ticket produces the content;
   the map lists it as fog until then.
