---
title: Provision the radon VPS — base hardening + git-push deploy pipeline
status: open
priority: high
created: 2026-07-02
closed: null
labels: [epic:public-apps, needs-human]
---

## Description

Bring radon into existence and under dotfiles management as a hardened, **standalone
public box** — the runtime the app stack later deploys onto. Create the **Hetzner
CX22** instance (Helsinki, Debian 13), then provision it with the fleet's *server*
module set so its posture matches everyone else while it stays deliberately isolated
from the home network.

The module set mirrors neon's server hosts: base, hardened **key-only SSH** (root
login and password auth off) with the fleet's authorized keys, **ufw** default-deny
allowing only 22/80/443, a **fail2ban** sshd jail, Docker from the official repo,
then the **git-push deploy trio** (deploy-user, sops, bare-git-repo) so pushing the
dotfiles repo to radon sparse-checks-out this host's stack tree and runs its deploy
script. Enable **Hetzner's built-in daily whole-disk backups**.

Crucially, radon does **not** join the NetBird mesh and gets **no** storage/NAS
modules — a compromised public box must have no path into the home fleet, which is
the entire reason this workload lives on a VPS rather than on helium. Admin access
is key-only SSH over the public internet.

This can proceed in parallel with `issues/021`; it produces radon's per-host age
recipient that `issues/024` needs.

## Acceptance criteria

- [ ] A Hetzner CX22 instance named `radon` runs Debian 13 in Helsinki.
- [ ] SSH is key-only with the fleet's authorized keys; root login and password auth are disabled.
- [ ] ufw is default-deny allowing only 22/80/443; a fail2ban sshd jail is active.
- [ ] Docker engine + compose v2 are installed from the official repo.
- [ ] Pushing the dotfiles repo to radon checks out only this host's stack tree and runs its deploy script end-to-end (verifiable with an empty/placeholder stack).
- [ ] Hetzner daily whole-disk backups are enabled.
- [ ] radon is not a NetBird peer and carries no mesh or storage modules.
