#!/usr/bin/env bash
# msbrain — the autonomous personal-assistant agent (code lives in the separate
# ~/projects/msbrain repo, ADR 0006). This module is the *deploy* side on the host:
# it installs the systemd --user units that schedule the pipelines and run the local
# Proton Bridge. krypton is the interim host (ADR 0005); the host is fungible, so the
# units live here and a titan migration is a re-provision, not a rebuild.
#
# The email-ingest timer is deliberately DISABLED by default. Installing only places +
# daemon-reloads the units; it does NOT enable or start the ingest. Reasons:
#   - the timer drives an autonomous claude -p run that bills the personal API key
#     (ADR 0002) and reads the real mailbox — never auto-armed by a provision;
#   - it fails closed until the personal key is provisioned (model-governance.md §4 / D1).
# Activation is an explicit owner step (printed below).
#
# protonmail-bridge.service is the exception: it was already hand-enabled during Epic C
# and is safe to autostart (Bridge uses a file-based vault, not the OS keyring, so it
# runs detached at boot under linger). This module just brings its unit under dotfiles
# management (content-identical) so a re-provision restores it; its enabled state is
# preserved, not changed.
#
# Depends on: claude module (the CLI), python, and protonmail-bridge (installed
# separately; account already logged in). No apt package of its own.
set -euo pipefail

# The runtime config dir (~/.config/msbrain) holds SECRETS — the Bridge IMAP password
# (proton-bridge.env), its cert, and the personal API key (anthropic.env). Those are
# NEVER tracked in dotfiles. Only ensure the dir exists, locked down; never clobber it.
cfg="$HOME/.config/msbrain"
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: mkdir -p $cfg (mode 0700)"
else
  mkdir -p -- "$cfg"
  chmod 700 -- "$cfg"
fi

# systemd --user units (linked individually; do not link the whole configs dir over
# ~/.config/msbrain — that would collide with the secrets above).
link "configs/msbrain/protonmail-bridge.service"   "$HOME/.config/systemd/user/protonmail-bridge.service"
link "configs/msbrain/msbrain-email-ingest.service" "$HOME/.config/systemd/user/msbrain-email-ingest.service"
link "configs/msbrain/msbrain-email-ingest.timer"   "$HOME/.config/systemd/user/msbrain-email-ingest.timer"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo loginctl enable-linger $USER (if not already)"
  info "would: systemctl --user daemon-reload"
  info "would NOT enable/start anything (disabled by default — see header)"
  exit 0
fi

# Linger so the units can run without an active login session and the timer catches
# up at boot. Idempotent: only flip it (the one sudo here) when it isn't already on.
if [[ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != yes ]]; then
  sudo loginctl enable-linger "$USER"
fi

systemctl --user daemon-reload
ok "msbrain units installed (disabled): protonmail-bridge.service, msbrain-email-ingest.{service,timer}"

# Activation is intentionally manual — see header. Surface the steps without doing them.
info "to go live (owner steps):"
info "  1. provision the personal key  → msbrain repo docs/model-governance.md §4 (D1)"
info "  2. mail source (already enabled)→ systemctl --user start protonmail-bridge.service  (runs now; autostarts at boot)"
info "  3. test one run by hand first   → systemctl --user start msbrain-email-ingest.service"
info "                                     journalctl --user -u msbrain-email-ingest.service -n50"
info "  4. arm the daily ingest         → systemctl --user enable --now msbrain-email-ingest.timer"
