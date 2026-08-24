---
title: Provision rootless-Podman prerequisites and the forgejo-runner user on helium
status: open
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

helium gains everything rootless Podman needs to run CI job containers as a dedicated
unprivileged user, and a user-scoped podman socket for that user that survives logout.
None of it is present today — verified: podman, the uid-mapping helpers, the userspace
network helper and the userspace overlay driver are all absent, and only `ms` has a
subuid/subgid range at all.

This exists because Forgejo's *documented default* runner shape is a privileged
docker-in-docker daemon, and its own docs warn the runner "performs remote code
execution… significant security threats for the host". That is unacceptable on the box
holding the photo archive and every scanned document, so the runner is confined to an
unprivileged user with rootless Podman instead.

What the slice delivers:

- The four missing packages installed.
- A dedicated `forgejo-runner` service user with a subuid/subgid range that does not
  collide with the existing one for `ms`.
- Lingering enabled for that user, so its user manager runs without a login session.
- The podman socket as a `systemd --user` unit for that user, which is the pattern
  Forgejo itself documents for rootless Podman.

Copy the in-house `systemd --user` pattern the syncthing role already uses — look the
uid up rather than hardcoding it, enable lingering **before** touching any user unit,
and drive systemd in user scope with the runtime dir set. Getting the ordering wrong
produces a confusing failure rather than a clear one.

Accepted, and worth knowing before debugging anything here: a `systemd --user` unit is
invisible to a plain `systemctl status` from a root shell. Inspecting it needs a shell
as the runner user with its runtime dir set.

## Acceptance criteria

- [ ] All four rootless-Podman prerequisites are installed on helium.
- [ ] A `forgejo-runner` user exists with a subuid/subgid range that does not overlap
      the existing range for `ms`.
- [ ] Lingering is enabled for that user and survives a reboot.
- [ ] The podman socket is an enabled `systemd --user` unit for that user, and a
      rootless `podman run` of a trivial image succeeds as that user after a reboot
      with nobody logged in.
- [ ] The uid is looked up at run time, never hardcoded, and the play is idempotent on
      a second run.
