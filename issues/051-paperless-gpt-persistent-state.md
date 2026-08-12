---
title: Persist paperless-gpt state across container recreates
status: open
priority: medium
created: 2026-08-12
closed: null
labels: [epic:services]
---

## Description

paperless-gpt keeps its prompt templates, correction history, and other
configuration under its own data directory inside the container, but its service
definition in the compose stack has no volume backing that directory. Every
recreate — an image bump, an unrelated compose-file edit that forces a recreate,
or a manual force-recreate — silently discards any customization made through
paperless-gpt's UI. Give it a persistent volume, consistent with how the rest of
the stack's stateful services are handled, so its configuration survives
redeploys.

## Acceptance criteria

- [ ] paperless-gpt's config/prompt/database directory is backed by a persistent
      volume, following the stack's existing convention (bind mount on the SSD
      appdata tier, owned by the stack's jellyfin uid/gid where applicable).
- [ ] A container recreate preserves a prompt customization or correction made
      before the recreate.
- [ ] The new directory is included wherever the compose-stack role pre-creates
      and chowns appdata directories, matching how the other *arr/paperless-suite
      apps are handled.
