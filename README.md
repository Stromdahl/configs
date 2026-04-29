# Configs

Personal workstation dotfiles and a bash-based installer for Debian/Ubuntu.

## Quick start (fresh machine, nothing installed)

```bash
wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
```

`bootstrap.sh` is the fetch-and-pipe entry point: it `apt install`s `git`,
clones this repo to `~/.dotfiles`, then hands off to `install.sh`. (`wget`
is used because a minimal Debian install ships it but not `curl`.) If this
machine's hostname doesn't have `hosts/<hostname>/modules.conf` yet, the
conservative `hosts/default/` profile is used for the first run — create a
per-host file afterwards to tailor the machine (sway stack, battery-guardian
on laptops, etc.).

## Already have the repo

```bash
cd ~/.dotfiles && ./install.sh
```

`install.sh` reads `hosts/$(hostname -s)/modules.conf` and runs each listed
module from `modules/<name>/install.sh`. Re-running is safe; every module is
idempotent.

## Layout

```
bootstrap.sh            # curl-pipe entry point: apt + clone, then calls install.sh
install.sh              # module runner (used locally after the repo is cloned)
lib/                    # shared helpers (log, symlink, apt, platform)
modules/<name>/         # one install.sh per unit of work
hosts/<hostname>/       # modules.conf per machine
configs/                # the actual dotfiles; modules link these into $HOME
bin/                    # utility scripts; base module links them into ~/.local/bin
```

## Flags

```
./install.sh --host NAME          # override hostname
./install.sh --module nvim,bash   # run only those modules
./install.sh --dry-run            # show what would change, touch nothing
```

`bootstrap.sh` forwards any flags to `install.sh`, so e.g.
`wget -qO- ... | bash -s -- --dry-run` works.

## Adding a new host

```bash
mkdir -p hosts/<hostname>
cp hosts/krypton/modules.conf hosts/<hostname>/modules.conf
# trim to what this host needs (e.g. drop battery-guardian on a desktop)
./install.sh
```

## Adding a new module

1. `mkdir modules/<name> && $EDITOR modules/<name>/install.sh`
2. Start with:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   apt_ensure pkg1 pkg2
   link "configs/<name>/..." "$HOME/.config/<name>/..."
   ```
3. Add `<name>` to the hosts that want it.

Helpers available in every module (sourced by `install.sh`): `info`, `ok`,
`warn`, `err`, `die`, `link`, `apt_ensure`, `apt_installed`. `DRY_RUN=1`
is honored automatically by `link` and `apt_ensure`.

### Shell snippets (~/.bashrc.d)

`~/.bashrc.d/*.sh` is sourced at the end of `bashrc` (alphabetical order).
Tools that need shell-side setup — env vars, completions, aliases, helper
functions — drop a snippet there instead of bloating `bashrc`. The bash
module pre-creates the directory; per-tool modules link their snippet:

```bash
# configs/<name>/<name>.sh — sourced into the user's shell
alias something='...'
export FOO=bar
```

```bash
# modules/<name>/install.sh
apt_ensure <pkg>
link "configs/<name>/<name>.sh" "$HOME/.bashrc.d/<name>.sh"
```

See `modules/{node,rust,fzf,git,docker,...}/` for examples. If a module
also ships a runtime config dir (e.g. yazi), keep them separate:
`configs/<name>/config/` for the dir, `configs/<name>/<name>.sh` for the
snippet, so the snippet doesn't leak into `~/.config/<name>/`.
