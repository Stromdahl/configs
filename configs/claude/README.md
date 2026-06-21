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

## Deploy

`cd ~/.dotfiles && ./install.sh` (the module is idempotent; `--dry-run` to
preview). The `link` helper only creates `~/.claude/skills` — it never touches
the rest of `~/.claude`.
