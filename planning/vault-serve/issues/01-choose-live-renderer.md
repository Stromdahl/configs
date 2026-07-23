# Choose the live vault renderer

Type: research
Status: claimed
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
