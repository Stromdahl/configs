#!/usr/bin/env bash
# Premise probes for ticket 10 (the `forge sync` contract), run 2026-08-23
# against the ticket-05 prototype (Forgejo 15.0.7, /var/tmp/forgejo-prototype).
#
# Re-run with:   ./10-forge-api-probes.sh
# Prereq: the prototype is up (`curl -s -o /dev/null -w '%{http_code}' http://localhost:3210/`
# returns 200; if not, re-run /var/tmp/forgejo-prototype/build.sh — ticket 05 warns
# the instance dies when its bind mounts sit in a cleaned tmp dir).
#
# Every finding below is a MEASUREMENT, not a doc reading.
set -uo pipefail

P=/var/tmp/forgejo-prototype
API=http://localhost:3210/api/v1
ADMIN=(-u ms:protoforge123)          # created by build.sh
T=$(cat "$P/.token")                 # full-scope token

say() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------------------
# P1. Clone-URL rendering when SSH is NOT on port 22.
# FINDING: ssh_url is the URL form `ssh://git@host:PORT/owner/repo.git`,
#          NOT scp-style `git@host:owner/repo.git`.
#          This is the case helium will be in (helium keeps sshd on 22, so
#          Forgejo's SSH lands elsewhere). Closes ticket 10's explicitly-flagged
#          unverified premise. A port-22 deployment would render scp-style, so a
#          parser should accept both.
# Also visible here: the `archived` and `empty` booleans the contract needs.
# ---------------------------------------------------------------------------
say "P1 clone URLs + archived/empty flags"
curl -s -H "Authorization: token $T" "$API/orgs/projects/repos?limit=50" |
  python3 -c "
import json,sys
for r in json.load(sys.stdin):
    print('%-28s ssh=%-52s http=%-50s archived=%s empty=%s' % (
        r['full_name'], r['ssh_url'], r['clone_url'], r['archived'], r['empty']))
"

# ---------------------------------------------------------------------------
# P2. Read-only token scoping is enforced SERVER-SIDE.
# FINDING: list=200, create=403, delete=403 with scopes
#          ["read:repository","read:organization"].
#          So "read-only by default" can be a TOKEN property, not merely a
#          --dry-run flag the tool could be talked out of.
# ---------------------------------------------------------------------------
say "P2 read-only token scoping"
RO=$(curl -s "${ADMIN[@]}" -H "Content-Type: application/json" \
      -d '{"name":"probe-ro","scopes":["read:repository","read:organization"]}' \
      "$API/users/ms/tokens" | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha1"])')
curl -s -o /dev/null -w "list   = %{http_code}\n" -H "Authorization: token $RO" "$API/orgs/projects/repos?limit=50"
curl -s -o /dev/null -w "create = %{http_code}\n" -X POST -H "Authorization: token $RO" \
  -H "Content-Type: application/json" -d '{"name":"probe-should-fail"}' "$API/orgs/projects/repos"
curl -s -o /dev/null -w "delete = %{http_code}\n" -X DELETE -H "Authorization: token $RO" "$API/repos/projects/taskmaster"

# ---------------------------------------------------------------------------
# P3. Pagination contract.
# FINDING: X-Total-Count plus an RFC-5988 Link header with rel=next/last.
#          `forge sync` must paginate; it need not throttle (no rate limit in
#          any primary source, per ticket 03).
# ---------------------------------------------------------------------------
say "P3 pagination headers"
curl -s -D- -o /dev/null -H "Authorization: token $T" "$API/orgs/projects/repos?limit=2" |
  grep -iE '^(x-total-count|link):'

# ---------------------------------------------------------------------------
# P4. Private repos are not anonymously cloneable; an API TOKEN works as an
#     HTTP git credential; ARCHIVED repos clone fine (archive is push-only).
# FINDING: anonymous clone fails (auth required); token clone succeeds; the
#          archived repo `oppen` clones with full history.
# ---------------------------------------------------------------------------
say "P4 http clone: anonymous / token / archived"
D=$(mktemp -d)
git clone -q "http://localhost:3210/projects/taskmaster.git" "$D/anon" 2>&1 | head -2
echo "anon exists?    $([ -d "$D/anon" ] && echo yes || echo 'no  <- auth required, as wanted')"
git clone -q "http://x:$RO@localhost:3210/projects/taskmaster.git" "$D/tok" 2>/dev/null
echo "token clone:    $([ -d "$D/tok/.git" ] && echo ok || echo FAILED)"
git clone -q "http://x:$RO@localhost:3210/projects/oppen.git" "$D/arch" 2>/dev/null
echo "archived clone: $(git -C "$D/arch" rev-list --all --count 2>/dev/null) commits"

# ---------------------------------------------------------------------------
# P5. THE TRAP: an embedded HTTP credential is PERSISTED verbatim into
#     .git/config as remote.origin.url.
# FINDING: `grep -c "$RO" .git/config` == 1.
#          So a naive "clone over HTTPS with the token in the URL" restore
#          writes the forge token in plaintext into ~20 .git/config files on a
#          fresh machine. This is what makes HTTPS-vs-SSH a real trade rather
#          than "HTTPS is obviously simpler": it forces a credential-storage
#          decision (credential.helper, ~/.netrc, or url.<base>.insteadOf with
#          clean remotes) into this ticket's contract.
# ---------------------------------------------------------------------------
say "P5 does the token leak into .git/config?"
if grep -q "$RO" "$D/tok/.git/config"; then
  echo "YES — token persisted in remote.origin.url:"
  sed "s|$RO|<TOKEN>|g" "$D/tok/.git/config" | grep -A1 '\[remote'
else
  echo "no"
fi

curl -s -o /dev/null -X DELETE "${ADMIN[@]}" "$API/users/ms/tokens/probe-ro"
rm -rf "$D"
