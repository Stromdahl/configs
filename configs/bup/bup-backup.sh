#!/usr/bin/env bash
# Daily bup backup of ~/notes into a local repo (~/backups/bup-notes).
# Driven by bup-notes.service/.timer (systemd user units): index, then save.
#
# Restore examples (BUP_DIR points bup at the repo):
#   BUP_DIR=~/backups/bup-notes bup ls notes/                       # list saves
#   BUP_DIR=~/backups/bup-notes bup ls notes/latest/home/ms/notes   # browse tree
#   BUP_DIR=~/backups/bup-notes bup restore -C /tmp/r \
#       notes/latest/home/ms/notes/daily.md                         # one file
#   BUP_DIR=~/backups/bup-notes bup restore -C /tmp/r \
#       notes/latest/home/ms/notes/                                 # whole vault
#
# Offsite (future): add an ssh target on neon and a second save —
#   bup save -r neon:/srv/backups/bup-notes -n notes "$HOME/notes"
set -euo pipefail

export BUP_DIR="$HOME/backups/bup-notes"

[ -e "$BUP_DIR/HEAD" ] || bup init   # idempotent (HEAD exists once initialised)

# Index ~/notes, excluding Syncthing markers + Obsidian's volatile workspace
# cache. The rest of .obsidian/ (plugins, appearance) is KEPT so a restore
# brings the vault's settings back. --exclude-rx is a regex matched on the path.
bup index "$HOME/notes" \
  --exclude-rx '/\.stfolder(\.removed-[0-9-]+)?(/|$)' \
  --exclude-rx '/\.stversions(/|$)' \
  --exclude-rx '/\.trash(/|$)' \
  --exclude-rx '/\.obsidian/workspace[^/]*$'

bup save -n notes "$HOME/notes"
