# Inventory the hermes/briefings branch: what survives, what is superseded

Type: task
Status: open

## Question

Branch **`hermes/briefings`** (commit `abb62a6`, never merged) holds ~740 lines of
already-debugged Hermes config that `4ed7e63` deleted from `main`. Establish
**what is still valuable, what v0.19 supersedes, and what was always wrong** — so
later tickets *reuse* rather than rewrite, and so nothing carries a known bug
forward.

This is a task, not a decision: nothing to choose, but tickets `03`–`08` are all
cheaper once it's done, and at least one item on the branch is known-harmful.

### The inventory

Files deleted from `main` by `4ed7e63`, recoverable from the branch:

- `configs/hermes-agent/SOUL.md` — the exec-assistant persona. Note the *original*
  `~/.hermes/SOUL.md` on titan was **empty/default**; this file is the replacement
  that was written and deployed live.
- `configs/hermes-agent/morning_briefing.sh` (122 lines) + `morning-briefing.prompt.{md,txt}`
- `configs/hermes-agent/weekly_briefing.sh` (65 lines) + `weekly-briefing.prompt.txt`
- `configs/hermes-agent/env.example`
- `configs/hermes-agent/vault-skeleton/` — `System/Assistant/{context,environment,preferences}.md`,
  `logs/issues-fixes-log.md`, `People/MOC.md`
- `configs/hermes-agent/README.md`
- `modules/hermes-agent/install.sh`, `modules/hermes-vault/install.sh`
- `bin/hermes-vault-ensure-marker.sh` (39 lines) +
  `configs/hermes-vault/systemd/hermes-vault-marker.{path,service}`
- `hosts/titan-hermes-agent/{modules.conf,HARDWARE.md}`

### What the answer must judge, per item

- **Keep as-is / adapt / discard**, with the reason.
- **Superseded by v0.19 built-ins?** The briefing scripts in particular exist
  because v0.14 had no usable scheduling or memory. If Automation Blueprints and
  persistent memory now cover it, these scripts are *anti-value* — they'd
  reintroduce the scaffolding this map is trying to shed.
- **Does it encode a known defect?** Specifically: the *original* briefing stub had
  **hardcoded fake weather** and a static home-maintenance echo; the `abb62a6`
  rewrite fixed that (real HA weather via `HASS_*`, per-source `STATUS=OK/ERROR`).
  Confirm which behaviour each recovered file actually contains before reusing it —
  the per-source `STATUS=OK/ERROR` pattern is directly reusable by ticket `05`.
- **Vault-structure assumptions are stale.** The scripts target the *old* separate
  `~/hermes-vault` (`Areas/Health/Medication.md`, `~/Health/Medication.md`) — that
  folder is gone and `~/vault` has a different shape (`health/`, no `Areas/`). Any
  path in these files is suspect.
- **`hosts/titan-hermes-agent/` is dead** (titan is decommissioned) but its
  `modules.conf` documents the working module set — worth reading, not resurrecting.
- **The marker-guard unit** (`hermes-vault-ensure-marker.sh` + path/service) is
  cheap insurance worth keeping even if the memory-out-of-vault redesign means it
  should never fire. Note that it was **gated to hosts with `~/.hermes`** and is a
  *user* systemd unit — both facts constrain ticket `03`.

Record the verdict table in the resolution. Do not merge the branch; this is a
read-and-judge pass. Note also that the branch's dotfiles-module shape assumed a
`install.sh`-managed host — helium is **ansible-only**, so module code is
reference, not reusable as-is.
