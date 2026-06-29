---
title: Ansible foundation — bring helium to a hardened, docker-ready host from krypton
status: in-progress
priority: high
created: 2026-06-27
closed: null
labels: [epic:bootstrap]
---

## Description

Establish the Ansible control layer (this box is the pilot — the rest of the
fleet stays on the custom dotfiles modules) and use it to bring the
freshly-installed host to a hardened, docker-ready state with a single playbook
run pushed **from krypton over SSH**. The box holds no GitHub key and no deploy
key.

Scope:
- Scaffold the Ansible tree inside the dotfiles repo (inventory entry for helium,
  a host playbook, role layout), mirroring the archived homelab-stack layout.
- **Secrets stay sops + age**, decrypted on krypton via the community.sops
  integration — the box never holds an age key, and (unlike the other servers) has
  no per-host key, so only the admin key can decrypt its secrets. Ansible-consumed
  values are loaded as variables and consumed at run-time without landing on the
  box; the sudo/become password is the foundation's demonstrator secret and also
  makes playbook runs non-interactive. (Rendering a secret to disk — the Docker
  compose env — arrives with the service stack, not here.)
- A base/hardening role that **reproduces the fleet's dotfiles hardening config**
  (key-only SSH / no root login, ufw default-deny, a fail2ban sshd jail,
  unattended security upgrades) so helium stays consistent with the rest of the
  fleet, plus hostname/timezone. A docker role installing **docker-ce** (engine +
  compose v2) from the official repo via geerlingguy.docker.

The deliverable is one capability: run the playbook from krypton → helium comes up
hardened and able to run containers.

Depends on `issues/001` (a booted, SSH-reachable base OS — now done). Assumes a
**pinned DHCP reservation** for helium so the inventory address is stable (a
one-time manual router step).

## Acceptance criteria

- [ ] `ansible-playbook` run from krypton over SSH applies cleanly and is
      idempotent on a second run.
- [ ] A sops-encrypted secret is decrypted by Ansible at run-time and **consumed**
      without the age key ever landing on the box (the sudo/become password serves
      as this secret).
- [ ] SSH is hardened, the firewall is active, fail2ban and unattended-upgrades are
      running.
- [ ] `docker run hello-world` succeeds; the compose plugin is present.
- [ ] No GitHub/deploy key exists on the box.
