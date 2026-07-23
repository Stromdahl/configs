# Map: Serve non-sensitive vault folders from helium

`wayfinder:map` — child tickets live in `planning/vault-serve/issues/`.

## Destination

On **helium**, a **live Obsidian-vault web renderer** serves a **strict
include-list** of non-sensitive vault folders (starting with `recipes/` and
`learning/`) behind **one private `*.home.stromdahl.tech` URL** (mesh + LAN),
Traefik-fronted, deployed via helium's existing ansible/compose pattern. The
**whole vault** reaches helium via **Syncthing** (helium becomes a full peer like
the phone); the allowlist is enforced at the **serve layer** via a strict
*include*-list, so sensitive folders are never served.

## Notes

- **Domain:** ~/.dotfiles homelab. helium = bare-metal Debian NAS+services box
  (ansible-provisioned; media + Immich + Paperless stack behind Traefik + NetBird
  mesh + split-horizon DNS `*.home.stromdahl.tech`). See `hosts/helium/PRD.md`.
- **Audience:** just the user + maybe household. Private only — mesh (roaming) +
  LAN (e.g. a kitchen tablet). No public internet (helium PRD already forbids it).
- **Sensitive-data boundary is the spine of this effort.** The whole vault
  (incl. finance/health/people/journal) will physically sit on helium — accepted,
  since helium already holds Immich photos + Paperless docs, so it's not a new
  sensitivity class. The allowlist therefore MUST be a strict **include**-list at
  the serve layer (name what IS served), never a denylist — a future `journal/`
  folder is invisible by default, not accidentally LAN-readable.
- **Two content shapes:** recipes = structured Swedish markdown w/ rich
  frontmatter (`~/vault/templates/recipe.md`); learning = standalone HTML lessons
  meant to open in a browser (`~/vault/learning/<topic>/lessons/`). One general
  renderer must handle both. A frontmatter-aware recipe *app* is out of scope.
- **Current Syncthing topology:** krypton + phone. titan (old peer) is gone;
  Syncthing is NOT installed on helium yet. Vault Syncthing gotcha: agent deleting
  `.stfolder` on reorg silently halts sync (see `project_hermes_vault_sync`).
- **Skills:** use `/grilling` + `/domain-modeling` for the grilling tickets;
  `/research` for the research ticket.
- **Plan, don't do:** this map produces decisions; the deploy execution graduates
  into real `issues/NNN` once the way is clear.

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Choose the live vault renderer](issues/01-choose-live-renderer.md) —
  **Perlite** (secure-77/Perlite): live per-request PHP render, serves the `.html`
  lessons via its bundled nginx, mount only allowlisted folders `:ro` (its
  `HIDE_FOLDERS` denylist is NOT the boundary). Runner-up Emanote. Full research:
  [`assets/01-renderer-research.md`](assets/01-renderer-research.md).
- [Decide the Syncthing-on-helium approach & full-vault security posture](issues/02-syncthing-on-helium.md) —
  new **ansible `syncthing` role** (helium is ansible-only); vault at
  **`/data/ssd/vault`** (new SSD *precious* subvol), owned by **`ms`**, Syncthing
  as the `ms` user service; **plaintext-at-rest + `700`** (allowlist guards the
  *site*, not the files — accepted), allowlisted subdirs opened for container read
  = disk-layer echo of the include-list (→ ticket 03); helium **`Receive Only`**,
  krypton authoritative, pure passive replica.

## Not yet specified

- **Deploy wiring (all execution — graduates as real `issues/NNN`, not decision
  tickets, once ticket 03 lands).** Now spec-complete except the allowlist mount
  surface (ticket 03):
  - **Syncthing role** — DECIDED (ticket 02): ansible role installing Syncthing
    as the `ms` user service on helium, folder `/data/ssd/vault` `Receive Only`,
    krypton authoritative; open 22000/tcp + 21027/udp on helium's firewall path.
    Ready to graduate.
  - **Perlite service** — Perlite (`sec77/perlite` + `nginx:stable`) as a helium
    compose service behind the internal Traefik at a chosen
    `*.home.stromdahl.tech` subdomain, incl. the DNS-01 first-cert
    `docker restart traefik` dance (`project_helium_traefik_acme_restart`).
    Waits on ticket 03 for the exact `:ro` mount lines + subdir perms.
- **Recipe render fidelity** — whether the recipe markdown/frontmatter renders
  *acceptably* as-is in the chosen renderer, or wants a `/prototype` pass.
  Graduates once the renderer is chosen.

## Out of scope

- A **frontmatter-aware recipe app** (serving-size scaling, generated shopping
  lists) — a separate future want, not this effort.
- **Public internet exposure** — helium PRD forbids it.
- Serving any **sensitive** vault folder (finance/health/people/journal/…) — never,
  by construction of the include-list.
