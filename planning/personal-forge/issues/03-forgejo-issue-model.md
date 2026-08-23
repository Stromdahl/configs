# Forgejo's issue model — can it carry the tracker *and* wayfinder maps?

Type: research
Status: open

## Question

The tracker decision is made (Forgejo Issues win; taskmaster loses). What is not
established is whether Forgejo's issue model can actually express what the current
markdown tracker and the agent skills rely on.

Establish, from Forgejo's docs and API reference for the current stable release:

1. **Blocking dependencies.** Does Forgejo have native issue dependencies
   ("blocked by" / "blocks"), across repos as well as within one? **Wayfinder
   requires this** — it is how the frontier is computed and rendered.
2. **Parent/child (sub-issues).** Does Forgejo support a parent issue with child
   issues? **Wayfinder's map is a parent issue and its tickets are child issues.**
   If this is missing, say what the closest expressible substitute is.
3. **Cross-repo views.** Is there a single view of open issues across every repo
   (the thing the in-repo markdown tracker explicitly cannot do, per
   `~/projects/issue-tracker/README.md`)? Global issue search, filters, and
   whether **kanban boards / projects** exist and are per-repo or org-wide.
4. **The API surface an agent adapter needs** — create/read/update/close an issue,
   labels, comments, assignees, dependencies, and *listing* by state+label+repo.
   Token scopes required. Rate limits, if any.
5. **Attachments** — can a wayfinder *asset* (a research markdown file) be attached
   to an issue, or does it need to stay in-repo and be linked?

Then answer the design question this feeds: **what would
`issue-tracker-forgejo.md` have to say?** The existing adapters live at
`~/.claude/skills/setup-matt-pocock-skills/issue-tracker-{github,gitlab,local}.md`
— there is **no Forgejo one**, and every skill (`/wayfinder`, `/to-tickets`,
`/triage`, `/implement`, `/pickup`) resolves tickets through that doc. Read
`issue-tracker-github.md` and `issue-tracker-local.md` and report which sections
map cleanly, which need a workaround, and which cannot be expressed at all.
Include the **"Wayfinding operations"** section specifically.

Do **not** write the adapter — that is execution. Report what it would contain.

Capture findings as `../assets/03-forgejo-issue-model-research.md`.
