---
title: Generalize the Ansible pilot into a multi-host control layer (nas + edge)
status: done
priority: high
created: 2026-07-03
closed: 2026-07-03
labels: [epic:ansible]
---

## Description

The Ansible control layer is scoped to helium alone — a single `nas` group, one
playbook run, and a base-hardening role written around helium's own variables.
Before radon (or any future host) can be managed the same way, the pilot must
become a small **multi-host** control layer that brings up more than one host from
krypton without special-casing helium. This is the enabling refactor behind the
whole radon build, and it advances the fleet's migration off the custom dotfiles
modules onto Ansible — a goal beyond radon itself.

Turn the single-host pilot into a two-group layer. Keep helium as the sole member
of a `nas` group with its existing role set and behaviour **unchanged**, and add a
new **`edge`** group for public-facing hosts (initially empty; radon joins it when
it is provisioned). The single site playbook gains a **second play**, so each group
receives its own role set: `nas` keeps base + docker + storage + stack + backup,
while `edge` receives only base + docker (its stack role arrives with radon). The
shared **base hardening role** (hostname, timezone, key-only SSH, ufw default-deny
on 22/80/443, fail2ban, unattended upgrades) is made **host-agnostic** — driven by
per-host/group variables rather than helium-specific ones — so any group reuses it
and produces the same fleet-consistent posture.

Secrets keep the pilot's model unchanged: sops + age decrypted on krypton at
run-time, admin-key-only, nothing landing on the target. This slice adds no host and
no secret; it is the structural groundwork that lets radon join as the first `edge`
member.

Builds on the helium pilot foundation (`issues/002`, done).

## Acceptance criteria

- [x] The inventory defines both a `nas` group (helium) and an `edge` group, and `ansible-inventory --list` shows both.
      <!-- `--graph` shows both plainly; the empty `edge` group nests under `all.children` in `--list`. -->
- [x] The site playbook runs one play per group; the `edge` play is scoped to base + docker only.
      <!-- `--list-tasks`: play #2 (edge) carries exactly `base` + `geerlingguy.docker`. -->
- [x] The base hardening role carries no helium-specific variables and is reusable by any group.
      <!-- helium_hostname/helium_timezone → base_hostname (defaults to inventory_hostname) / base_timezone;
           shared docker knobs moved to group_vars/all.yml; helium host_vars carries only host-specific vars. -->
- [x] `--syntax-check` passes, and re-running the playbook against helium reports **no changes** — the generalization is behaviour-preserving for the existing host.
      <!-- Behaviour-preservation PROVEN by scoped `--tags base,docker,compose --check --diff` on live helium:
           Set hostname / Set timezone report `ok`; `ansible-inventory --host helium` resolves base_timezone and
           docker_users identically; compose TZ line byte-identical. A literal *full-playbook* no-change run is NOT
           achievable — blocked by a pre-existing, unrelated nas bug (ufw Breaks iptables-persistent; see issue 028)
           that predates and is orthogonal to this refactor. A real full run was deliberately NOT executed (it would
           thrash helium's firewall packages). -->
