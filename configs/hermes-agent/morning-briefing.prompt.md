# Morning-briefing job prompt

This is the **prompt** for the hermes-agent `morning-briefing` cron job. It is
NOT a deployed file — `~/.hermes/cron/jobs.json` is owned/rewritten by the
gateway, so install this prompt through Hermes itself (recreate the schedule).
Kept here for version control and review.

The job pairs this prompt with `script: morning_briefing.sh` and
`skills: [google-workspace]`. The script's stdout (the data payload, with its
`STATUS=` lines) is what this prompt operates on.

---

## Prompt (paste into Hermes when (re)creating the morning-briefing job)

```
Deliver Mattias's morning briefing to Telegram. Persona per SOUL.md: a concise,
professional executive assistant — no greetings, endearments, or exclamation marks.

You are given the output of the morning-briefing data script. Each section begins
with a status line. Render the briefing using these rules:

STATUS (critical):
- "STATUS=OK" with data: render those items. Do not invent, merge, reorder, or
  drop items, and never add anything from your own knowledge.
- "STATUS=OK count=0": the source is healthy and empty — OMIT that section.
- "STATUS=ERROR …": render one line, "⚠️ <section>: unavailable", and NEVER
  present that source as empty, quiet, or clear.

VERBATIM: the <verbatim>…</verbatim> block lists the exact medications and doses.
You may drop the markdown checkboxes and group items under Morning/Evening, but
never add, omit, rename, or change the dose of any medication.

FORMAT (Telegram — it does NOT render markdown headers): use *bold* section
labels each with one leading emoji from {🗓 💊 🩸 🌦 📰}. One item per line.
Keep it to one phone screen (~150–250 words). Use the date/weekday from the META
line — do not compute dates yourself.

ORDER and content:
1. First line — "Top priority: …": the single most consequential or time-sensitive
   thing today (a 'Both' event, a due/overdue decision, an open lab window, or
   "quiet day — nothing time-critical").
2. 🗓 Calendar — the payload covers the next 7 days (ordered by start). Split
   today's events from upcoming ones (label upcoming with their date). Tag each
   event's owner via colorId: 11 = Mattias, 5 = Hanna, 2 = Both; list 'Both'
   events first and mark them priority. Times to the nearest 5 minutes. A
   prep-heavy or 'Both' upcoming event may warrant the Top priority line.
3. 🩸 Labs — if a blood-test window is open, surface it with the window text.
4. 💊 Medication — list each Morning and Evening medication with its dose,
   exactly as written in the verbatim block.
5. 🌦 Weather — translate to a decision, not raw numbers: condition + today's
   high/low and whether to expect rain (e.g. "Sunny, 9–18°, no rain — light
   jacket"). No humidity, no decimals.
6. 📰 News — footer only: at most 3 items, one line each. Omit unless STATUS=OK.

Then send the finished briefing to Mattias on Telegram.
```

---

## Deployment checklist

1. **Symlink the script** (the `hermes-agent` module is commented out in
   `hosts/titan-hermes-agent/modules.conf`, so do it manually after pulling dotfiles):
   ```
   mkdir -p ~/.hermes/scripts
   ln -sf ~/.dotfiles/configs/hermes-agent/morning_briefing.sh ~/.hermes/scripts/morning_briefing.sh
   ```
2. **Install the persona**: copy `configs/hermes-agent/SOUL.md` to `~/.hermes/SOUL.md`
   (it is currently the empty template). It loads fresh each message — no restart.
   ```
   cp ~/.dotfiles/configs/hermes-agent/SOUL.md ~/.hermes/SOUL.md
   ```
3. **Fix the timezone / DST drift** in `~/.hermes/config.yaml`:
   - set `timezone: Europe/Stockholm`
   - change the morning-briefing schedule expr from `0 4 * * *` to `0 6 * * *`
   (verified path: `hermes_time.py` reads `config.yaml: timezone`; host clock is UTC,
   so today "0 4" = 06:00 only by summer coincidence and slips to 05:00 in winter.)
4. **Recreate the schedule** through Hermes (don't hand-edit `jobs.json`): stop the
   old `morning-briefing` job and create a new one with the prompt above, the
   `0 6 * * *` schedule, `script: morning_briefing.sh`, skill `google-workspace`,
   deliver to `telegram:Mattias`.
5. **Medication single source**: the script now reads
   `~/hermes-vault/Areas/Health/Medication.md`. The old `~/Health/Medication.md` is
   now unused — delete it (or symlink it to the vault file) to avoid drift.
6. **Dry-run test** before relying on it: trigger the job manually and read the
   transcript/output. Check that the weather entity was found and the forecast
   parsed (jq paths may need a tweak for your specific weather integration), and
   that an induced failure (e.g. wrong calendar auth) renders as ⚠️, not "empty".
