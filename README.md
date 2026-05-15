# Configs

Personal workstation dotfiles and a bash-based installer for Debian/Ubuntu.

## Quick start (fresh machine, nothing installed)

```bash
wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash
# then, when bootstrap prints the next step:
cd ~/.dotfiles && ./install.sh --dry-run   # preview
cd ~/.dotfiles && ./install.sh             # apply
```

`bootstrap.sh` does prep only: it `apt install`s `git` and `curl`, clones
this repo to `~/.dotfiles`, runs the `ssh` module so `authorized_keys` is
in place, then **stops and prints the next step**. You run `install.sh`
yourself — that lets you dry-run, pick a module subset, or eyeball the
changes before applying. (`wget` is used for the curl-pipe because a
minimal Debian install ships it but not `curl`.) If this machine's
hostname doesn't have `hosts/<hostname>/modules.conf` yet, the conservative
`hosts/default/` profile is used — create a per-host file afterwards to
tailor the machine (sway stack, battery-guardian on laptops, etc.).

## Already have the repo

```bash
cd ~/.dotfiles && ./install.sh
```

`install.sh` reads `hosts/$(hostname -s)/modules.conf` and runs each listed
module from `modules/<name>/install.sh`. Re-running is safe; every module is
idempotent.

## Layout

```
bootstrap.sh            # curl-pipe entry point: apt + clone + ssh keys, then prints next step
install.sh              # module runner (used locally after the repo is cloned)
lib/                    # shared helpers (log, symlink, apt, platform)
modules/<name>/         # one install.sh per unit of work
hosts/<hostname>/       # modules.conf per machine
configs/                # the actual dotfiles; modules link these into $HOME
bin/                    # utility scripts; base module links them into ~/.local/bin
servers/<name>/         # runtime artifacts for homelab services (compose, secrets, deploy.sh)
.sops.yaml              # age recipients per servers/<name>/secrets.env path
```

## Flags

```
./install.sh --host NAME          # override hostname
./install.sh --module nvim,bash   # run only those modules
./install.sh --dry-run            # show what would change, touch nothing
```

`bootstrap.sh` does not run `install.sh`; pass flags to `install.sh` directly
in the second step (e.g. `./install.sh --dry-run`).

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

## Homelab

Docker Compose services running on remote hosts live under `servers/<name>/`.
Each server dir contains `docker-compose.yml`, `config.env` (plain, committed),
`secrets.env` (sops-encrypted, committed), and `deploy.sh` (decrypts secrets to
a tmpfile, runs compose).

### Deploying

Pushing to a server's `deploy` remote triggers its post-receive hook, which
checks the working tree out into `/opt/<name>/` and runs `deploy.sh`:

```bash
git push <name> main
```

Currently provisioned: `jellyfin`. See `servers/home-assistant/` for Home
Assistant — HAOS is managed via REST/WS, not git-push (see
`servers/home-assistant/AGENTS.md`).

### Secrets (sops + age)

Per server:
- `servers/<name>/config.env` — plain, committed
- `servers/<name>/secrets.env` — sops-encrypted, committed

`deploy.sh` decrypts `secrets.env` to a tmpfile and passes both files to
`docker compose` via `--env-file`. `.sops.yaml` lists each admin's age public
key plus the per-server age key; everyone listed can decrypt, nobody else.

Edit a secret:

```bash
sops servers/<name>/secrets.env                            # opens $EDITOR
sops set servers/<name>/secrets.env '["KEY"]' '"value"'    # non-interactive
```

First-time setup on a new workstation:

```bash
age-keygen -o ~/.config/sops/age/keys.txt   # generate
# add the printed public key to .sops.yaml under `keys:` as a new admin anchor
# and include it in each creation_rule's age: list, then re-encrypt existing files:
sops updatekeys servers/<name>/secrets.env
```

Back up `~/.config/sops/age/keys.txt` — losing it locks you out of everything
encrypted to it.

### Adding a new server

1. Provision the host (currently via `ansible/` in `~/projects/homelab-stack.archived`; porting to dotfiles modules is in progress).
2. Append the server's age public key and a matching `creation_rule` to `.sops.yaml`.
3. `mkdir servers/<name>`, add `docker-compose.yml`, `config.env`, `deploy.sh` (copy from `servers/jellyfin/`).
4. Create secrets: `sops servers/<name>/secrets.env`.
5. Add the deploy remote and push:
   ```bash
   git remote add <name> deploy@<host>:homelab.git
   git push <name> main
   ```
