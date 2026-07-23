# Deploy Perlite as a helium compose service behind Traefik

Type: execution
Status: open
Blocked by: 004

_Graduated from the vault-serve map once the way was clear (decisions in tickets
[01](01-choose-live-renderer.md) + [03](03-allowlist-enforcement.md)); full
renderer research in [`assets/01-renderer-research.md`](../assets/01-renderer-research.md)._
Implementation, not a decision — build it per the spec below.

## Goal

Serve the allowlisted vault folders through **Perlite** at one private
`*.home.stromdahl.tech` URL (mesh + LAN), fronted by helium's existing internal
Traefik, deployed via the helium ansible/compose pattern.

## Spec (all decided — do not re-litigate)

- **Images:** `sec77/perlite:latest` (php-fpm-alpine renderer) + `nginx:stable`
  (`web`, serving static `.html` via `volumes_from: perlite`). Pin the perlite
  digest deliberately (tagged releases lag `main`).
- **Include-list = the bind-mount surface, alone** (ticket 03). Mount **only**
  the allowlisted subdirs `:ro` into subpaths of `NOTES_PATH`; leave
  `HIDE_FOLDERS` **unset** (it's a denylist, not the boundary):
  ```yaml
  environment:
    - NOTES_PATH=vault
  volumes:
    - /data/ssd/vault/recipes:/var/www/perlite/vault/recipes:ro
    - /data/ssd/vault/learning:/var/www/perlite/vault/learning:ro
  ```
- **Allowlist as an ansible list variable** in helium's host_vars — the compose
  template loops over it to emit the `:ro` volume lines:
  ```yaml
  vault_serve_allowlist:
    - recipes
    - learning
  ```
  Adding a folder later = one word here + redeploy; anything not listed is not
  mounted, hence not served (default-deny). No chmod step — issue
  [004](004-syncthing-role.md)'s Ignore-Permissions + `UMask=022` makes mounted
  content readable by Perlite's uids (php-fpm `www-data`/82, nginx `nginx`/101).
- **`.html` lessons** are served as-is by the bundled nginx (`try_files` hits the
  on-disk file; only `.md`/`.json` are denied). Set `ALLOWED_FILE_LINK_TYPES` to
  include `html` if lessons should be clickable from inside a rendered markdown
  index note.
- **Traefik:** drop the `web` host port, attach to the Traefik network, add a
  router on a chosen `*.home.stromdahl.tech` subdomain; the `perlite` php service
  stays internal. New subdomain's first cert needs the DNS-01 first-cert
  **`docker restart traefik`** dance (`project_helium_traefik_acme_restart`).
  Confirm split-horizon DNS resolves the subdomain on LAN + mesh
  (`project_helium_dns_split_horizon`).
- **No auth** — private mesh/LAN only; helium PRD forbids public exposure.

## Done when

- The subdomain serves rendered recipes (Obsidian markdown: wikilinks,
  frontmatter, callouts) **and** the standalone `learning/` `.html` lessons, over
  both LAN and mesh.
- Only `recipes/` + `learning/` are reachable; a spot-check confirms no path
  outside the allowlist is served.
- **Recipe render fidelity check** (folds in the former fog item): a
  representative Swedish recipe with rich frontmatter renders *acceptably* as-is.
  If it disappoints, open a `/prototype` follow-up — do not block this deploy on
  cosmetic fidelity.
- Service deploys via the helium ansible/compose pattern and is idempotent.
