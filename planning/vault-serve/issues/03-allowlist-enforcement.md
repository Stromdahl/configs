# Decide the serve-time allowlist enforcement mechanism

Type: grilling
Status: open
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
