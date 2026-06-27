---
title: Ansible foundation — bring helium to a hardened, docker-ready host from krypton
status: open
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
  a host playbook, role layout).
- **Secrets stay sops + age**, consumed by Ansible via the community.sops
  integration; krypton decrypts at run-time and templates rendered values onto the
  box, which never holds the age key.
- A base/hardening role covering ssh/sshd, firewall, fail2ban, and unattended
  upgrades, plus a docker role (engine + compose plugin).

The deliverable is one capability: run the playbook from krypton → helium comes up
hardened and able to run containers.

Depends on `issues/001` (needs a booted, SSH-reachable base OS).

## Acceptance criteria

- [ ] `ansible-playbook` run from krypton over SSH applies cleanly and is
      idempotent on a second run.
- [ ] A sops-encrypted secret is decrypted by Ansible at run-time and rendered onto
      the host without the age key ever landing on the box.
- [ ] SSH is hardened, the firewall is active, fail2ban and unattended-upgrades are
      running.
- [ ] `docker run hello-world` succeeds; the compose plugin is present.
- [ ] No GitHub/deploy key exists on the box.
