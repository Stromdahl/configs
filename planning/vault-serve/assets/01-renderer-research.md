# Renderer research: live Obsidian-vault web renderer for helium

Research ticket for `planning/vault-serve` (map: serve non-sensitive vault
folders from helium). Read/research only — nothing installed or configured.

## The requirements

One renderer on helium must serve an allowlist of vault folders (starting
`recipes/` + `learning/`) behind one private Traefik-fronted
`*.home.stromdahl.tech` URL. Two content shapes through **one** renderer:

- **recipes/** — Obsidian-flavored Swedish markdown, rich YAML frontmatter.
- **learning/<topic>/lessons/** — standalone `.html` files that open directly.

Scored against six hard requirements:

1. **Live** — reads markdown per request; no static build/rebuild trigger to
   stay in sync (vault syncs continuously via Syncthing). SSGs strongly disfavored.
2. Renders **Obsidian markdown**: `[[wikilinks]]`, YAML frontmatter,
   embeds/transclusion, callouts.
3. Serves **standalone `.html` as-is** alongside rendered markdown (natively or trivially alongside).
4. **Strict include-list / allowlist** — points at ONLY named folders. A future
   `journal/` must be invisible **by default** (include-list, never denylist).
   This is the safety spine of the whole effort.
5. **Dockerizes cleanly** — ideally a maintained image; fits compose + Traefik.
6. **No forced auth** (sits behind private mesh/LAN) — note if a tool forces it.

## Comparison

| Tool | 1 Live | 2 Obsidian md | 3 Serves `.html` | 4 Include-list | 5 Docker | 6 No forced auth | Maintained (2026) |
|---|---|---|---|---|---|---|---|
| **Perlite** | ✅ per-request PHP | ✅ wikilinks, frontmatter, callouts, tags, mermaid, LaTeX | ✅ nginx serves `.html` directly | ⚠️ denylist env, but ✅ true include-list via per-folder `:ro` mounts | ✅ `sec77/perlite` + `nginx:stable` | ✅ none | ✅ commits into Jan 2026 (tagged releases lag) |
| **Emanote** | ✅ live server (Ema/warp) | ✅ wikilinks, callouts, embeds, queries, frontmatter | ⚠️ likely, unconfirmed from primary source | ✅ mount only named folders as the notebook | ⚠️ `sridca/emanote` image ~2 yr stale (repo active) | ✅ none | ✅ repo active; niche (Haskell/Nix) |
| **Silverbullet** | ✅ live server | ⚠️ own md flavor (not Obsidian-identical); wikilinks/frontmatter yes | ❌ markdown space only | ✅ mount only named folders as the space | ✅ maintained image | ⚠️ editor-first; needs experimental `SB_READ_ONLY` | ✅ very active (2026) |
| Quartz | ❌ SSG; `--serve` = watch+rebuild | ✅ | ✅ (static assets) | ⚠️ input dir | ⚠️ build tool | ✅ | ✅ active |
| MkDocs-Material | ❌ SSG; `mkdocs serve` = dev-only, watch+rebuild, "not for production" | ⚠️ needs plugins for wikilinks/callouts | ⚠️ | ⚠️ nav config | ✅ | ✅ | ✅ active |
| Dendron / Foam publish | ❌ static export | ✅/⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | ⚠️ Dendron stalled |
| Obsidian LiveSync | n/a — **not a renderer** (CouchDB sync backend) | — | — | — | — | — | ✅ |
| Generic md server (markserv/grip) | ✅ | ❌ no Obsidian wikilinks/callouts | ✅ | via mount | ⚠️ | ✅ | varies |

## Per-tool notes

### Perlite (recommended) — secure-77/Perlite

PHP (`php:fpm-alpine`) + `nginx:stable`, "web-based markdown viewer optimized
for Obsidian." Renders **dynamically, no build step** — PHP processes markdown
on request, no database
([README](https://github.com/secure-77/Perlite/blob/main/README.md)). Obsidian
support: wikilinks, tags, images, Mermaid, LaTeX, interactive graph; **YAML
frontmatter** rendered as properties (issue #107) and **collapsed callouts**
(issue #113) are both supported
([Changelog](https://github.com/secure-77/Perlite/blob/main/Changelog.md)).

**`.html` — confirmed served directly.** The bundled nginx config
(`web/config/perlite.conf`, read via `gh api`) is:

```nginx
root /var/www/perlite;
index index.php index.html index.htm;
location / { try_files $uri $uri/ /index.php; }
location ~ \.php$ { fastcgi_pass perlite:9000; ... }
location ~ \.(md|json)$ { deny all; }   # markdown only via the PHP SPA
```

`try_files $uri ...` serves any on-disk file first; `.md`/`.json` are denied
(forcing them through the renderer) but **`.html` is not denied**, so standalone
`.html` lessons on disk are served as static files at their path, while markdown
routes through `index.php`. Both content shapes work in **one container**, no
sidecar. (To make a `.html` link *clickable from within a rendered markdown
note*, add `html` to `ALLOWED_FILE_LINK_TYPES`; direct URLs work regardless.)

**Allowlist — the important part.** Perlite's own env var `HIDE_FOLDERS` is a
**denylist** and MUST NOT be the boundary — it violates the include-list spine
(you'd have to remember to add every future sensitive folder). Instead enforce
the include-list **at the Docker mount layer**: mount only the named safe
folders read-only into subpaths of the notes root, mount nothing else:

```yaml
environment:
  - NOTES_PATH=vault          # container notes root
volumes:
  - /home/ms/vault/recipes:/var/www/perlite/vault/recipes:ro
  - /home/ms/vault/learning:/var/www/perlite/vault/learning:ro
```

`/var/www/perlite/vault` then contains *only* `recipes/` and `learning/`. A
future `~/vault/journal/` is invisible **by default** because it was never
mounted — that is a true include-list, exactly what map.md's safety spine
requires. `:ro` also guarantees the renderer can never write back into the vault.

Config: `sec77/perlite:latest` image, env vars (`NOTES_PATH`, `HOME_FILE` for a
landing note, `SHOW_TOC`, `SHOW_LOCAL_GRAPH`, `HTML_SAFE_MODE`, etc. — see
[Settings wiki](https://github.com/secure-77/Perlite/wiki/03---Perlite-Settings)).
No built-in auth. **Maintained:** git history shows commits through **Jan 2026**
(PR #178) — actively developed, though tagged releases lag (last tag ~2024), so
pin the digest or track `latest` deliberately.

### Emanote (runner-up) — srid/emanote

Purpose-built "live Obsidian-flavored markdown server" on the Ema live-server
framework. `emanote run` starts a **real per-request live server** with
hot-reload (`emanote gen <out>` is the *separate* static path — you'd use `run`,
not `gen`). Supports `[[wikilinks]]`, `![[embeds]]`, callouts, task lists,
Obsidian-style queries, YAML, HTML templates
([guide](https://emanote.srid.ca/guide),
[embed](https://emanote.srid.ca/guide/markdown/embed)). Include-list is clean:
mount only the named folders as the notebook. As a **publisher (read-only by
nature)** it fits a browsable site better than Silverbullet.

Why not primary: (a) the `sridca/emanote` Docker Hub image is **~2 years stale**
even though the repo is active — you'd likely build your own; (b) I could **not
confirm from a primary source** that the live server serves standalone `.html`
as-is (its strength is HTML *templates*, a different thing); (c) Haskell/Nix
niche is heavier to self-support than Perlite's PHP+nginx. Strong second choice,
and the natural fallback if Perlite's markdown fidelity disappoints.

### Silverbullet (third) — silverbulletmd/silverbullet

Actively maintained (2026) self-hosted PKM, single container, wikilinks +
frontmatter + queries + Lua. But it is an **editor first**; a read-only public
view needs the **experimental** `SB_READ_ONLY` env var
([Configuration](https://silverbullet.md/Install/Configuration)), its markdown
flavor is **not Obsidian-identical**, and it **does not serve standalone
`.html`**. Include-list via mounting only safe folders as the "space." Good tool,
weaker fit for a read-only browsable site with HTML lessons.

### Rejected

- **Quartz** — SSG. `npx quartz build --serve` is a watch-and-**rebuild** dev
  server, not per-request rendering; production output is static HTML. Fails req 1.
- **MkDocs-Material** — SSG. `mkdocs serve` is explicitly **development-only**
  ("MkDocs' server is intended for local development purposes only... use a
  third party production-ready server") and rebuilds on change; also needs
  plugins for Obsidian wikilinks/callouts. Fails req 1.
- **Dendron / Foam publish** — static export pipelines; fail req 1. Dendron
  development has largely stalled.
- **Obsidian LiveSync** — a CouchDB **sync backend**, not a renderer at all. Out
  of scope (helium gets the vault via Syncthing, not LiveSync).
- **Generic live md servers** (markserv, grip) — serve `.md` live and `.html`
  as-is, but have **no Obsidian wikilink/callout/embed** support. Fail req 2.

## Recommendation

**Recommended: Perlite.** It is the only candidate that satisfies **all six**
hard requirements with primary-source confirmation: per-request live PHP
rendering (no build), Obsidian markdown *including* frontmatter + callouts,
standalone `.html` served directly by its bundled nginx (verified in the
committed `perlite.conf`), a true serve-layer include-list via per-folder `:ro`
mounts, a clean two-service compose (`sec77/perlite` + `nginx:stable`), no forced
auth, and active maintenance into 2026.

**Runner-up: Emanote** — a genuine live Obsidian renderer and the better
publisher-shaped tool of the rest; demoted only by a stale Docker image, an
unconfirmed `.html`-passthrough story, and a heavier Haskell/Nix footprint.

**How Perlite meets the three tricky points:**

- **Include-list:** enforced at the **mount layer**, not by config. Mount only
  `recipes/` and `learning/` `:ro` into subpaths of `NOTES_PATH`; mount nothing
  else. New sensitive folders are invisible by default. Explicitly do **not**
  rely on `HIDE_FOLDERS` (a denylist).
- **HTML lessons:** served as-is by the bundled nginx (`try_files` hits the
  on-disk file; only `.md`/`.json` are denied). No sidecar needed. Add `html` to
  `ALLOWED_FILE_LINK_TYPES` if you want the lessons clickable from inside a
  rendered markdown index note.
- **Traefik/compose slot-in:** the `web` (nginx) service already publishes port
  80 — drop the host port, attach it to the Traefik network with a router on a
  `*.home.stromdahl.tech` subdomain (mind the DNS-01 first-cert
  `docker restart traefik` gotcha, per `project_helium_traefik_acme_restart`).
  The `perlite` PHP service stays internal.

## Requirement no tool fully satisfies (natively)

**Req 3 — one tool doing Obsidian-md rendering AND native `.html` passthrough —
is not met by any renderer's *rendering engine*.** The Obsidian renderers
(Perlite, Emanote, Silverbullet) are markdown engines; generic servers that pass
`.html` through lack Obsidian markdown. Perlite resolves this only because its
*deployment stack* bundles nginx, which serves the `.html` files as static
assets beside the PHP-rendered markdown — the "trivially alongside" path map.md
already permits, achieved inside a single container. If a future tie-break
rejects that split, the honest fallback is a tiny static-nginx sidecar mounting
only `learning/` `:ro` behind the same Traefik router. Also note: Perlite's
`.html` lessons won't appear in its markdown *navigation/graph* (it indexes
`.md`); reach them via direct URL or a markdown index note that links to them.
