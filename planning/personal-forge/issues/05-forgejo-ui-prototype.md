# Throwaway Forgejo loaded with real repos and real issues

Type: prototype
Status: open
Blocked by: 03

## Question

The tracker decision rests on one bet, in the owner's words: **"A, I want a UI I
actually open."** That is a claim about a UI nobody has looked at yet. Test it
cheaply, before it becomes an ansible role and a migration.

Stand up a **throwaway** Forgejo — locally on krypton in Docker is fine and
preferred; this is not a deploy and must not touch helium's stack — and load it
with *real* material, not lorem ipsum:

- **3–4 real repos** pushed into it, chosen to span the range: `lumin` (the serious
  one, with an existing `.scratch` tracker), `taskmaster` (has `tickets/`), and one
  stale hobby repo (`diy-speekers` or `freecad-prints`).
- **Real issues.** Import a representative slice of `~/.dotfiles/issues/` (they
  have YAML frontmatter with `status`/`priority`/`labels` — map those onto Forgejo
  labels and state). A dozen is plenty; the point is realistic density.
- **A real wayfinder shape.** Reproduce one existing map as a parent issue with
  child tickets and a blocking edge — `planning/vault-serve/` is a good specimen.
  If ticket 03 found sub-issues or dependencies missing, build the closest
  substitute so the owner can react to *that* instead.
- **A board.** If Forgejo has projects/kanban, put the issues on one.

Deliver: the running instance (with the URL and how to start/stop it) plus a short
`../assets/05-prototype-notes.md` recording what was imported, what mapped
awkwardly, and any screenshots worth keeping.

**This ticket resolves once the instance exists and is linked.** The owner's
reaction to it is not this ticket's job — that happens in ticket 07.
