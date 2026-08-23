# Throwaway Forgejo loaded with real repos and real issues

Type: prototype
Status: resolved
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

## Amendment (2026-08-23, from ticket 03) — build this shape

Ticket 03 settled what to build for the wayfinder specimen: **Forgejo has no
sub-issues at all**, so build the substitute and let the owner react to *that*:

- map issue labelled **`wayfinder:map`**
- children labelled **`wayfinder:effort:vault-serve`** + **`wayfinder:<type>`**
- **`Part of #<map>`** as the first line of each child body
- a **markdown task list in the map body** for order and legibility (note it is
  inert — closing a child does not tick its box; do not fake this)
- at least one **real blocking edge** via
  `POST /repos/{o}/{r}/issues/{child}/dependencies` — this part *is* native, and it
  is the thing worth seeing rendered in the UI

Also, and this is the sharpest thing to put in front of the owner: **kanban boards
cannot be automated** (no `/projects` API at all). Build a board by hand anyway and
put the issues on it — because the board is very likely the "UI I actually open"
that justified the whole tracker decision, and the owner needs to see it knowing
that no agent will ever be able to touch it.

## Amendment (2026-08-23, from ticket 03) — two additions to the shape above

**1. Build it under an organisation, not a user.** Ticket 03 §3 found the web
dashboard's label picker is **only populated in an org context**
(`GetLabelsByOrgID`, `routers/web/user/home.go:593`) — on a personal dashboard you
can pass label IDs by URL but there is **no selector**, and there is no milestone
filter either. Standing the throwaway up under a bare user account and concluding
"the cross-project view is weak" would be a **false negative caused by an unmade
config choice**. Ticket [06](06-repo-curation.md) has since settled a single org
named `projects`, so mirror that: create the org, put the repos and the labels under
it, and show the owner the **org** dashboard. Cheap bonus if it costs nothing: show
the user dashboard beside it, which is the evidence that 06's org call was right.

**2. Free win — tag-verify on v15 while you are in there.** 03's dependency findings
were verified against codeberg's **`16.0-dev`**; ticket 01 pinned **`:15`**. This
throwaway will be a v15 instance, so it is the cheap place to close the one
inferred-not-verified gap in 03. Confirm and record: that
`POST /repos/{o}/{r}/issues/{n}/dependencies` accepts `{owner,repo,index}`; that
`internal_tracker.enable_issue_dependencies` is readable *and* settable on
`PATCH /repos/{o}/{r}`; that closing a blocked issue really returns **412
`DependenciesLeft`**; and that `type=issues` filters PRs out of
`/repos/issues/search`.

## Answer

Resolved 2026-08-23. **The instance exists and is running.** Notes, imports, and
the API corrections: [`../assets/05-prototype-notes.md`](../assets/05-prototype-notes.md).

- **URL:** <http://localhost:3210/> · org listing <http://localhost:3210/projects>
  · login `ms` / `protoforge123`
- **Version:** Forgejo **15.0.7**, image `codeberg.org/forgejo/forgejo:15-rootless`
  — the exact pin ticket 01 chose.
- **Lives in** the session scratchpad at `…/scratchpad/forgejo-prototype/`
  (`docker compose start` / `stop` to resume/pause, keeping data;
  `down -v && rm -rf data config` to destroy). Scratchpad path — **good for this
  week, not forever.**
- **Loaded with:** 4 real repos in an org named `projects` (per ticket 06,
  including `oppen` archived and `diy-speekers`→`diy-speakers` renamed), **14 real
  issues** from `~/.dotfiles/issues/`, the **vault-serve map reproduced as `#16`**
  with children `#17`–`#21` in the substitute shape and a **real blocking edge**
  (`#21` blocks the map), and a **hand-built org-level kanban board** with 20 cards.

**Four things it found that the API research got wrong or didn't know:**

1. **`exclusive: true` is a silent no-op on `:`-separated labels.** `/` is the
   scope separator; `:` is not — and the API accepts and *stores* `exclusive: true`
   on a colon label it will never enforce, with no warning. This contradicts the
   research's claim that exclusive labels are an improvement over the other
   adapters. The `wayfinder:map` / `wayfinder:effort:<slug>` convention works as
   specified but **cannot have exclusivity**; getting it means renaming to
   `wayfinder/type/research`. **Ticket 07 should make that naming choice
   knowingly, not discover it at migration time.** Both renderings are on the
   instance side by side (`#2`, `#4`, `#10`) to be looked at.
2. **Same-named org and repo labels both attach, silently** — one `POST` resolved
   `epic:services` to two labels and attached both, duplicating the pill and
   double-counting every `labels=` query. Adapter rule: pick one level and never
   define a name at both, or resolve name→ID yourself.
3. **Boards are org-scoped** — nobody had checked. An org board is a first-class
   tab; a *user*-level board is **not offered** for issues in an org-owned repo.
   So **ticket 06's "one org hedges ticket 03" reasoning was correct and
   load-bearing** — flat-under-user would have made a cross-project board
   impossible.
4. `internal_tracker.enable_issue_dependencies` was **`true` by default on every
   repo**, so no pre-flight `PATCH` was needed in practice.

**What mapped awkwardly (all input to ticket 07):** `~/.dotfiles/issues/` has
**five** statuses in the wild (`open`/`in-progress`/`done` per its README, plus
`closed` and `dropped`), and Forgejo has two — so `dropped` became *closed + a
`status:dropped` label*, surviving by convention with nothing enforcing it.
**`in-progress` has no home at all**: Forgejo's only in-flight signal is an
assignee, and "assigned to `ms`" meaning "in progress" works on a single-user
forge by coincidence, not by model. And **`Part of #16` renders as an ordinary
issue link** — the map's children are legible only because of the label query, so
the body line buys nothing machine-readable, exactly as ticket 03 predicted.
