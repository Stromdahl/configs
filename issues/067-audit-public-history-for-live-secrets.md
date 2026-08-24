---
title: Audit the public git history of planning and issues for live secrets
status: done
priority: medium
created: 2026-08-24
closed: 2026-08-24
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

- [x] Every commit touching the planning and issues directories has been swept for
      credential-shaped content, with the method recorded so it can be re-run.
- [x] Each hit is classified as live or dead, with a one-line justification.
- [x] Every live secret found has been rotated (or the owner has explicitly accepted it
      as not worth rotating).
- [x] No secret material was written to a transcript in the course of the audit.

## Resolution

Swept 2026-08-24 at `7d3643f`. **232 commits, 495 blob revisions, 6 hits, 0 live.**
No rotation needed, so criterion 3 is satisfied vacuously. The only 40-character
token in the corpus is upstream Forgejo documentation's own example value, verified
byte-for-byte against the live docs page. Method, hit table and redacted findings
are recorded and re-runnable in the audit asset.

One non-blocking note for the owner: one issue quotes krypton's residential public
IP from a Traefik access log. Dead as a credential and not rotatable; the mitigation
is simply to stop quoting client IPs in future access-log excerpts, not a history
rewrite (which is off the table and would not unpublish it anyway).
