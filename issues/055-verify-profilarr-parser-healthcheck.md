---
title: Verify profilarr's parser healthcheck actually exists in the pinned image
status: open
priority: low
created: 2026-08-12
closed: null
labels: [epic:services, needs-human]
---

## Description

profilarr's dependency on the parser service uses a health-gated `depends_on`,
but no healthcheck is defined in the compose file itself — it's assumed to ship
inside the pinned parser image. If a future image update drops that healthcheck
(or never reliably had one), the stack fails to come up entirely, since Docker
refuses to honor a health-gated dependency against a container with no
healthcheck configured, rather than degrading gracefully.

Needs a one-time on-box check (needs-human: requires shell access to inspect a
running container on helium). If the assumption doesn't hold, either add an
explicit healthcheck for the parser service or relax profilarr's dependency
condition so a future image bump can't silently break the stack's ability to
start.

## Acceptance criteria

- [ ] Confirmed whether the currently-pinned parser image ships a working
      healthcheck.
- [ ] If it does not, the compose file defines an explicit healthcheck for the
      parser service, or profilarr's dependency condition is relaxed accordingly.
