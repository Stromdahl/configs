---
title: Write bin/forge, the house wrapper over the Forgejo API
status: open
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

A `forge` helper script in the same shape as the existing house wrappers for Home
Assistant, UniFi and the keyboard — one tool, verbs on the command line, the API token
read from a plain JSON file in `$HOME` and never appearing in a transcript. Depends on
`issues/056`.

It is the seam everything else in the cutover goes through: the migration script, the
tracker cookbook, the wayfinder dialect and the CI-verdict verb all call it rather than
issuing raw HTTP. Without it, the tracker adapter becomes an HTTP cookbook that puts
inline `curl` with headers into every skill invocation — exactly the pattern the
"extend the wrapper first" rule exists to prevent.

Gitea's own CLI was considered and rejected: an unpackaged Go binary outside the module
system is a worse dependency than a wrapper this repo owns, and the name collides with
an unrelated Debian package.

The verb set is driven by what the tracker actually needs, and three API behaviours
must be absorbed *inside* the wrapper rather than leaked to every caller:

- The dependency relation reads in the inverse direction from how callers think about
  it, so the wrapper should expose "blocks" and "blocked by" in the sensible direction.
- Label filtering is OR, not AND, so narrowing by two label scopes needs client-side
  filtering.
- Issues and pull requests share one number space.

The frontier query has no summary endpoint and is inherently N+1 — list a map's children
by label, drop the assigned ones, then one dependency call each. That is roughly a dozen
calls for a ten-ticket map with nothing to rate-limit against, so it is fine, but it
belongs behind a verb rather than being rebuilt by each caller.

Read-only versus write token scoping is this ticket's call, following the house pattern
of a plain JSON token file. There is no password manager installed.

## Acceptance criteria

- [ ] `forge` exists on `PATH` via the usual module symlink, with `--help` listing its
      verbs.
- [ ] It reads its token from a JSON file in `$HOME` and never echoes it.
- [ ] It can create, read, list, label, assign, close and comment on issues, and create
      and query blocking dependencies in both directions.
- [ ] A label query narrowing on two scopes returns the intersection, not the union.
- [ ] A frontier query for a wayfinder map returns its unblocked, unclaimed children in
      one command.
- [ ] Issue and pull-request number collision cannot silently return the wrong object.
