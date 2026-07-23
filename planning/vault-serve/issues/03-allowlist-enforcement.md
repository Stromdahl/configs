# Decide the serve-time allowlist enforcement mechanism

Type: grilling
Status: resolved
Blocked by: 01

## Question

Given the renderer chosen in `01-choose-live-renderer`, how is the strict
include-list enforced so only allowlisted folders (recipes, learning, + future
additions) are ever served — and never finance/health/people/journal?

Resolve which layer(s) enforce it, and whether to combine them for
defense-in-depth:

- **Renderer include-config** — the tool's own "serve only these folders" setting.
- **Bind-mount surface** — mount only the allowlisted subdirs
  (`recipes/`, `learning/`) into the renderer container read-only, so even a
  path-traversal bug in the renderer cannot reach sensitive folders on disk.
- **Both** — mount narrow AND configure the include-list.

Also settle how a new folder gets added to the allowlist later (the "add to
include-list" ritual) so the default for anything new is *not served*.

## Context inherited from ticket 02

- **Vault path on helium is `/data/ssd/vault`**, owned by `ms`, mode `700`
  (plaintext-at-rest — no encryption). So the renderer's `:ro` bind mounts source
  from `/data/ssd/vault/recipes` and `/data/ssd/vault/learning`.
- **The `700` root is the disk-layer half of the include-list already decided in
  02** — nothing under the vault is reachable by a container *unless* explicitly
  opened. This ticket pins the other half: the exact `:ro` mount surface AND the
  perm mechanism that lets Perlite's container uid (php-fpm/nginx, not `ms`) read
  *only* `recipes/` + `learning/` (world-readable subdirs, or a shared group) —
  verify Perlite's actual read uid when deciding.

## Answer

The include-list is enforced at **one layer — the Docker bind-mount surface** —
with disk perms normalized so the container can read exactly what's mounted, and
the mount list itself expressed as an ansible allowlist variable so "add a
folder" is one legible edit.

### 1. Enforcement layer: the bind-mount surface, alone

Only allowlisted folders are ever mounted (`:ro`) into subpaths of Perlite's
notes root; nothing sensitive is ever present inside the container, so even a
renderer path-traversal bug cannot reach a sensitive folder — it isn't there to
reach.

- Perlite's own `HIDE_FOLDERS` env var is a **denylist** and is left **unset**.
  It is deliberately *not* part of the boundary: relying on it would mean
  remembering to name every future sensitive folder, exactly the failure mode the
  include-list spine forbids. One legible boundary (the mount list), not two
  half-mechanisms.
- Mount sources use ticket 02's path (not the research asset's stale
  `/home/ms/vault/...`):
  ```yaml
  # perlite service
  environment:
    - NOTES_PATH=vault
  volumes:
    - /data/ssd/vault/recipes:/var/www/perlite/vault/recipes:ro
    - /data/ssd/vault/learning:/var/www/perlite/vault/learning:ro
  ```
  `/var/www/perlite/vault` then contains *only* `recipes/` and `learning/`. The
  `web` (nginx) service inherits these via `volumes_from: perlite` and serves the
  `.html` lessons directly. A future `journal/` is invisible by default because
  it was never mounted.

### 2. Read-permission mechanism: helium normalizes perms on sync

Verified read uids (Perlite Dockerfile is `FROM php:fpm-alpine` with **no `USER`**
override; `web` is Debian `nginx:stable`), so two distinct "other" uids must read
the `ms`-owned files:

- **php-fpm** renders markdown as **`www-data` (uid 82, Alpine default pool user)**.
- **nginx** serves static `.html` as **`nginx` (uid 101, nginx:stable default)**.

Because Docker bind-mounts the *subdirs directly* (root daemon does the mount),
the container never traverses the `700` vault root — it only needs read+traverse
on the mounted subdirs and their contents. Files just need to be
**readable-by-other** (`o+r` on files, `o+rx` on dirs), which satisfies both
uid 82 and uid 101 with no shared-group scaffolding.

Rather than chmod-per-file (which helium, as a **Receive Only** replica, would
have Syncthing revert), the readable bit is arranged so it survives sync:

- helium's Syncthing vault folder is set to **Ignore Permissions**, so helium
  writes every synced file using its own filesystem default rather than
  replicating krypton's (inconsistent) modes — verified on krypton: `learning/`
  is already `755`/`644`, but `recipes/` is `770`/`660`.
- the `ms` Syncthing **user service pins `UMask=022`** → synced dirs land `755`,
  files `644` (readable-by-other) deterministically, regardless of source modes,
  and this automatically covers any future allowlisted folder.
- the vault **root stays `700`** (ticket 02): sensitive folders synced in are
  world-readable *dirs* but sit behind the `700` gate (no host-local traversal)
  and are **never mounted** (no container exposure). The mount list remains the
  sole boundary; the perm choice only makes mounted content reachable.

### 3. Add-a-folder ritual: one word in an ansible list variable

The allowlist is a **first-class ansible list variable** in helium's host_vars,
e.g.:

```yaml
vault_serve_allowlist:
  - recipes
  - learning
```

The compose template loops over it to emit the `:ro` volume lines. To add a
folder: add one word to `vault_serve_allowlist`, redeploy. No chmod step
(Ignore-Permissions + `UMask=022` handles readability). Anything not in the list
is not mounted, hence **not served** — default-deny by construction.

### Deploy wiring (graduates to execution issues)

This was the last open decision. The deploy graduates into execution issues
[`004-syncthing-role`](004-syncthing-role.md) (the Receive-Only + Ignore-Perms +
`UMask=022` Syncthing role) and [`005-perlite-service`](005-perlite-service.md)
(the Perlite/nginx compose service, Traefik router, allowlist-driven mounts, and
a check that a representative recipe renders acceptably — retiring the
recipe-render-fidelity fog).
