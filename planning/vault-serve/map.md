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
  krypton authoritative, pure passive replica — **the sync-posture half of this is
  superseded: helium is now `Send-Receive` and a two-writer folder** (2026-07-31,
  [hermes-helium 04](../hermes-helium/issues/04-respec-vault-serve-004-send-receive.md));
  everything else in 02 stands.
- [Decide the serve-time allowlist enforcement mechanism](issues/03-allowlist-enforcement.md) —
  boundary is the **bind-mount surface alone** (only allowlisted subdirs mounted
  `:ro`; `HIDE_FOLDERS` denylist left unset). Perlite reads as two "other" uids
  (php-fpm `www-data`/82, nginx `nginx`/101), so files must be readable-by-other;
  achieved by setting helium's Syncthing folder to **Ignore Permissions** +
  pinning `UMask=022` on the `ms` Syncthing service (deterministic `755`/`644`,
  auto-covers future folders), vault root stays `700`. Allowlist is a first-class
  ansible list var `vault_serve_allowlist` templating the `:ro` mounts — add a
  folder = one word + redeploy; default-deny for everything else.

## Not yet specified

> ⚠️ **Cross-map coupling — read before working ticket 004.** The
> [hermes-helium map](../hermes-helium/map.md) puts a *writing* agent on the same
> helium vault replica, so **004's `Receive Only` spec was superseded by
> `Send-Receive`** (decided 2026-07-31). **The re-spec has landed** — 004 is
> amended and buildable as written, and carries a verified *Consequences of
> Send-Receive* section (deletions propagate upstream; `.sync-conflict-*` accepted;
> the `.stfolder` trap is now high-exposure). Tickets 02 and 03 carry inline
> amendment notes. Done by
> [hermes-helium ticket 04](../hermes-helium/issues/04-respec-vault-serve-004-send-receive.md).
> Everything else in 004 stands — `/data/ssd/vault`, `ms`-owned, Ignore
> Permissions, `UMask=022`. Ticket 005 (Perlite) is **unaffected — verified, not
> assumed**: its boundary is the `:ro` bind-mount surface, and `Ignore Permissions`
> is folder-type independent. This map is no longer strictly decision-complete,
> since the write posture was decided on the other map.

_Was decision-complete as of 2026-07-24 — see the coupling note above._ Ticket 03
was the last open decision then. All remaining work is **execution**, now
graduated into two implementation issues (no decisions left, just building):

- [`004-syncthing-role`](issues/004-syncthing-role.md) — ansible role installing
  Syncthing as the `ms` user service on helium: folder `/data/ssd/vault`
  **Send-Receive** (re-specced 2026-07-31) + **Ignore Permissions**, `UMask=022`
  on the service unit, krypton the first-reconcile source; open 22000/tcp +
  21027/udp on helium's firewall path. Must create the folder **empty** — under
  Send-Receive, pre-seeded content is pushed upstream.
- [`005-perlite-service`](issues/005-perlite-service.md) — Perlite
  (`sec77/perlite` + `nginx:stable`) compose service behind the internal Traefik
  at a `*.home.stromdahl.tech` subdomain, `:ro` mounts driven by the
  `vault_serve_allowlist` ansible var, incl. the DNS-01 first-cert
  `docker restart traefik` dance (`project_helium_traefik_acme_restart`); also
  checks a representative recipe renders acceptably (folds in the former
  recipe-render-fidelity question — if it disappoints, open a `/prototype`
  follow-up then).

## Out of scope

- A **frontmatter-aware recipe app** (serving-size scaling, generated shopping
  lists) — a separate future want, not this effort.
- **Public internet exposure** — helium PRD forbids it.
- Serving any **sensitive** vault folder (finance/health/people/journal/…) — never,
  by construction of the include-list.
