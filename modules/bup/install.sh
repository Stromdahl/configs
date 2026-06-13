#!/usr/bin/env bash
# Local versioned backup of ~/notes with bup, on a daily systemd *user* timer.
#
# bup (git-packfile dedup backup) snapshots ~/notes into a local repo at
# ~/backups/bup-notes. This guards against accidental deletion / corruption:
# the Syncthing share to the phone is replication, not backup (deletes
# propagate, no history). A same-disk repo does NOT protect against drive
# failure / laptop loss; an ssh offsite copy to neon is the planned follow-up
# (see the configs/bup/bup-backup.sh header for the one-liner).
#
# Restore (browse, then pull a file or the whole tree):
#   BUP_DIR=~/backups/bup-notes bup ls notes/latest/home/ms/notes
#   BUP_DIR=~/backups/bup-notes bup restore -C /tmp/r notes/latest/home/ms/notes/
#
# No encryption (local repo; the notes are plaintext on the same disk anyway).
# No pruning wired up — at a few MB with dedup the repo grows negligibly; reach
# for `bup rm` + `bup gc` only if it ever warrants it.
set -euo pipefail

apt_ensure bup

link "configs/bup/bup-backup.sh"     "$HOME/.config/bup/bup-backup.sh"
link "configs/bup/bup-notes.service" "$HOME/.config/systemd/user/bup-notes.service"
link "configs/bup/bup-notes.timer"   "$HOME/.config/systemd/user/bup-notes.timer"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  info "would: sudo loginctl enable-linger $USER"
  info "would: systemctl --user daemon-reload && enable --now bup-notes.timer"
  info "would: systemctl --user start bup-notes.service  (first backup)"
  exit 0
fi

# Linger so the timer fires without an active login session and catches up at
# boot. Only flip it (the one sudo this module needs) when it isn't already on,
# so re-runs stay sudo-free.
if [[ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != yes ]]; then
  sudo loginctl enable-linger "$USER"
fi

systemctl --user daemon-reload
systemctl --user enable --now bup-notes.timer
ok "bup-notes.timer enabled (daily)"

# Kick one run now so the repo initialises + a first save lands during install.
# Non-fatal: a first-run hiccup shouldn't fail the whole install.sh. `start` on
# a oneshot blocks until the run finishes and reflects its exit status.
if systemctl --user start bup-notes.service; then
  ok "bup: first backup done (journalctl --user -u bup-notes.service)"
else
  warn "bup: first backup failed; see journalctl --user -u bup-notes.service"
fi
