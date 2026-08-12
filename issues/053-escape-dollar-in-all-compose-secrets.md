---
title: Escape '$' in every compose secret interpolated from stack.env, not just the Traefik dashboard hash
status: open
priority: medium
created: 2026-08-12
closed: null
labels: [epic:services]
---

## Description

docker compose's own `.env`-file interpolation eats a literal `$` before a value
ever reaches the compose YAML. That bug already bit the Traefik dashboard's
basic-auth hash and was fixed by escaping `$` to `$$` specifically for that one
secret. The same interpolation exposure exists for the qBittorrent WebUI password
and several Paperless secrets (secret key, DB password, admin password) — none of
which are escaped, and none of which are documented as constrained to
alphanumeric-only the way the Immich DB password is. Any of those secrets
containing a `$` — plausible for a user-set WebUI password — would silently
corrupt on render: the same failure class already fixed once for Traefik.

## Acceptance criteria

- [ ] Every stack secret rendered into `stack.env` that is later consumed via
      compose's `${VAR}` interpolation is either escaped consistently with the
      Traefik dashboard fix, or documented and enforced (at mint/rotate time) to
      be alphanumeric-only, matching the Immich DB password convention.
- [ ] A secret value containing a literal `$` round-trips correctly into its
      container's environment for each affected service (qBittorrent WebUI,
      Paperless secret key, Paperless DB password, Paperless admin password).
