---
title: Ingest documents into Paperless from a Proton Mail mailbox via Proton Mail Bridge
status: done
priority: medium
created: 2026-07-09
closed: 2026-07-10
labels: [epic:services, needs-human]
---

## Description

Let documents that arrive by email land in Paperless automatically: emailed receipts,
invoices, and statements should be OCR'd and become full-text searchable without a manual
upload. Paperless does this by polling a mailbox over **IMAP** — but Proton Mail exposes
**no native IMAP/SMTP**. The supported path is **Proton Mail Bridge**, a daemon that logs
into Proton, decrypts mail locally, and re-serves it as plaintext IMAP on a loopback
listener; it requires a paid Proton plan (which the account has).

Run Proton Mail Bridge as a container in helium's compose stack, reachable only by the
Paperless webserver over the internal `paperless` bridge network — no published ports, no
Traefik, never public or LAN-exposed (same boundary as the rest of the stack). Paperless
connects to it with a mail account (unencrypted, container-to-container on the private
bridge; the end-to-end encryption to Proton is a separate, intact layer) and a mail rule
that consumes attachments.

Two steps are unavoidably **needs-human** and cannot be Ansible-automated:

- **Bridge login** is a one-time interactive TTY step (Proton credentials + 2FA/TOTP),
  run over SSH on helium against the deployed container. It writes a session + keyring into
  the bridge's data volume that subsequent restarts reuse.
- **Mail account + rule** are configured once in the Paperless UI (the IMAP host/port/creds
  from the bridge, then the consume rule).

**Operational caveat (document in the runbook):** Proton periodically invalidates the Bridge
session, and when it does mail consumption stops **silently** — Paperless surfaces no error.
The container's status is shown on the Homepage dashboard so a dead bridge is visible; if
ingest goes quiet, re-run the interactive login.

Depends on `issues/007` (Paperless is the ingest target) and `issues/018` (Homepage, for the
bridge status tile).

## Acceptance criteria

- [x] The Proton Mail Bridge container runs on helium and is reachable only by the Paperless
      webserver over the internal network — it has no published port and no Traefik router,
      and is not reachable from the LAN or the public internet.
- [x] After the one-time interactive login, the bridge holds a persistent Proton session that
      survives a container restart without re-login. (Verified: `docker restart` → session
      re-established, Paperless re-authenticated, no re-login.)
- [x] A test email with a PDF attachment sent to the Proton address is ingested by Paperless,
      OCR'd, and becomes full-text searchable. (Verified 2026-07-10: doc id=8; full-text
      search for the marker `BRIDGE-VERIFY-7Q2` returns the document.)
- [x] The bridge's up/down status is visible on the Homepage dashboard.
- [x] The container, its data path, and all non-secret config are defined in the Ansible
      compose-stack role (the login/mail-rule steps are documented as needs-human).

## Outcome (2026-07-10)

Deployed and verified end-to-end. The libfido2 crash from the bridge's runtime self-update
was fixed with a locally-built patched image (Dockerfile at
`roles/compose_stack/files/protonmail-bridge/`). Interactive Bridge login done on the box;
Paperless mail account (id=1) + consume-attachments rule (id=1) created via the REST API.
A forwarded PDF was fetched over IMAP, consumed, OCR'd, and is full-text searchable
(doc id=8). Session persistence across a container restart confirmed.

Operational note: mail account + rule live in Paperless's DB (backed up by issue 026), not
Ansible. If ingest goes quiet, suspect a Proton-expired Bridge session — the Homepage tile
is the tell; re-run the interactive `init` login.
