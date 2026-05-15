#!/usr/bin/env bash
# Server-side bare git repo + sparse-checkout post-receive hook. Workstation
# pushes to deploy@host:deploy.git; the hook materializes only
# servers/$(hostname -s)/ into /opt/$(hostname -s)/ then runs that server's
# deploy.sh. Generates the deploy user's age key if missing.
#
# Depends on: modules/deploy-user (deploy user must exist) and modules/sops
# (age binary must be on PATH).
set -euo pipefail

readonly DEPLOY_USER="deploy"
readonly BARE_NAME="deploy.git"

if id -- "$DEPLOY_USER" >/dev/null 2>&1; then
  deploy_home="$(getent passwd -- "$DEPLOY_USER" | cut -d: -f6)"
  [[ -n "$deploy_home" ]] || die "could not resolve home dir for $DEPLOY_USER"
elif [[ "${DRY_RUN:-0}" == 1 ]]; then
  warn "user '$DEPLOY_USER' missing — modules/deploy-user would create it first; using /home/$DEPLOY_USER for dry-run"
  deploy_home="/home/$DEPLOY_USER"
else
  die "user '$DEPLOY_USER' missing — modules/deploy-user must run first"
fi

bare="$deploy_home/$BARE_NAME"
hook_src="$DOTFILES_ROOT/configs/bare-git-repo/post-receive"
deploy_dir="/opt/$(hostname -s)"

# 1) bare repo
if sudo test -d "$bare/objects" 2>/dev/null; then
  ok "bare repo present: $bare"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: sudo -u $DEPLOY_USER git init --bare $bare"
  else
    sudo -u "$DEPLOY_USER" git init --bare -- "$bare"
    ok "initialized: $bare"
  fi
fi

# 2) /opt/<hostname>/
if [[ -d "$deploy_dir" ]]; then
  ok "deploy dir present: $deploy_dir"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would: install -d -m 0755 -o $DEPLOY_USER -g $DEPLOY_USER $deploy_dir"
  else
    sudo install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" -- "$deploy_dir"
    ok "created: $deploy_dir"
  fi
fi

# 3) post-receive hook
hook_dst="$bare/hooks/post-receive"
if sudo test -f "$hook_dst" 2>/dev/null && sudo cmp -s -- "$hook_src" "$hook_dst" 2>/dev/null; then
  ok "post-receive hook already current"
else
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install: $hook_src -> $hook_dst (mode 0755, owner $DEPLOY_USER)"
  else
    sudo install -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" -- "$hook_src" "$hook_dst"
    ok "installed post-receive hook"
  fi
fi

# 4) deploy user's age key (deploy.sh needs sops -d to decrypt secrets.env)
deploy_age_dir="$deploy_home/.config/sops/age"
deploy_age_key="$deploy_age_dir/keys.txt"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: ensure $deploy_age_dir (0700, $DEPLOY_USER), generate $deploy_age_key if missing"
  exit 0
fi

sudo install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" -- "$deploy_age_dir"

if sudo test -s "$deploy_age_key" 2>/dev/null; then
  ok "deploy age key present at $deploy_age_key"
else
  command -v age-keygen >/dev/null 2>&1 || die "age-keygen missing — modules/sops must run first"
  # age-keygen -o writes the (private) key to the file; only the public key
  # appears on stderr. Capture stderr so the public key shows in the install
  # log, then re-prompt the operator to update .sops.yaml.
  sudo -u "$DEPLOY_USER" age-keygen -o "$deploy_age_key" 2>&1 >/dev/null | sed 's/^/    /' >&2
  sudo chmod 0600 -- "$deploy_age_key"
  pub="$(sudo grep '^# public key:' -- "$deploy_age_key" | sed 's/^# public key: *//')"
  ok "generated deploy age key at $deploy_age_key"
  warn ""
  warn "ADD TO .sops.yaml ON THE ADMIN WORKSTATION:"
  warn "  keys:"
  warn "    - &server_$(hostname -s) $pub"
  warn "  (and include &server_$(hostname -s) in each relevant creation_rule's age: list)"
  warn ""
  warn "Then re-encrypt: sops updatekeys servers/$(hostname -s)/secrets.env"
  warn ""
fi
