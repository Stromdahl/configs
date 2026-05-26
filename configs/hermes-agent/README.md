# hermes-agent — config

- `env.example` — operator-editable env file; the module symlinks it to
  `~/.hermes/env.example` and you copy it to `.env` and fill in the
  OpenRouter key. `.env` itself is never auto-created (don't clobber
  operator state).
- `vault-skeleton/` — seed files for the long-term memory vault. The
  module copies this tree into `~/hermes-vault/` with no-clobber
  semantics, so re-running the module never overwrites agent or hand
  edits. Empty subfolders (`Daily/`, `Inbox/`, `Work/`, `Personal/`) are
  created by `mkdir -p` in the module rather than tracked as empty
  dirs here.

Layout mirrors the three-tier pattern from u/Jonathan_Rivera's
r/hermesagent post:

- **Hot tier** — `~/.hermes/memories/MEMORY.md` + `USER.md` (built-in,
  injected into the system prompt). Treated as an *index* of routing
  pointers, not bulk storage.
- **Warm tier (this vault)** — stable reference files, read on demand
  via the bundled `obsidian` skill.
- **Daily tier** — `Daily/YYYY-MM-DD.md` timestamped notes.

Fill in the placeholders in `System/Assistant/*.md` before the first
real session; the agent reads them as ground truth.
