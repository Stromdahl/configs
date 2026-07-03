---
title: Provision radon via Ansible — the first edge host (base + docker)
status: open
priority: high
created: 2026-07-02
closed: null
labels: [epic:public-apps, needs-human]
---

## Description

Bring radon under the fleet's **Ansible** control layer as a hardened, deliberately
**standalone public box** — the runtime the app stack later deploys onto. radon is
an existing **Hostinger VPS** running **Debian 13**, continuing the noble-gas
naming; add it to the new **`edge`** inventory group as its first member and bring
it to a fleet-consistent posture with a playbook run pushed **from krypton over
SSH**.

Ansible connects as the box's cloud-init **`debian`** admin user, which already
carries an SSH key and passwordless sudo — so hardening SSH to key-only/no-root
introduces no bootstrap step and no lockout risk. radon receives the **`edge`** role
set: the shared **base** hardening role (rename the host to `radon`, timezone,
key-only SSH with root login and password auth disabled, ufw default-deny allowing
only 22/80/443, a fail2ban sshd jail, unattended security upgrades) and
**docker-ce + compose v2** from the official repo. It gets **none** of helium's
storage or mesh roles.

Secrets follow the pilot unchanged: sops + age, decrypted **on krypton at run-time**
and passed to the connection in memory. radon holds **no per-host age key, no deploy
key, no GitHub key, and no repo clone** — the sole recipient of its encrypted vars is
the admin key, matching the existing host-vars creation rule, so **no new sops rule**
is introduced. The become password is its demonstrator secret. Backups are
**deferred** — radon holds nothing critical and settleup's data auto-expires; the
earlier whole-disk-snapshot plan is void (per ADR-0002).

Crucially, radon does **not** join the NetBird mesh — a compromised public box must
have no path back into the home fleet, which is the entire reason this workload lives
on a VPS rather than on helium. Admin access is key-only SSH over the public
internet.

Depends on `issues/027` (the multi-host `nas`/`edge` structure and host-agnostic base
role). Can otherwise proceed in parallel with `issues/021` and `issues/023`.

## Acceptance criteria

- [ ] radon (an existing Hostinger VPS, Debian 13) is a member of the `edge` inventory group; a playbook run from krypton over SSH applies cleanly and is idempotent on a second run.
- [ ] The host's hostname is `radon`; SSH is key-only; root login and password auth are disabled.
- [ ] ufw is default-deny allowing only 22/80/443; a fail2ban sshd jail is active; unattended security upgrades run.
- [ ] Docker engine + compose v2 are installed from the official repo (`docker run hello-world` succeeds; the compose plugin is present).
- [ ] radon's become password is decrypted from sops at run-time by the admin key and consumed without any age key landing on the box.
- [ ] radon holds no per-host age key, deploy key, GitHub key, or repo clone; no new sops creation-rule was added.
- [ ] radon is not a NetBird peer and carries no mesh or storage roles.
