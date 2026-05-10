# AGENTS.md

Guidance for AI coding agents (Claude Code, etc.) working in this repository.

## Repository purpose

Personal Debian/Ubuntu workstation dotfiles plus a small bash installer.
`README.md` covers the user-facing flow (quick start, flags, adding a host);
this file covers the contributor-facing implementation details and the
contracts new code must honor.

## Common commands

There is no build step, no test runner, and no linter wired up. Verification
is done by re-running with `--dry-run`.

- `./install.sh` — apply the current host's modules.
- `./install.sh --dry-run` — preview every change; touches nothing. Primary correctness check.
- `./install.sh --module <a,b>` — run a comma-separated subset, ignoring the host's `modules.conf`.
- `./install.sh --host <name>` — apply another host's profile (useful for testing).
- `./install.sh --module <name> --dry-run` — fastest feedback loop while iterating on a single module.

Scripts carry `# shellcheck source=...` directives but `shellcheck` is not
invoked automatically anywhere; running it manually is fine but not required.

## Architecture (the non-obvious shape)

Four layers, top-down:

1. **`bootstrap.sh`** — fresh-machine prep. apt-installs `git` + `curl`, clones the repo to `~/.dotfiles`, runs `install.sh --module ssh` so `authorized_keys` is in place for future SSH sessions, then **stops and prints the `install.sh` command for the user to run**. Does NOT run the main install — that's an explicit second step so the user can dry-run or review first. Uses `wget` for the curl-pipe because a minimal Debian image ships `wget` but not `curl`.
2. **`install.sh`** — the orchestrator. Resolves and exports `DOTFILES_ROOT`, sources every `lib/*.sh` once, parses flags, selects the module list from `hosts/<hostname>/modules.conf` (falling back to `hosts/default/modules.conf` with a warning), then runs each `modules/<name>/install.sh` **in a subshell** with `LOG_PREFIX=<name>` set. Continues past a failed module but exits non-zero overall if any failed.
3. **`modules/<name>/install.sh`** — one unit of work per tool/feature. A module directory contains only this single file; config files, snippets, and other artifacts live under `configs/<name>/`.
4. **`lib/`** — helpers sourced once by `install.sh` and inherited by every module's subshell:
   - `log.sh` — `info`, `ok`, `warn`, `err`, `die`, `dim`, `section` (color output, prefixed by `LOG_PREFIX`).
   - `platform.sh` — `require_debian`, `require_cmd <cmd...>`.
   - `symlink.sh` — `link <src> <dst>`. Relative `src` is resolved against `$DOTFILES_ROOT`. If `dst` is a real file/dir (not a matching symlink), it is moved to `<dst>.backup-<timestamp>` before the symlink is created. Honors `DRY_RUN`.
   - `apt.sh` — `apt_ensure <pkg...>` (installs only the missing ones; runs `apt-get update` at most once per `install.sh` invocation via the `$_APT_UPDATED_FLAG` tempfile, which the trap in `install.sh` cleans up). Also `apt_installed <pkg>`. Honors `DRY_RUN`.

`hosts/<hostname>/modules.conf` is a plain ordered list, one module per
line, with `#` comments stripped. Order matters; modules do not declare
dependencies on each other.

`configs/` mirrors the eventual `$HOME` layout but is inert until a module
calls `link` on it. `bin/` holds helper scripts; the `base` module symlinks
them into `~/.local/bin`.

## Contracts every module must honor

- `set -euo pipefail` at the top of `install.sh`.
- **Idempotent.** Re-running must be a no-op when state already matches. `apt_ensure` and `link` already enforce this; custom logic should `cmp -s` / `readlink` before mutating (see `modules/unattended-upgrades/install.sh` for the pattern).
- **Honor `DRY_RUN=1`.** `apt_ensure` and `link` honor it automatically. Any other side-effecting command (downloads, `sudo install`, external installers) must guard itself:
  ```bash
  if [[ "${DRY_RUN:-0}" == 1 ]]; then info "would: …"; exit 0; fi
  ```
- Exit 0 on success even when nothing changed; non-zero on failure.
- Do not re-source `lib/*.sh` — the helpers are already in the subshell's environment.
- Use `$DOTFILES_ROOT` (exported by `install.sh`) for any absolute paths into the repo.

## Shell snippet convention

Tools that need shell-side setup (env vars, aliases, completions, init
hooks) ship a snippet at `configs/<name>/<name>.sh` and link it into
`~/.bashrc.d/<name>.sh`. `~/.bashrc` sources `~/.bashrc.d/*.sh`
alphabetically at the end. When a tool also needs a runtime config
directory, keep the two separate — `configs/<name>/config/` for the dir,
`configs/<name>/<name>.sh` for the snippet — so the snippet does not leak
into `~/.config/<name>/`. The bash module pre-creates `~/.bashrc.d/`.

## Adding a new module (recipe)

1. `mkdir modules/<name>` and write `install.sh` (typically `apt_ensure` + one or more `link` calls).
2. Put config files under `configs/<name>/`.
3. Add `<name>` to the relevant `hosts/<hostname>/modules.conf`.
4. Verify with `./install.sh --module <name> --dry-run`, then run without `--dry-run`.

## Reference patterns

When in doubt, copy the closest existing shape:

- `modules/docker/install.sh` — minimal package + shell snippet.
- `modules/sway/install.sh` — package + single config file link.
- `modules/yazi/install.sh` — runtime config dir plus a separate snippet.
- `modules/node/install.sh` — external installer (nvm) with explicit `DRY_RUN` handling.
- `modules/unattended-upgrades/install.sh` — system files in `/etc` via `sudo install`, with a manual `cmp -s` idempotency check.
