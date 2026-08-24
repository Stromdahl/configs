---
title: Audit the public git history of planning and issues for live secrets
status: in-progress
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge, needs-human]
---

## Description

This repository is **public on GitHub and is a permanent carve-out** — it is not moving
to the forge, because the bootstrap path and the SSH-key fetch must work before the mesh
exists. Eighty-seven commits touch the planning and issues directories, and everything
they ever contained stays readable **whether or not the files are deleted**. Deletion
cannot unpublish. No blockers — this is independent of the rest of the epic and can run
at any time.

So this is a plain security chore over existing public history, not a migration task and
not a decision. It was originally parked as conditional on the tracker cutover; that
condition is gone.

The only action it can produce is **rotate anything that turns out to be a live
secret** — hence `needs-human`. A history rewrite is not on the table: it would break
every clone, and it would not unpublish anything already fetched or indexed.

Scope the search to what those commits actually carried: tokens, keys, hostnames and
internal addresses, and any credential quoted inline in a resolution or a measurement
transcript. A prior audit of a different repo's history measured this kind of sweep down
to a dozen credential-mentioning files, so the expected finding is small — but "expected
small" is the reason to check it once and close it, not a reason to skip it.

Do not decrypt any encrypted file to standard output while doing this.

## Acceptance criteria

- [ ] Every commit touching the planning and issues directories has been swept for
      credential-shaped content, with the method recorded so it can be re-run.
- [ ] Each hit is classified as live or dead, with a one-line justification.
- [ ] Every live secret found has been rotated (or the owner has explicitly accepted it
      as not worth rotating).
- [ ] No secret material was written to a transcript in the course of the audit.
