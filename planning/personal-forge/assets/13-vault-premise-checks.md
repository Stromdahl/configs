# Ticket 13 premise checks — the vault's git/Syncthing/sensitivity ground truth

Measured 2026-08-24 on krypton, before the grilling. Every fact below is
re-runnable; the command is given.

## P1 — "Pushing a Syncthing-replicated git repo is a known-bad shape" → **VOID**

`~/vault/.stignore` excludes `.git` explicitly, with the reason in a comment:

```
$ head -3 ~/vault/.stignore
// Keep the local git repo off Syncthing — avoids .sync-conflict churn on .git
// and keeps history on krypton only (phone/titan don't need it).
.git
```

So there is **no replicated `.git`** and never was — the index/lock race the
ticket feared cannot occur. Only krypton has history; the other peers hold a
working tree only.

Topology also corrected — the ticket inherited a stale peer list:

```
$ python3 - <<'PY'  # parse ~/.local/state/syncthing/config.xml
devices: {'BIAYWY6': 'helium', 'HOB72FX': 'krypton', 'TQMNB3R': 'CPH2581 phone'}
personal-vault /home/ms/vault -> ['helium', 'krypton', 'CPH2581 phone']
PY
```

**titan is gone; helium is the third peer** (vault-serve issue 004 — helium is a
Send-Receive replica at `/data/ssd/vault`).

The vault also runs **three live git worktrees** under `.claude/worktrees/`
(`git -C ~/vault worktree list`), and `.claude` is Syncthing-excluded too.

## P1b — the real single-copy gap (not the one the ticket named)

- **Working tree:** 3 copies (krypton, helium, phone). Syncthing is replication,
  not backup — a delete propagates — but `.stversions` gives a window.
- **Git history: exactly ONE copy.** 313 commits / 14 MB, krypton only
  (`git -C ~/vault rev-list --count HEAD` → 313; `du -sh .git` → 14M).
- **helium's restic does not cover it.** `restic-backup.service` backs up
  `/data/ssd/appdata` only; the vault replica is a *different* subvolume
  (`/data/ssd/vault`) and there is no `restic-vault` unit — only
  `restic-backup`, `restic-immich`, `restic-paperless` exist
  (`ls ansible/roles/restic_backup/files/systemd/`).

So option C's stated motive ("addresses a real gap") is **confirmed and is
specifically about history**, not about the files.

## P2 — "Is `finance-rebuild` different in kind?" → **mis-aimed, and moot**

Two findings.

**(a) `finance-rebuild` is not the sensitive one.** The vault's data-sensitivity
fence is `.gitignore`, and it fences `finance/` (the engine + DB + reports) —
**not** `projects/finance-rebuild/`, which is design discussion. The sharp
content is elsewhere and is **already tracked in git**
(`git check-ignore -v` returns nothing for these; 40 tracked files across the
three dirs):

- `projects/vardepapperskredit/` — real mortgage figures: *"His share: 1 045 250 kr
  debt against a 1 690 000 kr valuation ≈ 62% LTV"*, a −20 861 kr 27-month
  surplus, and *"`debt_collection` is 19 614 kr across 14 events"*.
- `projects/strength-and-weight/` — body weight (~106 kg) and **medical treatment
  history** (long-term steroid treatment as the driver), i.e. special-category
  health data. Its `photos/` subdir is gitignored; the map text is not.

**(b) The "should it sit in a service at all" discriminator is already spent.**
The sibling map `planning/vault-serve/` decided the **whole vault physically sits
on helium** via Syncthing — *"incl. finance/health/people/journal — accepted,
since helium already holds Immich photos + Paperless docs, so it's not a new
sensitivity class"*. helium already stores all of this in plaintext today.

**What is genuinely new under any Forgejo option** is therefore not the box, it
is **git history + a remote**. The vault's own `.gitignore` header states the
rule and pre-writes the chore:

```
# Local-only git for the personal vault — audit trail + undo for LLM-maintained edits.
# NO remote: the vault holds bank data and personal records. Before any
# `git remote add` / push, audit history for secrets first.
```

and `projects/vault-tools/decisions.md` **D7** makes it a recorded decision:
*"the sensitive-data boundary is **git/remotes, not the phone** … the repo is
local-only, never pushed to any remote."* Option C overturns D7 and inherits its
history audit over 313 commits; option A does not touch the vault repo at all.

## P3 — "What does `bin/wf` do today, and what would each option cost it?" → **already done**

`bin/wf` (654 lines, read-only) **already supports both layouts and both
dialects**, auto-detected per file:

```
$ sed -n 7,12p bin/wf
Two on-disk dialects are supported and auto-detected per file:

  prose      `Type:` / `Status:` / `Blocked by:` lines under the `# Title`
             (~/.dotfiles/planning, ~/notes/.scratch)
  frontmatter  YAML `label: wayfinder:<type>` / `status:` / `blocked-by: [1, 2]`
             (~/vault/projects/*/tickets)
```

`ROOTS = ["~/.dotfiles/planning", "~/vault/projects", "~/notes/.scratch"]` and
`TICKET_DIRS = ("issues", "tickets")`. So:

- The vault is **already a first-class `wf` root** — nothing is owed to it.
- Ticket 07's "gains a Forgejo dialect" would be a **third** dialect, not a
  second, and it is needed for `~/.dotfiles` regardless of what 13 decides.
- Under **A**, the *frontmatter* dialect could eventually be retired (the vault
  is its only user); under **B/C** it stays, and `wf` keeps working unchanged.
- `~/notes/.scratch` (the **work** vault) is a fourth root, out of scope here,
  and it also uses the prose dialect — so retiring dialects is not a clean win.

Layout caveat from the ticket stands: 11 project dirs, only 5 with `tickets/` +
`map.md`; the other six (`3d-printing`, `homelab`, `msbrain`, `next-daily-car`,
`vault-split`, `vault-tools`) have neither, and `projects/` also holds loose
single-file notes (`retirement.md`, `laptop-search.md`, …).
