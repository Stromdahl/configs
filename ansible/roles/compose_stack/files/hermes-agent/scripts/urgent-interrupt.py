#!/usr/bin/env python3
"""hermes-helium ticket 022 — the interrupt channel.

no_agent cron script: date arithmetic over ~/vault/tasks.md, nothing else.
Empty stdout is silence; a non-zero exit is what the engine reports as a
failure, so any real problem (unreadable board, unwritable state) must exit
non-zero rather than being swallowed here. See planning/hermes-helium/issues/
022 and 06 (D1-D3) for the design this implements.
"""

import hashlib
import json
import os
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Europe/Stockholm")
VAULT_TASKS = Path("/vault/tasks.md")
HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))
STATE_PATH = HERMES_HOME / "state" / "urgent-seen.json"
WINDOW_DAYS = 2  # ticket 06 D2.3 — T-2
DAILY_CEILING = 3  # ticket 06 D3

# Only literal "- [ ] " lines are candidates (06 D2.6) — a nested "  - " bullet
# with no checkbox, or the board's own format-documentation line, must not
# parse as a task just because it contains a 📅.
TASK_LINE_RE = re.compile(r"^\s*-\s\[\s\]\s")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
DATE_TOKEN_RE = re.compile(r"📅\s*(\d{4}-\d{2}-\d{2})")
DATE_MARKER_RE = re.compile(r"📅")
PUNCT_RE = re.compile(r"[^\w\s]", re.UNICODE)


def today() -> date:
    return datetime.now(TZ).date()


def normalize_title(title: str) -> str:
    stripped = title.replace("[[", " ").replace("]]", " ").replace("`", " ")
    stripped = PUNCT_RE.sub(" ", stripped)
    return " ".join(stripped.lower().split())


def item_key(iso_date: str, title: str) -> str:
    return hashlib.sha1(f"{iso_date}{normalize_title(title)}".encode()).hexdigest()


def parse_board(text: str):
    """Return (items, parse_errors). items: dicts with date/title/key/line."""
    items = []
    parse_errors = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if not TASK_LINE_RE.match(line):
            continue
        if not DATE_MARKER_RE.search(line):
            continue  # undated task — not this job's concern
        # First 📅 occurrence on the line is the item's own due date — a line
        # may reference another item's date later in its prose (verified on
        # the real board: the Stills-appointment line cites the Kineret
        # ticket's own 📅 in passing).
        m = DATE_TOKEN_RE.search(line)
        if not m:
            parse_errors.append((lineno, line.strip()))
            continue
        raw_date = m.group(1)
        try:
            y, mo, d = (int(part) for part in raw_date.split("-"))
            item_date = date(y, mo, d)
        except ValueError:
            parse_errors.append((lineno, line.strip()))
            continue
        title_match = BOLD_RE.search(line)
        title = title_match.group(1).strip() if title_match else line.strip()
        items.append(
            {
                "date": item_date,
                "iso": item_date.isoformat(),
                "title": title,
                "key": item_key(item_date.isoformat(), title),
                "line": lineno,
            }
        )
    return items, parse_errors


def load_state():
    if not STATE_PATH.exists():
        return None
    with STATE_PATH.open() as f:
        return json.load(f)


def save_state(state):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    with tmp.open("w") as f:
        json.dump(state, f, indent=2, sort_keys=True)
    tmp.replace(STATE_PATH)


def prune_daily_counts(daily_counts, current):
    cutoff = current - timedelta(days=3)
    return {d: n for d, n in daily_counts.items() if date.fromisoformat(d) >= cutoff}


def why_now(item_date: date, current: date) -> str:
    delta = (item_date - current).days
    if delta > 0:
        return f"due in {delta} day{'s' if delta != 1 else ''}"
    if delta == 0:
        return "due today"
    return f"overdue by {-delta} day{'s' if -delta != 1 else ''}"


def format_title(title: str, limit: int = 200) -> str:
    title = " ".join(title.split())
    if len(title) > limit:
        return title[: limit - 1].rstrip() + "…"
    return title


def main() -> int:
    try:
        text = VAULT_TASKS.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"FATAL: cannot read {VAULT_TASKS}: {exc}", file=sys.stderr)
        return 1

    current = today()
    items, parse_errors = parse_board(text)

    try:
        state = load_state()
    except (json.JSONDecodeError, OSError) as exc:
        print(f"FATAL: cannot read state file {STATE_PATH}: {exc}", file=sys.stderr)
        return 1

    cold_start = state is None
    if cold_start:
        state = {"seen": {}, "daily_counts": {}, "errors_seen": {}}

    seen = state.setdefault("seen", {})
    daily_counts = state.setdefault("daily_counts", {})
    errors_seen = state.setdefault("errors_seen", {})

    lines_out = []

    if cold_start:
        seeded = 0
        for item in items:
            delta = (item["date"] - current).days
            if delta <= WINDOW_DAYS:
                seen[item["key"]] = {
                    "date": item["iso"],
                    "title": item["title"],
                    "seeded": True,
                    "at": current.isoformat(),
                }
                seeded += 1
        state["cold_start_at"] = current.isoformat()
        state["seeded_count"] = seeded
        if seeded:
            lines_out.append(
                f"🌱 First run — seeded {seeded} already-due/near-due item"
                f"{'s' if seeded != 1 else ''}. No pings sent for these; "
                "they're already on the board."
            )
        else:
            lines_out.append(
                "🌱 First run — nothing already due. Interrupts start from here."
            )
    else:
        today_key = current.isoformat()
        fired_today = daily_counts.get(today_key, 0)
        newly_due = [
            item
            for item in items
            if item["key"] not in seen and (item["date"] - current).days <= WINDOW_DAYS
        ]

        overflow = 0
        for item in newly_due:
            seen[item["key"]] = {
                "date": item["iso"],
                "title": item["title"],
                "seeded": False,
                "at": current.isoformat(),
            }
            if fired_today < DAILY_CEILING:
                lines_out.append(
                    f"*{format_title(item['title'])}* · 📅 {item['iso']} · "
                    f"{why_now(item['date'], current)}"
                )
                fired_today += 1
            else:
                overflow += 1
        daily_counts[today_key] = fired_today
        if overflow:
            lines_out.append(f"+{overflow} more due soon — see tonight's brief.")
        state["daily_counts"] = prune_daily_counts(daily_counts, current)

    for lineno, raw in parse_errors:
        err_key = hashlib.sha1(raw.encode()).hexdigest()
        if err_key in errors_seen:
            continue
        errors_seen[err_key] = current.isoformat()
        snippet = raw if len(raw) <= 160 else raw[:159] + "…"
        lines_out.append(f"⚠ ERROR: unparseable 📅 date on tasks.md line {lineno}: {snippet}")

    try:
        save_state(state)
    except OSError as exc:
        print(f"FATAL: cannot write state file {STATE_PATH}: {exc}", file=sys.stderr)
        return 1

    if lines_out:
        print("\n".join(lines_out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
