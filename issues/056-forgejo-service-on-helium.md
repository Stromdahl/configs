---
title: Stand up Forgejo on helium behind the internal Traefik
status: open
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

helium gains a private Forgejo instance, reachable over the mesh and LAN only at a
`*.home.stromdahl.tech` subdomain, serving both the web UI and git over SSH. This is
step 1 of the personal-forge migration ordering and everything else in the epic waits
on it: no repos, no tickets, no CI runner until the forge answers.

The persistence spec is settled by personal-forge ticket 11 and must be honoured
exactly, because two of its details fail silently rather than loudly:

- The image is the LTS rootless line, floating across minors and patches rather than
  exact-pinned. That is deliberately against the host-vars house style — patch
  releases on an LTS line are the security fixes you want arriving without a ticket,
  and the thing that needs human verification is the major, which the LTS tag can
  never cross. It wants a comment saying so. Revisit around May 2027.
- The container runs as the stack's existing service uid/gid rather than the image's
  baked-in 1000 (which collides with `ms`). The data directory must be pre-created and
  chowned to that uid/gid **before the compose service ever starts** — with the wrong
  owner the container dies immediately on first boot.
- The bind mount targets the rootless image's data dir, not `/data`. Getting this
  wrong means backups silently cover nothing.
- Configuration is entirely env-var driven. Forgejo needs **no config bind mount at
  all**; the prototype's `/etc/gitea` mount is vestigial and must not be copied.

Git over SSH uses the officially documented container shape: Forgejo's builtin SSH
server published on an alternate host port, with the advertised port set to match so
the clone URLs the UI and API hand out actually work. helium keeps sshd on 22. The
host-sshd `AuthorizedKeysCommand` shim is rejected — it is official for bare metal
only.

Deploys are scoped-tag only; a full play against helium is non-idempotent.

## Acceptance criteria

- [ ] The Forgejo web UI answers over the mesh and over the LAN at its
      `*.home.stromdahl.tech` name, with a valid certificate and no public exposure.
- [ ] The service runs from the floating LTS rootless tag, declared in host vars with
      a comment explaining why it is not exact-pinned.
- [ ] The container runs as the stack's service uid/gid, and the data directory was
      created and chowned before first start (verifiable by the container coming up
      clean on a from-scratch deploy, not just on a re-deploy).
- [ ] The data bind mount targets the rootless image's data dir, and there is no
      config bind mount.
- [ ] `git clone` over SSH succeeds against a test repo using exactly the SSH URL the
      API advertises, with helium's own sshd still serving port 22.
- [ ] The deploy ran with scoped compose tags only.
