#!/usr/bin/env bash
# Link the personal Claude Code skills dir into ~/.claude. Skills live in the
# repo at configs/claude/skills/<name>/SKILL.md; symlinking the whole dir means
# skills authored interactively (Claude Code writes to ~/.claude/skills/) land
# straight in the working tree, ready to commit. Only the skills subdir is
# touched — the rest of ~/.claude is runtime state and stays untracked.
# See configs/claude/README.md and configs/claude/SKILL.template.md.
set -euo pipefail

link "configs/claude/skills" "$HOME/.claude/skills"
link "configs/claude/claude.sh" "$HOME/.bashrc.d/claude.sh"
