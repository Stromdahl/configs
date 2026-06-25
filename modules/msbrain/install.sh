#!/usr/bin/env bash
# msbrain — the autonomous personal-assistant agent (code lives in the separate
# ~/projects/msbrain repo, ADR 0006). This module is the *deploy* side on the host:
# it installs the systemd --user units that schedule the email pipeline. krypton is the
# interim host (ADR 0005); the host is fungible, so the units live here and a titan
# migration is a re-provision, not a rebuild.
#
# The email-ingest timer is deliberately DISABLED by default. Installing only places +
# daemon-reloads the units; it does NOT enable or start the ingest. Reasons:
#   - the timer drives an autonomous claude -p run that bills (krypton interim: the
#     company Claude subscription via the unit's MSBRAIN_AUTH=oauth + oauth-token.env,
#     ADR 0002 interim exception; personal key is the titan target) and reads the real
#     mailbox — never auto-armed by a provision;
#   - activation is an explicit owner step (printed below).
#
# Proton Bridge is NOT managed here. On krypton it runs as a SESSION app (the logged-in
# Bridge GUI/tray), because the headless --noninteractive service could not retain the
# interactive-login session (it dropped to "user not connected" on handoff). That fits
# ADR 0005: krypton is a laptop, the pipeline runs while the owner is logged in. The
# ingest unit just waits for Bridge's local IMAP (ExecStartPre) and fails fast if it
# isn't up. A true headless Bridge (dedicated user + pass) is a titan-era job.
#
# Depends on: claude module (the CLI), python, and the Proton Bridge app (run in-session,
# logged in). No apt package of its own.
set -euo pipefail

# The runtime config dir (~/.config/msbrain) holds SECRETS — the Bridge IMAP password
# (proton-bridge.env), its cert, and the autonomous-layer token (oauth-token.env). Those
# are NEVER tracked in dotfiles. Only ensure the dir exists, locked down; never clobber it.
cfg="$HOME/.config/msbrain"
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: mkdir -p $cfg (mode 0700)"
else
  mkdir -p -- "$cfg"
  chmod 700 -- "$cfg"
fi

# systemd --user units (linked individually; do not link the whole configs dir over
# ~/.config/msbrain — that would collide with the secrets above).
link "configs/msbrain/msbrain-email-ingest.service" "$HOME/.config/systemd/user/msbrain-email-ingest.service"
link "configs/msbrain/msbrain-email-ingest.timer"   "$HOME/.config/systemd/user/msbrain-email-ingest.timer"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo loginctl enable-linger $USER (if not already)"
  info "would: systemctl --user daemon-reload"
  info "would NOT enable/start anything (timer disabled by default — see header)"
  exit 0
fi

# Linger so the Persistent timer can catch up at boot. Idempotent: only flip it (the one
# sudo here) when it isn't already on.
if [[ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != yes ]]; then
  sudo loginctl enable-linger "$USER"
fi

systemctl --user daemon-reload
ok "msbrain units installed (timer disabled): msbrain-email-ingest.{service,timer}"

# Activation is intentionally manual — see header. Surface the steps without doing them.
info "to go live (owner steps):"
info "  1. mail source     → start the Proton Bridge app in your session and log in; leave it running"
info "  2. auth (optional) → claude setup-token (company acct) into ~/.config/msbrain/oauth-token.env"
info "                       (else the unit's oauth mode falls back to your stored login)"
info "  3. test one run    → systemctl --user start msbrain-email-ingest.service"
info "                       journalctl --user -u msbrain-email-ingest.service -n50"
info "  4. arm daily ingest→ systemctl --user enable --now msbrain-email-ingest.timer"
