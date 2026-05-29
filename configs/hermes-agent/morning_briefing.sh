#!/usr/bin/env bash
# Morning-briefing DATA-GATHER script for Hermes.
#
# Source of truth: dotfiles configs/hermes-agent/morning_briefing.sh
#   → symlinked to ~/.hermes/scripts/morning_briefing.sh (see modules/hermes-agent).
# Invoked by the hermes-agent "morning-briefing" cron job; its stdout becomes the
# data payload the agent synthesizes (the synthesis rules live in the job prompt,
# configs/hermes-agent/morning-briefing.prompt.md — NOT in this script).
#
# CONTRACT the job prompt relies on:
#   * Each section starts with a status line:
#       <name>: STATUS=OK count=<n>      (or with data lines below it)
#       <name>: STATUS=ERROR reason="…"
#   * The agent renders OK-with-data, OMITS STATUS=OK count=0, and surfaces
#     STATUS=ERROR as an explicit ⚠️ warning — a failed source is NEVER shown
#     as "empty/quiet". (This is the fix for "fetch failed" masquerading as
#     "nothing scheduled".)
#   * Safety-critical text is wrapped in <verbatim>…</verbatim> and must be
#     copied character-for-character by the agent.
#   * ALL date math (weekday, lab window) is done here so the LLM never has to.
#
# Deps on host: curl, jq, the google-workspace skill venv, HASS_URL/HASS_TOKEN
# in ~/.hermes/.env. (`ha` CLI/node are intentionally NOT required — not present
# on titan-hermes-agent.)
#
# NOTE: not `set -e` — one failing section must not abort the whole briefing.
set -uo pipefail

# --- HA credentials (Hermes' own token; ha CLI is unavailable on this host) ---
set -a; [ -f "$HOME/.hermes/.env" ] && . "$HOME/.hermes/.env"; set +a
HASS_URL="${HASS_URL:-}"; HASS_TOKEN="${HASS_TOKEN:-}"
ha_get()  { curl -fsS -m 10 -H "Authorization: Bearer ${HASS_TOKEN}" "${HASS_URL%/}$1"; }
ha_post() { curl -fsS -m 10 -H "Authorization: Bearer ${HASS_TOKEN}" -H 'Content-Type: application/json' -X POST "${HASS_URL%/}$1" -d "$2"; }

# --- date facts (computed here, never by the agent) ---------------------------
today="$(date +%Y-%m-%d)"; weekday="$(date +%A)"
ym="$(date +%Y-%m)"; dom="$(date +%-d)"; monthname="$(date +%B)"
echo "META: date=$today weekday=$weekday"

# --- 1. Weather (REAL, from Home Assistant) -----------------------------------
emit_weather() {
  if [ -z "$HASS_URL" ] || [ -z "$HASS_TOKEN" ]; then
    echo 'weather: STATUS=ERROR reason="no HASS_URL/HASS_TOKEN in ~/.hermes/.env"'; return; fi
  local states ent cur fc
  states="$(ha_get /api/states 2>/dev/null)" || { echo 'weather: STATUS=ERROR reason="Home Assistant unreachable"'; return; }
  ent="$(printf '%s' "$states" | jq -r '[.[].entity_id|select(startswith("weather."))][0] // empty' 2>/dev/null)"
  [ -n "$ent" ] || { echo 'weather: STATUS=ERROR reason="no weather.* entity in Home Assistant"'; return; }
  cur="$(printf '%s' "$states" | jq -c --arg e "$ent" '.[]|select(.entity_id==$e)|{condition:.state,temp:.attributes.temperature}' 2>/dev/null)"
  [ -n "$cur" ] || { echo 'weather: STATUS=ERROR reason="weather state unreadable"'; return; }
  # Daily forecast (today) — modern HA exposes this via a service, not attributes.
  fc="$(ha_post "/api/services/weather/get_forecasts?return_response" "{\"entity_id\":\"$ent\",\"type\":\"daily\"}" 2>/dev/null \
        | jq -c --arg e "$ent" '.service_response[$e].forecast[0] | {high:.temperature, low:.templow, precip_pct:.precipitation_probability, precip_mm:.precipitation, condition:.condition}' 2>/dev/null)"
  echo "weather: STATUS=OK entity=$ent"
  echo "  current=$cur"
  [ -n "$fc" ] && [ "$fc" != "null" ] && echo "  today=$fc"
}

# --- 2. Calendar (google-workspace skill) -------------------------------------
GAPI_DIR="$HOME/.hermes/skills/productivity/google-workspace"
emit_calendar() {
  local out n
  out="$("$GAPI_DIR/venv/bin/python" "$GAPI_DIR/scripts/google_api.py" calendar list --max 10 2>/dev/null)" \
    || { echo 'calendar: STATUS=ERROR reason="google_api.py failed (auth expired?)"'; return; }
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    echo 'calendar: STATUS=ERROR reason="non-JSON output (auth/setup issue)"'; return; fi
  n="$(printf '%s' "$out" | jq '(if type=="array" then . elif .events then .events elif .items then .items else [] end)|length' 2>/dev/null)"
  echo "calendar: STATUS=OK count=${n:-0}"
  # Pass raw JSON through; the agent labels owners via colorId (11=Mattias,5=Hanna,2=Both).
  printf '%s\n' "$out"
}

# --- 3. Medication (vault file; emit ONLY the dosing block, not table/labs) ---
MED="$HOME/hermes-vault/Areas/Health/Medication.md"
emit_medication() {
  if [ ! -s "$MED" ]; then echo "medication: STATUS=ERROR reason=\"missing $MED\""; return; fi
  local block
  # Prefer the "## Daily Schedule" section — the compact Morning/Evening dosing list.
  block="$(awk '/^##[[:space:]]+Daily Schedule/{f=1;next} /^##[[:space:]]/{f=0} f' "$MED")"
  # Fallback: everything up to the Lab section (labs are emitted by emit_labs, never here).
  [ -n "${block//[[:space:]]/}" ] || block="$(awk '/^##[[:space:]]+Lab Test Schedule/{exit} {print}' "$MED")"
  if [ -z "${block//[[:space:]]/}" ]; then echo 'medication: STATUS=ERROR reason="no dosing block parsed from Medication.md"'; return; fi
  echo "medication: STATUS=OK"
  echo "<verbatim>"; printf '%s\n' "$block"; echo "</verbatim>"
}

# --- 4. Lab / blood-test window (deterministic date math) ---------------------
# This is the SINGLE owner of the lab date-logic. The "Lab Test Schedule" section
# in Medication.md is human-readable reference only and is NOT passed through
# (emit_medication strips it). If the schedule changes, update here and the doc.
# Current: monthly 2026-05..2026-10, quarterly 2027-01 & 2027-04; first part of month.
emit_labs() {
  case "$ym" in
    2026-05|2026-06|2026-07|2026-08|2026-09|2026-10|2027-01|2027-04) ;;
    *) echo "labs: STATUS=OK count=0"; return ;;
  esac
  if [ "$dom" -le 12 ]; then
    echo "labs: STATUS=OK count=1"
    echo "  due_this_month=true window=\"first part of $monthname\" where=\"Trelleborg or local clinic, bring ID\""
  else
    echo "labs: STATUS=OK count=0"   # this month's first-part window has passed
  fi
}

# --- 5. Hacker News (footer; capped, with error handling) ---------------------
emit_news() {
  local ids id
  ids="$(curl -fsS -m 10 'https://hacker-news.firebaseio.com/v0/topstories.json' 2>/dev/null | jq -r '.[0:5][]' 2>/dev/null)" \
    || { echo 'news: STATUS=ERROR reason="Hacker News unreachable"'; return; }
  [ -n "$ids" ] || { echo 'news: STATUS=ERROR reason="Hacker News returned nothing"'; return; }
  echo "news: STATUS=OK count=$(printf '%s\n' "$ids" | wc -l | tr -d ' ')"
  while read -r id; do
    [ -n "$id" ] || continue
    curl -fsS -m 10 "https://hacker-news.firebaseio.com/v0/item/$id.json" 2>/dev/null \
      | jq -r '"  - \(.title) :: https://news.ycombinator.com/item?id=\(.id)"' 2>/dev/null
  done <<< "$ids"
}

emit_weather
echo; emit_calendar
echo; emit_medication
echo; emit_labs
echo; emit_news
