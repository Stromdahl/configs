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
