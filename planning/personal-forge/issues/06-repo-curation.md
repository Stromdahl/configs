# Which repos come to the forge, and in what state?

Type: grilling
Status: open

## Question

"Organize" was scoped to hosting + **curation**. Curation is the half that needs
the owner: deciding what is alive, what is parked, and what is dead — because
importing 24 repos with no sense of which 12 are stale just moves the mess behind
a nicer front-end.

Work through, with the owner (`/grilling`):

1. **The 17 remote-less repos** — one at a time or in batches, `active` / `paused`
   / `archived`. (Forgejo has a per-repo archive flag; `taskmaster`'s
   `state = active|paused|archived` was reaching for exactly this vocabulary and
   is worth reusing.)
2. **The edge cases the survey turned up:**
   - `keyerr` — a git repo with **no commits at all** and a dirty tree. Is this a
     project or a false start?
   - `homelab-stack.archived` — remote points at the decommissioned
     `jellyfin.stromdahl.tech`. Archive as history, or drop? Its content is
     superseded by `~/.dotfiles/servers/` (`project_monorepo_merge`).
   - `playground`, `rssfeed`, `vendor`, `hermes` — **not git at all**. Do any
     become repos, or do they stay loose directories? (`hermes` is live —
     see `project_hermes_agent_architecture`.)
   - `marlin-ender3`, `marlin-configs` — **upstream clones of MarlinFirmware's
     repos**, not the owner's work. Recommendation: exclude from the forge
     entirely; they are re-cloneable from upstream and do not need backing up.
     Confirm.
3. **Naming.** Does the forge repo name always match the directory name? The
   survey found `diy-speekers` (sic) — a chance to fix a typo, at the cost of the
   directory and the repo disagreeing.
4. **Organisation structure.** One user account with flat repos, or Forgejo
   *organisations* to group them (e.g. `tools` / `hardware` / `homelab`)? Note
   this is grouping *on the forge*, which is cheap and reversible — filesystem
   restructuring is explicitly out of scope.

Output: a concrete, per-repo import list with states — the input the migration
work will execute against.
