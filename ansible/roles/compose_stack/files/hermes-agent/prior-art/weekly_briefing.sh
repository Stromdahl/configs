#!/usr/bin/env bash
# PRIOR ART — NOT DEPLOYED, AND NOT SCHEDULED. Recovered by ticket 018 from 4ed7e63^.
#
# ⚠️ There is no weekly brief. Ticket 06 settled the push channels as exactly two —
# a script-only interrupt channel and one 20:00 daily brief — so this file's cadence
# was not adopted. It is kept only as ticket 02's "second worked example" of the same
# contract morning_briefing.sh carries. Do not schedule it.
#
# CARRIED FORWARD — one thing, and it is the one morning_briefing.sh does not show:
#
#   Multi-day date arithmetic in the script rather than the prompt. The META line
#   hands the agent a computed `week_through` with a fallback, so a range the LLM
#   might otherwise infer is a fact it is given. Same rule, wider window:
#   ALL date math here, never in the LLM.
#
# Everything else duplicates morning_briefing.sh — the STATUS contract, the env-file
# credential read, the not-`set -e` rationale. Read that file first; this one exists
# to show the contract holding across a second cadence, not to add to it.
#
# STRIPPED — all three emitters, none of them adaptable:
#
#   emit_calendar — calendar is out of scope in spec 015 (and the titan-era
#                   google-workspace skill venv it shelled into is gone).
#   emit_inbox    — read the *old* ~/hermes-vault/Inbox, which no longer exists. The
#                   vault's inbox is now a source spec 015 handles differently: the
#                   brief reports backlog *depth* and oldest-note age in the footer,
#                   and Hermes writes into ~/vault/inbox/ rather than reading tasks
#                   out of it. Not an adaptation — a different design.
#   emit_weather  — Home Assistant as a read source is out of scope; dropping it is
#                   what makes the fake-weather class unwritable.

set -uo pipefail

# --- refuse to run --------------------------------------------------------------
# See prior-art/morning_briefing.sh for why: a prior-art script that sources real
# credentials and exits 0 is the shape this map exists to keep out.
echo "prior art, not a runnable script — read the header. Nothing below is wired." >&2
exit 2

# The v0.14 original also read $HOME/.hermes/.env here. Dropped: nothing left in this
# file reads a credential, and the env-file rule is stated once, in morning_briefing.sh.

# --- date facts, including the range: computed here, never by the agent -------
today="$(date +%Y-%m-%d)"; weekday="$(date +%A)"
week_through="$(date -d '+7 days' +%Y-%m-%d 2>/dev/null || echo "$today")"
echo "META: date=$today weekday=$weekday week_through=$week_through"
