# 0002 — radon on the Ansible control layer (amends ADR-0001)

- **Status:** Accepted (2026-07-03)
- **Amends:** [ADR-0001](0001-public-app-tier-radon.md) — supersedes its *deploy
  mechanism* (git-push pipeline) and *backup* (Hetzner daily snapshots) bullets. The
  **isolation** (no mesh) and **TLS** (static Cloudflare Origin cert, no LE/token)
  decisions of 0001 remain in force.

## Context

ADR-0001 established radon as an isolated, Cloudflare-fronted public VPS and — as a
"reused deploy conventions" bullet — assumed the neon-style **git-push pipeline**
(push the dotfiles repo to a bare repo on the box; a post-receive hook sparse-checks
out the host's tree and runs its `deploy.sh`, which sops-decrypts secrets locally).
It also assumed **Hetzner's built-in daily snapshots** for backups.

Two things changed after 0001 was accepted:

- The fleet began migrating off the custom dotfiles bash modules onto an **Ansible**
  control layer (the helium pilot), with the stated intent of eventually managing the
  whole fleet that way.
- radon was provisioned on a **Hostinger** VPS, not the planned Hetzner CX22, voiding
  the Hetzner-snapshot backup assumption.

Re-examining the deploy mechanism against radon's *raison d'être* — **minimal secret
footprint on the most-exposed box** — showed the git-push model works against that
goal: it places a per-host **age key**, a **bare git repo**, and a full **clone of the
dotfiles repo** on the public box. A compromise of radon would yield all three.

## Decision

Provision and deploy radon via the fleet's **Ansible** control layer, generalized from
the helium pilot into a small **multi-host** setup with radon as the first member of a
new **`edge`** inventory group (helium's `nas` play unchanged) — **not** the git-push
pipeline.

- Secrets stay **sops + age**, but are decrypted **on krypton at run-time** by the
  `community.sops` vars plugin and passed to the connection in memory. radon holds
  **no per-host age key, no deploy key, no GitHub key, and no repo clone**; the sole
  recipient of its encrypted vars is the admin key. Its only at-rest secret is the
  origin-cert private key Traefik must read from disk.
- Ansible connects as the box's cloud-init **`debian`** user (existing SSH key +
  passwordless sudo), so hardening SSH to key-only/no-root carries no bootstrap step
  and no lockout risk.
- The host is a **Hostinger** VPS running Debian 13, replacing the planned Hetzner
  CX22 (a provider swap only; isolation/edge/TLS are unaffected).

## Consequences

- radon's at-rest secret material is strictly smaller than the git-push model would
  leave — realizing ADR-0001's "minimal footprint on the exposed box" goal more
  completely.
- Deploys become **push-from-krypton** (a re-run of the playbook, optionally
  `--limit radon`) rather than self-contained on the box; **krypton becomes a soft
  dependency**. Accepted for a single toy-app host.
- radon is the fleet's **second** Ansible-managed host, establishing the multi-host
  `edge`/`nas` structure and advancing the migration off the dotfiles modules.
  Migrating existing hosts (neon and others) remains explicitly future work.
- The Hetzner-daily-snapshot backup plan is void; backups are **deferred** (radon
  holds nothing critical and settleup's data auto-expires). See `hosts/radon/PRD.md`.
- ADR-0001's isolation and TLS invariants are **unchanged and still binding** —
  including its warning that future work must not reconcile radon onto the NetBird
  mesh or onto Let's-Encrypt DNS-01. This ADR changes *how radon is deployed*, not
  *what radon is exposed to*.

## Alternatives considered

- **Keep the git-push pipeline for radon** — rejected: leaves an age key, a bare
  repo, and a repo clone on the most-exposed box, the exact footprint this tier
  exists to minimize.
- **Keep git-push but strip the on-box age key** (decrypt secrets elsewhere and push
  them in) — rejected: that reinvents the Ansible run-from-krypton model with less
  tooling and no fleet precedent, for no gain.
- **Wait and keep radon on git-push until a fleet-wide Ansible migration** — rejected:
  radon is greenfield with nothing built, so there is no migration cost to building it
  the new way now; doing so also creates the multi-host structure the fleet needs.

## Links

- Durable spec: `hosts/radon/PRD.md`
- Amends: `adr/0001-public-app-tier-radon.md`
- Ansible pilot → multi-host: `ansible/` (helium `nas` play; new `edge` play for radon)
- Backlog: `issues/027` (generalize to `nas`/`edge`) → `issues/022` (provision radon) → `issues/024` (`edge_stack`)
