---
title: Create the projects org and push the 20 curated repos to the forge
status: open
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

A single organisation on the forge holds all twenty curated personal repos, each pushed
with its full history, two of them archived. Depends on `issues/056` and `issues/062`.

This is step 3 of the migration ordering. It is a **one-shot** script, not a
continuously reconciling tool — the reconcile/restore command was deliberately shelved,
and this is unaffected by that.

One organisation, not several and not flat under the user. An org is a path segment in
every clone URL, so a regrouping later rewrites every remote; and the candidate
groupings do not survive scrutiny anyway, because they want to be many-to-many, which is
what topics are for. Topics are deferred until the twenty are actually sitting in a
listing. The org name is settled at creation time — renaming one rewrites clone URLs.

Three things the script must get right, each of which is a measured fact rather than a
preference:

- **The forge name may differ from the local directory name.** Two repos are renamed on
  the forge only, with local directories untouched — one whose own README says the
  directory name is known-wrong, and one plain typo. Anything walking `~/projects` needs
  a two-entry alias map, not an assumption that directory equals repo.
- **Archived repos reject issue creation** — a hard 423, measured live, and one of the
  two repos to be archived carries the second-largest markdown tracker in the set. So
  the ordering is create → import issues → *then* archive. If a repo is already archived
  when its issues arrive, un-archive, import, re-archive.
- **The planning assets get their own git repo in the org**, rather than being uploaded
  as issue attachments. That is the one regression of the tracker migration that has no
  workaround otherwise: attachments are opaque blobs with no diff and no grep, whereas a
  repo keeps the research assets greppable and committed atomically with the resolutions
  that cite them.

Two repos are archived for **supersession**, not staleness — the one archive
justification that does not rot. Stale-but-unsuperseded repos stay active on purpose:
"I haven't touched it since June" is not a decision.

This ticket also picks up a single-copy artifact that has nothing to do with the forge
but must not be lost: one GitHub Pages repo has **no local clone anywhere**, so GitHub
is its only copy. Cloning it is one command and it belongs here.

Storage is a non-issue and must not be re-opened as one — all the histories together are
well under 100 MB; the tens of gigabytes in `~/projects` are build output that never
pushes.

## Acceptance criteria

- [ ] The organisation exists on the forge and holds exactly the twenty curated repos.
- [ ] Every repo's full history is present — a fresh clone of each matches the local
      repo's commit count and tip.
- [ ] The two renamed repos carry their corrected names on the forge, local directories
      are untouched, and the alias map is recorded where the migration script and any
      later tooling can read it.
- [ ] The two superseded repos end archived — but a repo that still carries an
      un-imported markdown tracker is left active until that import happens (one of the
      two does; its fifteen issues are part of the lazy per-repo migration, not of
      `issues/064`), and the create → import → archive ordering is recorded where the
      lazy migration will read it.
- [ ] The planning assets repo exists in the org and holds the research assets.
- [ ] The single-copy Pages repo now has a local clone.
- [ ] The script is re-runnable without duplicating repos or losing state.
