# Tracker cutover: what moves into Forgejo Issues, and what stays markdown?

Type: grilling
Status: open
Blocked by: 03, 05

## Question

The decision is made — Forgejo Issues become the tracker. This ticket decides the
*cutover*, with the prototype in front of the owner and ticket 03's findings in
hand.

What exists today, and would be affected:
- **56 files in `~/.dotfiles/issues/`** — the live homelab tracker, with YAML
  frontmatter (`status`/`priority`/`labels`, `epic:<slug>` for epics) and a
  "files never move, `status` is the source of truth" rule.
- **Three live wayfinder maps** — `planning/hermes-helium/`,
  `planning/vault-serve/`, and this one — plus `~/projects/specs/.scratch/work-tracking/`
  and `~/yggio/master/.scratch/translator-tags/` (both **work**, and out of scope).
- **Per-project trackers** — `lumin/.scratch/`, `taskmaster/tickets/`.
- **The `issue-tracker` spec itself** (`~/projects/issue-tracker`, v0.0.2), which
  other repos pin to.

Decide:

1. **Migrate or line-in-the-sand?** Do the 56 existing issues move into Forgejo,
   or does only *new* work land there while the markdown history stays put? A
   partial answer is legitimate (e.g. open issues migrate, closed ones stay).
2. **Do wayfinder maps move?** They are the hardest case: they need parent/child
   and blocking edges (ticket 03 says whether Forgejo has them), and their bodies
   are long, cross-linked, and amended in place — which git diffs beautifully and
   an issue tracker does not. It is entirely defensible for **maps to stay in
   `planning/` while ordinary issues move**. Reach a deliberate answer, not a
   default.
3. **What happens to the `issue-tracker` spec?** Deprecated, or does it live on as
   the convention for repos that stay markdown-tracked?
4. **The agent adapter.** Ticket 03 reports what `issue-tracker-forgejo.md` would
   need to say. Confirm it gets written, and which skills are expected to use it.
5. **React to the prototype** (ticket 05). This is the moment to find out whether
   the UI is genuinely one the owner opens — *before* the migration. If it is not,
   that is a real finding and the tracker decision should be revisited here rather
   than defended.

Also decide taskmaster's fate if the conversation naturally reaches it; otherwise
leave it in the fog.
