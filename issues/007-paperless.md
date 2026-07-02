---
title: Paperless document ingest, mesh-only
status: done
priority: medium
created: 2026-06-27
closed: 2026-07-02
labels: [epic:services, needs-human]
---

## Description

Deploy Paperless-ngx for ingesting and searching personal records — receipts,
invoices, legal documents. The stack (web + Postgres + Redis + Gotenberg + Tika)
runs on the SSD tier, served at `paperless.home.stromdahl.tech` behind the internal
Traefik and reachable only over the NetBird mesh. OCR runs on the CPU. An ingest
path (consume folder and/or upload) lets documents be added and become full-text
searchable.

Documents and database live on the redundant SSD tier (the future backup work,
out of scope here, will cover this irreplaceable data).

Depends on `issues/005` (Traefik internal + NetBird mesh + compose-stack role) and
`issues/011` (the data-tier mirror the documents and database live on).

## Acceptance criteria

- [x] Paperless is reachable at `paperless.home.stromdahl.tech` over the mesh with a
      valid cert; not reachable publicly.
- [x] A document added via the ingest path is OCR'd and becomes full-text
      searchable.
- [x] Documents and Postgres data reside on the SSD tier.
- [x] The service is deployed via the Ansible compose-stack role with sops-sourced
      secrets.
