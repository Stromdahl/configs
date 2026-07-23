# Choose the live vault renderer

Type: research
Status: resolved
Blocked by: —

## Question

Which live (no-build) renderer should serve the allowlisted vault folders on
helium? Evaluate candidates (e.g. perlite, obsidian-livesync web, silverbullet,
mkdocs-material w/ live serve, a generic markdown server, digital-garden tools)
against these hard requirements:

- **Live**, reads markdown on request — no static rebuild trigger to rot.
- Renders **Obsidian-flavored markdown**: `[[wikilinks]]`, YAML frontmatter,
  embeds, callouts.
- Serves the **standalone HTML learning lessons** as-is
  (`~/vault/learning/<topic>/lessons/*.html`) alongside rendered markdown.
- Supports a **strict include-list** — can be pointed at only named folders, so
  sensitive folders are never reachable (this is safety-critical; see map Notes).
- **Dockerizes cleanly** — fits helium's ansible/compose + Traefik pattern.
- No built-in auth required (it sits behind the private mesh/LAN).

Deliver a markdown summary as a linked asset with a recommendation + runner-up
and the include-list mechanism each tool offers.

## Answer

**Recommended: Perlite** (secure-77/Perlite) — full write-up with comparison
table + primary sources at
[`assets/01-renderer-research.md`](../assets/01-renderer-research.md).

Perlite is the only candidate meeting all six hard requirements with
primary-source proof: per-request live PHP rendering (no build step), Obsidian
markdown incl. frontmatter + callouts + wikilinks, standalone `.html` served
directly by its bundled nginx (verified in the committed `perlite.conf`:
`try_files` serves on-disk files, only `.md`/`.json` are denied), a clean
two-service compose (`sec77/perlite` + `nginx:stable`), no forced auth, commits
into Jan 2026 (tagged releases lag → pin a digest).

- **Runner-up: Emanote** (srid/emanote) — a genuine live Obsidian renderer, but
  demoted by a ~2-yr-stale Docker image, unconfirmed `.html` passthrough, and a
  heavier Haskell/Nix footprint. (Silverbullet third: editor-first, experimental
  read-only, no `.html`.)
- **Safety spine → mount layer, not config.** Enforce the include-list by mounting
  only `recipes/` + `learning/` `:ro`; mount nothing else, so a future `journal/`
  is invisible by default. Perlite's own `HIDE_FOLDERS` is a *denylist* and MUST
  NOT be the boundary. This directly informs ticket 03.
- **Caveat:** no renderer's *engine* does both Obsidian-md AND `.html` passthrough;
  Perlite clears it only because its stack bundles nginx to serve `.html` as
  static assets alongside. Those lessons won't appear in Perlite's md nav/graph —
  reach them by direct URL or a linking index note (or, as a fallback, a tiny
  static-nginx sidecar mounting `learning/` `:ro`).
