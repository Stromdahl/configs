#!/usr/bin/env bash
# Weekly "week ahead" DATA-GATHER script for Hermes (runs Sundays).
#
# Source of truth: dotfiles configs/hermes-agent/weekly_briefing.sh
#   → symlinked to ~/.hermes/scripts/weekly_briefing.sh (see modules/hermes-agent).
# Paired with the weekly-briefing job prompt (weekly-briefing.prompt.txt) +
# google-workspace skill; stdout is the data payload the agent synthesizes.
#
# Same STATUS contract as morning_briefing.sh: each section emits
#   <name>: STATUS=OK count=<n>   or   <name>: STATUS=ERROR reason="…"
# and the prompt renders OK-with-data, omits count=0, surfaces ERROR as ⚠️.
# Covers the COMING 7 DAYS. No meds/news/labs (the daily owns those).
set -uo pipefail

set -a; [ -f "$HOME/.hermes/.env" ] && . "$HOME/.hermes/.env"; set +a
HASS_URL="${HASS_URL:-}"; HASS_TOKEN="${HASS_TOKEN:-}"
ha_get()  { curl -fsS -m 10 -H "Authorization: Bearer ${HASS_TOKEN}" "${HASS_URL%/}$1"; }
ha_post() { curl -fsS -m 10 -H "Authorization: Bearer ${HASS_TOKEN}" -H 'Content-Type: application/json' -X POST "${HASS_URL%/}$1" -d "$2"; }

today="$(date +%Y-%m-%d)"; weekday="$(date +%A)"
week_through="$(date -d '+7 days' +%Y-%m-%d 2>/dev/null || echo "$today")"
echo "META: date=$today weekday=$weekday week_through=$week_through"

# --- 1. Week ahead: calendar (next 7 days, owner via colorId) -----------------
GAPI_DIR="$HOME/.hermes/skills/productivity/google-workspace"
emit_calendar() {
  local out n
  out="$("$GAPI_DIR/venv/bin/python" "$GAPI_DIR/scripts/google_api.py" calendar list --max 25 2>/dev/null)" \
    || { echo 'calendar: STATUS=ERROR reason="google_api.py failed (auth expired?)"'; return; }
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    echo 'calendar: STATUS=ERROR reason="non-JSON output (auth/setup issue)"'; return; fi
  n="$(printf '%s' "$out" | jq '(if type=="array" then . elif .events then .events elif .items then .items else [] end)|length' 2>/dev/null)"
  echo "calendar: STATUS=OK count=${n:-0}"
  printf '%s\n' "$out"
}

# --- 2. Upcoming tasks / prep from the vault Inbox ----------------------------
# Emits open checkbox tasks (with their source file) across Inbox/*.md, skipping
# meta/spec/prompt docs. Tasks are NOT safety-critical — the agent may summarise.
emit_inbox() {
  local dir="$HOME/hermes-vault/Inbox" tasks n
  [ -d "$dir" ] || { echo 'inbox: STATUS=ERROR reason="no Inbox dir"'; return; }
  tasks="$(grep -H -- '- \[ \]' "$dir"/*.md 2>/dev/null | grep -viE 'spec|\.prompt\.')"
  n="$(printf '%s' "$tasks" | grep -c .)"
  echo "inbox: STATUS=OK count=$n"
  [ "$n" -gt 0 ] && { echo "<open_tasks  (format: file.md:- [ ] task)>"; printf '%s\n' "$tasks"; echo "</open_tasks>"; }
}

# --- 3. Weather outlook for the week (HA daily forecast, next 7 days) ---------
emit_weather() {
  if [ -z "$HASS_URL" ] || [ -z "$HASS_TOKEN" ]; then echo 'weather: STATUS=ERROR reason="no HASS creds"'; return; fi
  local states ent fc
  states="$(ha_get /api/states 2>/dev/null)" || { echo 'weather: STATUS=ERROR reason="Home Assistant unreachable"'; return; }
  ent="$(printf '%s' "$states" | jq -r '[.[].entity_id|select(startswith("weather."))][0] // empty' 2>/dev/null)"
  [ -n "$ent" ] || { echo 'weather: STATUS=ERROR reason="no weather.* entity"'; return; }
  fc="$(ha_post "/api/services/weather/get_forecasts?return_response" "{\"entity_id\":\"$ent\",\"type\":\"daily\"}" 2>/dev/null \
        | jq -c --arg e "$ent" '.service_response[$e].forecast[0:7][] | {date:.datetime, cond:.condition, high:.temperature, low:.templow, precip_pct:.precipitation_probability}' 2>/dev/null)"
  [ -n "$fc" ] || { echo 'weather: STATUS=ERROR reason="forecast unavailable"'; return; }
  echo "weather: STATUS=OK entity=$ent"
  printf '%s\n' "$fc"
}

emit_calendar
echo; emit_inbox
echo; emit_weather
