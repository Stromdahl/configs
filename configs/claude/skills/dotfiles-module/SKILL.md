---
name: dotfiles-module
description: Use when adding a new module to the ~/.dotfiles dotfiles repo — i.e. the user wants to install or configure a new tool, package, or set of config files through the dotfiles module system (a modules/<name>/install.sh plus configs/<name>/ artifacts, opted into per host via hosts/<host>/modules.conf). Scaffolds a correctly-shaped module from the right archetype and wires it in. Do NOT use for editing an existing module's behaviour, for the servers/ docker-compose stack, or outside the dotfiles repo.
---

# Add a dotfiles module

Scaffolds a new `modules/<name>/` in the `~/.dotfiles` repo following the
repo's conventions, then leaves you to fill in the specifics.

The full contract lives in the repo's `AGENTS.md` (§"Contracts every module must
honor", §"Reference patterns") and is auto-loaded when working here — this skill
operationalizes it; it does not restate it. Read those sections if unsure.

## When this fires

The user wants a new tool/package/config managed by the dotfiles, e.g. "add a
module for <tool>", "manage <tool>'s config through dotfiles", "install <tool> on
krypton via the dotfiles".

## Procedure

1. **Pick the archetype** that matches what the tool needs. Confirm with the user
   if ambiguous; default to the simplest that fits.

   | archetype | use when | reference module |
   |-----------|----------|------------------|
   | `pkg` | just an apt package, no config | `modules/microcode` |
   | `pkg-snippet` | package + a `~/.bashrc.d` shell snippet (env/aliases/init) | `modules/docker` |
   | `config-file` | package + one config file linked into place | `modules/sway` |
   | `config-dir` | package + a whole config directory (add a snippet by hand if needed) | `modules/yazi` |
   | `external` | installed via an upstream installer, not apt | `modules/node` |
   | `system` | files into `/etc` via `sudo install`, manual `cmp -s` idempotency | `modules/unattended-upgrades` |

2. **Run the scaffolder** (it refuses to clobber an existing module or configs dir):

   ```bash
   bash ~/.claude/skills/dotfiles-module/scaffold.sh <name> <archetype>
   ```

   It creates `modules/<name>/install.sh` (executable) from the archetype, stubs
   `configs/<name>/` where the archetype needs it, and prints the remaining steps.

3. **Fill in the TODOs.** Open the generated `install.sh` and the matching
   reference module side by side, and replace the placeholders with the real
   package name(s), config paths, and description. Keep it `set -euo pipefail`,
   idempotent, and `DRY_RUN`-honoring (see `AGENTS.md`). Put real config content
   under `configs/<name>/`.

4. **Wire it into a host.** Add the `<name>` line to the relevant
   `hosts/<host>/modules.conf` (krypton is the interactive workstation). Order
   matters; group it under a fitting comment heading.

5. **Verify**, the repo's only correctness check:

   ```bash
   cd ~/.dotfiles && ./install.sh --module <name> --dry-run   # then without --dry-run
   ```

## Notes

- One file per module dir (`install.sh` only); all artifacts go in `configs/<name>/`.
- Don't re-source `lib/*.sh` — `link`, `apt_ensure`, `info`/`ok`/`warn`/`err`,
  `require_debian` are already in the module subshell's environment.
- Shell snippets: `configs/<name>/<name>.sh` → `~/.bashrc.d/<name>.sh` (sourced
  alphabetically). Keep the snippet out of any `~/.config/<name>/` dir.
