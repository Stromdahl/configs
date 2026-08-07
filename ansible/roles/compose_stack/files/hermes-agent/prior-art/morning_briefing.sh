#!/usr/bin/env bash
# PRIOR ART — NOT DEPLOYED. Recovered by ticket 018 from 4ed7e63^ (v0.14, titan).
# Every emitter has been stripped; what is left is the *shape* ticket 023 builds the
# real gathering script from. Nothing copies this file onto helium.
#
# CARRIED FORWARD (the four things worth recovering, all four are in this file):
#
#   1. The per-source STATUS contract — the single most reusable thing recovered,
#      and directly what 023/024 need:
#          <name>: STATUS=OK count=<n>       (data lines below it)
#          <name>: STATUS=ERROR reason="…"
#      A failed source is NEVER rendered as "empty/quiet". That was the fix for
#      "fetch failed" masquerading as "nothing scheduled".
#   2. <verbatim>…</verbatim> — character-for-character passthrough for
#      safety-critical text the agent may reformat but never reword.
#   3. ALL date math here, never in the LLM (the META line).
#   4. Credentials read from the file, not inherited env:
#          set -a; . "$HOME/.hermes/.env"; set +a
#      This is accidentally correct and MUST be preserved: ticket 01 measured the
#      scheduler's subprocess environment as sanitized, so a well-meaning cleanup to
#      inherited env breaks credentials silently. The file read is the workaround.
#
#   Also: not `set -e` — one failing section must not abort the whole briefing.
#
# STRIPPED, and why (ticket 02's verdict table, §"what does not survive"):
#
#   emit_weather   — Home Assistant as a read source is out of scope in spec 015.
#                    Dropping it is what makes the founding fake-weather bug
#                    *unwritable* rather than merely detectable.
#   emit_calendar  — calendar is out of scope; it also shelled into a titan-era
#                    google-workspace skill venv that no longer exists.
#   emit_medication — its source (~/hermes-vault/Areas/Health/Medication.md) is gone.
#                    Ticket 13 has since created a machine-readable dose block in the
#                    vault; 024 builds that emitter fresh against it, not from here.
#   emit_labs      — DEFECT ②, do not port. Its hardcoded month list fell through to
#                    `labs: STATUS=OK count=0`, and the prompt omitted count=0
#                    sections — so from 2027-05 a *health* source would have vanished
#                    from the brief forever while reporting healthy and empty. Any
#                    reuse must make an expired schedule table STATUS=ERROR.
#   emit_news      — a Hacker News footer. Decorative, unrelated to the destination.
#
# PLACEMENT changed too: v0.14 symlinked this out of the dotfiles checkout into
# ~/.hermes/scripts/. Ticket 03 measured that the loader `.resolve()`s and rejects a
# symlink escaping the scripts dir, so there was never a version of it to port. The
# real script is ansible-copied from this role's files/ to
# /data/ssd/appdata/hermes/scripts/.

set -uo pipefail

# --- refuse to run --------------------------------------------------------------
# Not a guard against a hazard that exists today — nothing schedules this file. It is
# here so that running it by hand can never produce the map's enemy shape: a briefing
# script that sources real credentials, prints a plausible META line, emits one ERROR
# for a source that was never wired, and exits 0. Delete this block only together with
# the emitter skeleton it protects, when 023 turns this into a real script.
echo "prior art, not a runnable script — read the header. Nothing below is wired." >&2
exit 2

# --- credentials: read from the file, never inherited (see #4 above) -----------
set -a; [ -f "$HOME/.hermes/.env" ] && . "$HOME/.hermes/.env"; set +a

# --- date facts: computed here, never by the agent ----------------------------
today="$(date +%Y-%m-%d)"; weekday="$(date +%A)"
echo "META: date=$today weekday=$weekday"

# --- the emitter shape, with no source behind it ------------------------------
# One function per source. Three exits, and only three: OK with data, OK count=0,
# ERROR with a reason. Never `return` without printing a status line.
emit_example() {
  local block
  if [ -z "${EXAMPLE_SOURCE:-}" ]; then
    echo 'example: STATUS=ERROR reason="no EXAMPLE_SOURCE configured"'; return
  fi
  # `fetch_the_source` is deliberately undefined: there is no source behind this
  # shape. Whatever the fetch is, the `||` is the load-bearing part — every failure
  # path must land on a printed STATUS=ERROR, never on a bare return.
  block="$(fetch_the_source 2>/dev/null)" || {
    echo 'example: STATUS=ERROR reason="source unreachable"'; return
  }
  echo "example: STATUS=OK count=1"
  # Safety-critical text goes through verbatim: the agent may drop checkboxes or
  # regroup, but never add, omit, rename, or change a value inside the block.
  echo "<verbatim>"; printf '%s\n' "$block"; echo "</verbatim>"
}

emit_example
