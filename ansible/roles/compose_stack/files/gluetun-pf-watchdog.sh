#!/bin/sh
# gluetun-pf-watchdog — recover a dead ProtonVPN NAT-PMP port forward on helium.
#
# WHY: gluetun's port forwarding intermittently dies (the NAT-PMP gateway starts
# refusing the renewal RPC, e.g. `recvfrom: connection refused` to 10.2.0.1:5351)
# and gluetun does NOT self-recover — it keeps retrying the same broken server
# for hours, leaving /tmp/forwarded_port empty. With no inbound port, qBittorrent
# gets stuck in DownloadingMetadata on every grab; Cleanuparr then strikes and
# blocklists each release in a loop and nothing ever downloads. The only reliable
# fix is to bounce gluetun so it reconnects (a fresh PF-capable server).
#
# NETNS GOTCHA: qbittorrent, prowlarr and flaresolverr run with
# `network_mode: service:gluetun` — restarting gluetun tears down the shared
# network namespace, so those three MUST be restarted too, and only AFTER gluetun
# is healthy again (else they race a half-built netns and restart-loop).
#
# Steady-state port syncing is handled by gluetun's VPN_PORT_FORWARDING_UP_COMMAND
# (see docker-compose.yml.j2); this watchdog only handles the DEATH case, and does
# a final belt-and-suspenders sync since the UP command races the sibling restart.
#
# Installed + scheduled (every 5 min) by roles/compose_stack/tasks/pf_watchdog.yml.
set -eu

STATE=/run/gluetun-pf-watchdog.fails
MAX_FAILS=3                       # ~3 * 5min timer = act only after ~15 min dead
SIBLINGS="qbittorrent prowlarr flaresolverr"
QBIT_API=http://127.0.0.1:8080/api/v2/app/setPreferences

log() { logger -t gluetun-pf-watchdog "$*"; }

# Current forwarded port (digits only); empty/0 => port forwarding is down.
read_port() { docker exec gluetun cat /tmp/forwarded_port 2>/dev/null | tr -dc '0-9'; }

port=$(read_port)
if [ -n "$port" ] && [ "$port" -gt 0 ] 2>/dev/null; then
    rm -f "$STATE"                # healthy — reset the strike counter
    exit 0
fi

# Port is empty/zero. Count consecutive failures so a brief mid-renewal blank
# (gluetun clears the file for a moment while re-leasing) does not trip a restart.
fails=$(cat "$STATE" 2>/dev/null || echo 0)
fails=$((fails + 1))
echo "$fails" > "$STATE"
if [ "$fails" -lt "$MAX_FAILS" ]; then
    log "forwarded port empty (strike $fails/$MAX_FAILS) — waiting"
    exit 0
fi

log "port forward dead for $fails checks — restarting gluetun + netns siblings"
docker restart gluetun >/dev/null

# Wait for gluetun's built-in healthcheck to pass before touching the siblings.
health=starting
i=0
while [ "$i" -lt 36 ]; do          # up to ~3 min
    health=$(docker inspect -f '{{.State.Health.Status}}' gluetun 2>/dev/null || echo starting)
    [ "$health" = healthy ] && break
    sleep 5
    i=$((i + 1))
done
if [ "$health" != healthy ]; then
    log "WARNING: gluetun not healthy after wait (status=$health) — restarting siblings anyway"
fi

# shellcheck disable=SC2086  # word-splitting SIBLINGS into separate args is intended
docker restart $SIBLINGS >/dev/null

# Belt-and-suspenders: the UP command fires when gluetun re-acquires the port, but
# that can race qbit's restart above, so push the current port once more now that
# qbit is back (idempotent — same value the UP command sets). --retry-connrefused
# rides out the seconds until qbit's WebUI is serving.
newport=$(read_port)
if [ -n "$newport" ] && [ "$newport" -gt 0 ] 2>/dev/null; then
    docker exec gluetun sh -c \
      "wget -qO- --retry-connrefused --post-data 'json={\"listen_port\":$newport,\"random_port\":false,\"upnp\":false}' $QBIT_API" \
      >/dev/null 2>&1 || log "WARNING: post-recovery qbit port sync failed (port $newport)"
    log "recovery complete: gluetun health=$health, forwarded port=$newport"
else
    log "recovery ran but forwarded port still empty (gluetun health=$health) — will retry next tick"
fi

rm -f "$STATE"
