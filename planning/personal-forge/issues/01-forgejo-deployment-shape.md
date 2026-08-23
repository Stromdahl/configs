# Forgejo's deployment shape on helium

Type: research
Status: resolved

## Question

What does a Forgejo instance on helium actually look like, concretely enough that
the later grilling tickets have facts instead of guesses?

Answer these, against primary sources (Forgejo docs, the release notes, the
official container image) — and against **this** box's established patterns:

1. **Image + version.** Current stable Forgejo release, the official container
   image, and its release/LTS cadence.
2. **Database.** SQLite vs PostgreSQL for a single-user instance with ~20 repos.
   What does Forgejo itself recommend, and what does each cost in backup
   complexity? (helium's restic backs up `/data/ssd/appdata` only — whatever is
   chosen must land inside that path.)
3. **Resource footprint.** Idle and under load RAM/CPU, on a 16 GB / 6C6T box
   that is already running Jellyfin, Immich ML, Paperless OCR, and the *arr stack.
4. **Fit with helium's existing pattern.** Can it drop into the existing compose
   stack behind the internal Traefik at a `*.home.stromdahl.tech` subdomain,
   mesh+LAN only, with no public exposure? Note the known gotchas:
   `project_helium_traefik_acme_restart` (first-cert DNS-01 restart; single-file
   bind mounts pin the inode) and the ufw/iptables-persistent hazard
   (`project_ufw_breaks_iptables_persistent` — scoped `--tags compose` deploys only).
5. **SSH access.** Forgejo needs a git-over-SSH path. What are the options
   (container SSH on an alternate port, host SSH with the `forgejo` AUTHORIZED_KEYS
   shim), and which is compatible with helium already running sshd on 22?
6. **Container registry.** Does Forgejo's built-in package registry cover OCI
   images, and can an *anonymous* pull work? (Load-bearing for ticket 08: radon
   currently pulls `ghcr.io/stromdahl/settleup` anonymously and radon is
   **standalone, not on the mesh**.)
7. **Push-mirroring.** Native support, and whether it is per-repo config or global
   — for the deferred GitHub-mirror follow-up.
8. **API surface for repo listing** — enough to answer "what repos do I have?"
   for ticket 10's `forge sync`. Auth model (token scopes).
9. **Anything that would make Gitea the better pick instead.** Forgejo is the
   presumed choice; say so explicitly if the evidence disagrees.

Capture findings as `../assets/01-forgejo-deployment-research.md`.

## Answer

Resolved 2026-08-23. Full findings, with sources and live verification:
[`../assets/01-forgejo-deployment-research.md`](../assets/01-forgejo-deployment-research.md).
**Forgejo stays the pick** — the Gitea counter-case was examined and does not
overturn it. Verdicts by question:

1. **Image + version.** Stable **v16.0.3**; LTS **v15.0.7**. **Pin `:15-rootless`**
   — ~11 months of support vs ~9 weeks for `:16`, turning Forgejo maintenance from
   a quarterly chore into an annual one. Rootless also matches the stack's
   `cap_drop: ALL` house style, but carries two easy-to-miss requirements: the bind
   mount must target **`/var/lib/gitea`**, not `/data`, or the backup silently
   misses; and the host dir must be `chown 1000:1000` **before first start**. On
   Debian UID 1000 is `ms` — a collision to decide, not absorb.
2. **Database.** Docs recommend **SQLite** unambiguously at this size. But this is
   really a *backup-machinery* question, not a DB question — see the decision now
   split out as ticket **11**.
3. **Resource footprint.** Forgejo **publishes no resource requirements at all** —
   treat any sizing number as unsourced. Not a blocker on 16 GB, but it means
   headroom is an observation to make after deploy, not a fact to plan against.
4. **Fit with helium's pattern.** **Yes, and better than assumed** — config is
   entirely env-var driven (`FORGEJO__SECTION__KEY`, plus a `__FILE` variant that
   matches the compose-`secrets:` pattern Traefik already uses), so Forgejo needs
   **no config bind mount at all** and drops into `stack.env.j2` like any other
   service. Caveat: env vars can set a value but cannot *remove* one.
5. **SSH access.** helium **keeps sshd on 22** — no need to give it up. Three
   options enumerated; the sharp constraint is that publishing container SSH on an
   alternate host port **requires setting `SSH_PORT` to match**, or the API hands
   out a clone URL that does not work (folded into ticket 10).
6. **Container registry.** Anonymous OCI pull **works** (verified live) — but the
   registry is **same-origin with the web UI** and Forgejo offers **no way to
   expose only `/v2/`**. This turns ticket 08 from an open question into a
   **contradiction requiring a choice**; four exits enumerated there.
7. **Push-mirroring.** Native, **per-repository** — adequate for the deferred
   GitHub-mirror follow-up.
8. **API for repo listing.** Fully sufficient for `forge sync`, with read-only
   token scoping available.
9. **Gitea instead?** No. The one real point for Gitea is its stronger *intent*
   toward GitHub Actions compatibility; everything else favours Forgejo or is a wash.

**Two hazards in the map's Notes are retired for this service** (not merely
mitigated): the `dynamic.yml` single-file-inode trap does not apply (Forgejo is a
label-based docker router with no config bind mount of its own), and the first-cert
DNS-01 stall was already fixed in the compose template by issue 044's
public-resolver flags. The ufw / iptables-persistent hazard **stands** — deploys
must be `--tags compose`, never a full play.

**One thing this ticket surfaced that was not in its scope, and it is the most
important line in the research:** Forgejo's *documented default runner shape is a
privileged docker-in-docker daemon*, on the box holding the Immich photo archive and
every Paperless document — with Forgejo's own docs warning that the runner "performs
remote code execution. That poses significant security threats for the host and
network that it operates upon." Folded into ticket 04 as a first-class question.
