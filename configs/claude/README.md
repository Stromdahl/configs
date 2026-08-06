# Claude Code personal skills

The `claude` module symlinks this repo's `configs/claude/skills/` to
`~/.claude/skills/`, the location Claude Code loads *personal* (all-projects)
skills from. Because it's a symlink, skills authored interactively — Claude
Code's own `skill-creator` writes to `~/.claude/skills/` — land directly in this
tree, ready to `git add` and commit.

## Layout

```
configs/claude/
├── README.md            # this file
├── SKILL.template.md    # copy-me template (NOT a live skill — not under skills/)
└── skills/              # symlinked → ~/.claude/skills/
    └── <skill-name>/
        └── SKILL.md      # one folder per skill; the dir name is the skill id
```

Only folders under `skills/` become live skills. The template lives one level up
on purpose, so it never shows up in the session skill list.

## Adding a skill

1. `mkdir configs/claude/skills/<skill-name>` (kebab-case; this becomes the id).
2. Copy `SKILL.template.md` to `skills/<skill-name>/SKILL.md` and fill it in.
3. `git add` + commit. It's live on the next Claude Code session on any machine
   that has the `claude` module (currently krypton).

Or just ask Claude Code to use the `skill-creator` skill — it'll scaffold,
test, and iterate on the skill, writing straight into this tree via the symlink.

## The `description` field matters most

Claude decides whether to invoke a skill by matching the task against the
frontmatter `description`. Write it as *when to use this* with concrete trigger
phrases, not just *what it is*. A vague description means the skill never fires.

## Upstream skills and local deltas

Most of `skills/` is [mattpocock/skills](https://github.com/mattpocock/skills)
verbatim (pulled 2026-07-11). Re-pull a skill with:

```
curl -sfL https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/<name>/SKILL.md
```

Where a skill has been forked locally, the delta is listed here so the next
upstream pull knows what to re-apply on top.

### `wayfinder` — anti-grilling-bias delta (2026-08-06)

Rebased onto upstream `main` (commit `7d0c362`), then five edits. Measured over
11 maps / 117 tickets, 56% of tickets were typed `grilling` and 4% `prototype`;
on software/infra maps it was 66% / 2%. Empirical work still happened — it just
happened late, unplanned and mislabelled as grilling, so decisions got agreed on
unverified premises. The edits:

1. **Both "default to grilling" lines deleted** — `The default case.` from the
   Grilling type, and *"If in doubt, use `/grilling` and `/domain-modeling`"*
   from work-through step 4. A **fact-or-preference test** replaces them above
   the type list. Killing only one reinstates the bias at the other.
2. **`research` widened to measurement** — reading *or* running the real system
   (booting the image, probing the endpoint, counting the files). Upstream gates
   it to knowledge "outside the current working directory", which leaves facts
   about your own running system with no type but `grilling`.
3. **`prototype` builds AFK, reacts HITL** — upstream marks it wholly HITL, so a
   prototype ticket waits for a session with the human in it and never gets one.
   Also widened past code, since `/prototype` only covers code.
4. **Premise check** — new work-through step 3, before resolving: state the
   decision's assumptions, verify the load-bearing ones first (inline, or split
   into a blocking AFK ticket), open the conversation with findings on the table.
5. **Capture rule** — a fact established inline is recorded with *how* (the
   command, the probe), not just what, so the next ticket can re-run it.

Knock-on: charting step 5 builds prototypes alongside the research subagents,
and the one-ticket-per-session exception covers prototype builds. Upstream's
`research/<name>` throwaway branch was made tracker-conditional — the
local-markdown tracker keeps assets in-tree.

## Deploy

`cd ~/.dotfiles && ./install.sh` (the module is idempotent; `--dry-run` to
preview). The `link` helper only creates `~/.claude/skills` — it never touches
the rest of `~/.claude`.
