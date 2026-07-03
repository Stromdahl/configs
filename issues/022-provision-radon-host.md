---
title: Provision radon via Ansible — the first edge host (base + docker)
status: done
priority: high
created: 2026-07-02
closed: 2026-07-03
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

- [x] radon (an existing Hostinger VPS, Debian 13) is a member of the `edge` inventory group; a playbook run from krypton over SSH applies cleanly and is idempotent on a second run.
      <!-- edge group: radon @ 2.24.160.184 (ansible_user debian). Run 1: ok=37 changed=17 failed=0; run 2: ok=30 changed=0. -->
- [x] The host's hostname is `radon`; SSH is key-only; root login and password auth are disabled.
      <!-- hostnamectl --static → radon; sshd -T: permitrootlogin no, passwordauthentication no, pubkeyauthentication yes. -->
- [x] ufw is default-deny allowing only 22/80/443; a fail2ban sshd jail is active; unattended security upgrades run.
      <!-- ufw: deny(incoming), only 22/80/443 (v4+v6); fail2ban sshd jail active; unattended-upgrades enabled+active. -->
- [x] Docker engine + compose v2 are installed from the official repo (`docker run hello-world` succeeds; the compose plugin is present).
      <!-- hello-world "working correctly"; `docker compose version` → v5.3.0 (v2-style plugin subcommand). -->
- [~] radon's become password is decrypted from sops at run-time by the admin key and consumed without any age key landing on the box.
      <!-- N/A: the cloud-init `debian` user has PASSWORDLESS sudo (sudo -n true), so Ansible escalates with no become
           password and no secrets.sops.yml was created. The sops-secret demonstrator moves to issue 024 (the
           origin-cert private key becomes radon's first + only at-rest sops secret). The "no age key on the box"
           half is met (verified: none present). -->
- [x] radon holds no per-host age key, deploy key, GitHub key, or repo clone; no new sops creation-rule was added.
      <!-- verified on-box: age key none, repo clone none, id_* keys none. No .sops.yaml rule added. -->
- [x] radon is not a NetBird peer and carries no mesh or storage roles.
      <!-- no /etc/netbird, no wt0 iface; edge play runs base + geerlingguy.docker only. -->

## Resolution (2026-07-03) — provisioned; become-secret deferred to 024

radon (Hostinger VPS, `2.24.160.184`, Debian 13 trixie) is under Ansible as the first
`edge` host: renamed to `radon`, SSH key-only (root + password auth off), ufw
default-deny 22/80/443, fail2ban sshd jail, unattended-upgrades, Docker CE + compose
v2, `debian` in the docker group. Idempotent (2nd run `changed=0`), no mesh, minimal
at-rest secrets (none — see AC5). SSH hardening applied cleanly over the public
internet with no lockout (the connecting `debian` key kept working through the reload).

**AC5 caveat:** the box's `debian` user has passwordless sudo, so there is no become
password to store — this is a divergence from the issue's assumption. No sops secret
was created for radon; the sops-decrypt-on-krypton path is first exercised in
`issues/024`, where the Cloudflare Origin-cert private key becomes radon's only at-rest
secret. `edge_stack` (024) must **not** copy compose_stack's `iptables-persistent`
step (see `issues/028`) or ufw is evicted here too.
