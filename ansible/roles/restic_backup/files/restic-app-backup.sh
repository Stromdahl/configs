#!/usr/bin/env bash
# restic-app-backup — back up one Postgres-backed app (Immich or Paperless) into
# the SHARED restic repo issue 016 built, under a per-app tag so retention/prune
# rolls independently of the 'appdata' tag (issue 026).
#
#   Usage: restic-app-backup <immich|paperless>
#
# Invoked by restic-immich.service / restic-paperless.service, each on its own
# staggered timer. NOT the appdata slice — that stays in restic-backup.service.
#
# Why a script (vs 016's inline-ExecStart units): each app needs an ORDERED,
# multi-step pipeline that does not fit a static ExecStart line —
#   1. a CONSISTENT logical DB dump via `docker exec ... pg_dump` (a transaction-
#      consistent snapshot, NOT a file-level copy of the live PGDATA, which can
#      be torn and unrestorable),
#   2. a single restic backup of (dump + file libraries) under the app tag,
#   3. a per-tag forget/prune,
# with `set -o pipefail` (so a pg_dump failure fails the unit -> OnFailure alert)
# and a trap that guarantees the plaintext dump never lingers on disk.
#
# The hardcoded paths/creds below MUST match host_vars/helium/vars.yml
# (immich_upload_location, paperless_data_root, restic_repo_path,
# restic_password_file) and the container_name: values in
# roles/compose_stack/templates/docker-compose.yml.j2 — the same static-file,
# "paths hardcoded, comment says must-match-vars" convention as the 016 /
# SnapRAID / btrfs-scrub units.
set -euo pipefail

# --- shared repo (issue 016), reused verbatim — no new repo, no new secret ---
export RESTIC_REPOSITORY=/mnt/disk1/backups/restic-appdata
export RESTIC_PASSWORD_FILE=/etc/restic/appdata.pass
export RESTIC_CACHE_DIR=/var/cache/restic

# Wait for the repo lock rather than failing if the appdata run (02:00) or the
# other app's run overlaps this one. restic 0.18 (Debian trixie) supports it;
# `restic forget --prune` takes an EXCLUSIVE lock, so overlap is real if a first
# (full) run runs long. The timers are also staggered as the first line of
# defence.
RETRY_LOCK=5m

# Per-tag retention (same policy as the 016 appdata unit). Because forget is
# scoped to --tag <app>, each app's snapshots roll independently.
KEEP=(--keep-daily 7 --keep-weekly 4 --keep-monthly 6)

STAGING_ROOT=/var/backups/restic-staging

app="${1:?usage: restic-app-backup <immich|paperless>}"

case "$app" in
  immich)
    db_container=immich_postgres          # docker-compose.yml.j2 container_name:
    db_user=postgres                      # IMMICH_DB_USERNAME (host_vars: immich_db_username)
    db_name=immich                        # IMMICH_DB_NAME     (host_vars: immich_db_name)
    # UPLOAD_LOCATION root (immich_upload_location) — holds library/ upload/
    # profile/ thumbs/ encoded-video/. Backed up whole: this trends toward the
    # ONLY copy of the family photos, so err toward completeness. (thumbs/ +
    # encoded-video/ are regenerable and could be excluded to shrink the repo,
    # but Immich must recompute them, so they are kept.)
    library_paths=(/data/ssd/immich/library)
    ;;
  paperless)
    db_container=paperless_postgres       # docker-compose.yml.j2 container_name:
    db_user=paperless                     # PAPERLESS_DB_USERNAME (host_vars: paperless_db_username)
    db_name=paperless                     # PAPERLESS_DB_NAME     (host_vars: paperless_db_name)
    # media/ = document originals + archive + thumbnails (irreplaceable scans);
    # data/  = search index + classification model (regenerable, but small — a
    # restore can `document_index reindex` if stale). paperless_data_root.
    library_paths=(/data/ssd/paperless/media /data/ssd/paperless/data)
    ;;
  *)
    echo "restic-app-backup: unknown app '$app' (want immich|paperless)" >&2
    exit 64
    ;;
esac

tag="$app"
stage_dir="$STAGING_ROOT/$app"
dump="$stage_dir/$app-database.sql.gz"

install -d -m 0700 "$stage_dir"

# The plaintext DB dump only belongs INSIDE the encrypted repo — wipe it on every
# exit (success or failure) so it never lingers on the OS disk.
cleanup() { rm -f "$dump"; }
trap cleanup EXIT

# 1. Consistent logical DB dump. `docker exec` WITHOUT -t: a pseudo-TTY would
#    inject CR and corrupt the piped SQL. Immich's officially documented flags
#    (--clean --if-exists); Paperless uses the same shape. The vector-extension
#    search_path rewrite is a RESTORE-time step (see the issue-026 runbook), not
#    a dump-time one. pipefail makes a pg_dump failure fail the whole unit.
docker exec "$db_container" \
  pg_dump --clean --if-exists --dbname="$db_name" --username="$db_user" \
  | gzip >"$dump"

# 2. One snapshot per run = the DB dump + the file libraries, under the app tag.
restic backup --retry-lock "$RETRY_LOCK" --tag "$tag" --exclude-caches \
  "$dump" "${library_paths[@]}"

# 3. Per-tag retention/prune — independent of the appdata tag.
restic forget --retry-lock "$RETRY_LOCK" --tag "$tag" "${KEEP[@]}" --prune
