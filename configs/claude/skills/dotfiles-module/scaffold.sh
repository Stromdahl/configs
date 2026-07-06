#!/usr/bin/env bash
# Scaffold a new dotfiles module from an archetype. Companion to the
# `dotfiles-module` skill. Creates modules/<name>/install.sh (executable) and
# stubs configs/<name>/ where the archetype needs it, then prints next steps.
# Refuses to clobber an existing module or configs dir. Honors the repo
# conventions in AGENTS.md.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: scaffold.sh <name> <archetype>

  <name>       kebab-case module id (also the modules/ and configs/ dir name)
  <archetype>  one of:
                 pkg          apt package only
                 pkg-snippet  package + ~/.bashrc.d/<name>.sh snippet
                 config-file  package + one linked config file
                 config-dir   package + a linked config directory
                 external     upstream installer (not apt), DRY_RUN-guarded
                 system       files into /etc via sudo install (cmp -s idempotent)
USAGE
}

[[ $# -eq 2 ]] || { usage; exit 2; }
name="$1"; archetype="$2"

[[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "error: <name> must be kebab-case (got: '$name')" >&2; exit 2; }

case "$archetype" in
  pkg|pkg-snippet|config-file|config-dir|external|system) ;;
  *) echo "error: unknown archetype '$archetype'" >&2; usage; exit 2 ;;
esac

# Resolve the repo root from this script's real (de-symlinked) location:
# configs/claude/skills/dotfiles-module/scaffold.sh  ->  repo root is 4 dirs up.
real="$(readlink -f -- "$0")"
root="$(cd -- "$(dirname -- "$real")/../../../.." && pwd)"
if [[ ! -f "$root/lib/symlink.sh" || ! -d "$root/modules" ]]; then
  root="$HOME/.dotfiles"
fi
[[ -f "$root/lib/symlink.sh" && -d "$root/modules" ]] || {
  echo "error: can't locate the dotfiles repo (looked at $root)" >&2; exit 1; }

moddir="$root/modules/$name"
cfgdir="$root/configs/$name"
[[ -e "$moddir" ]] && { echo "error: module already exists: $moddir" >&2; exit 1; }
[[ -e "$cfgdir" ]] && { echo "error: configs dir already exists: $cfgdir" >&2; exit 1; }

mkdir -p -- "$moddir"
install_sh="$moddir/install.sh"

# Each archetype is written with MODNAME as a placeholder (quoted heredoc keeps
# $HOME / $DOTFILES_ROOT / ${DRY_RUN} literal), then MODNAME is replaced below.
case "$archetype" in
  pkg)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: one-line description — what MODNAME installs.
set -euo pipefail

apt_ensure MODNAME
EOF
    ;;
  pkg-snippet)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: install MODNAME and link its bashrc.d snippet.
set -euo pipefail

apt_ensure MODNAME

link "configs/MODNAME/MODNAME.sh" "$HOME/.bashrc.d/MODNAME.sh"
EOF
    mkdir -p -- "$cfgdir"
    cat > "$cfgdir/$name.sh" <<'EOF'
# shellcheck shell=bash
# MODNAME shell snippet — sourced from ~/.bashrc.d. TODO: env/aliases/init.
EOF
    ;;
  config-file)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: install MODNAME and link its config file.
set -euo pipefail

apt_ensure MODNAME

# TODO: fix the destination path for MODNAME's config file.
link "configs/MODNAME/MODNAME.conf" "$HOME/.config/MODNAME/MODNAME.conf"
EOF
    mkdir -p -- "$cfgdir"
    printf '# TODO: MODNAME config\n' > "$cfgdir/$name.conf"
    ;;
  config-dir)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: install MODNAME and link its config directory.
set -euo pipefail

apt_ensure MODNAME

link "configs/MODNAME" "$HOME/.config/MODNAME"
EOF
    mkdir -p -- "$cfgdir"
    : > "$cfgdir/.gitkeep"
    ;;
  external)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: install MODNAME via its upstream installer (not in apt).
set -euo pipefail

if command -v MODNAME >/dev/null 2>&1; then
  ok "MODNAME already installed"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: run the MODNAME installer"
  exit 0
fi

# TODO: real install steps (download + verify + install). See modules/node.
EOF
    ;;
  system)
    cat > "$install_sh" <<'EOF'
#!/usr/bin/env bash
# TODO: install MODNAME system config into /etc, idempotently.
set -euo pipefail

apt_ensure MODNAME

src="$DOTFILES_ROOT/configs/MODNAME/MODNAME.conf"
dst="/etc/MODNAME/MODNAME.conf"   # TODO: fix destination

if cmp -s -- "$src" "$dst"; then
  ok "MODNAME: /etc config already current"
  exit 0
fi

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo install -D -m 0644 $src $dst"
  exit 0
fi

sudo install -D -m 0644 -- "$src" "$dst"
ok "MODNAME: installed $dst"
EOF
    mkdir -p -- "$cfgdir"
    printf '# TODO: MODNAME /etc config\n' > "$cfgdir/$name.conf"
    ;;
esac

# Substitute the MODNAME placeholder in install.sh and any config stubs created.
files=("$install_sh")
if [[ -d "$cfgdir" ]]; then
  while IFS= read -r -d '' f; do files+=("$f"); done \
    < <(find "$cfgdir" -type f -print0)
fi
sed -i "s/MODNAME/$name/g" "${files[@]}"
chmod +x "$install_sh"

echo "scaffolded module '$name' (archetype: $archetype)"
echo "  created: modules/$name/install.sh"
[[ -d "$cfgdir" ]] && echo "  created: configs/$name/"
echo
echo "next:"
echo "  1. fill in the TODOs in modules/$name/install.sh (and configs/$name/)"
echo "  2. add '$name' to the relevant hosts/<host>/modules.conf"
echo "  3. verify: cd $root && ./install.sh --module $name --dry-run"
