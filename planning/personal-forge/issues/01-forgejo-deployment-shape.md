# Forgejo's deployment shape on helium

Type: research
Status: claimed

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
