---
name: note
description: Use when the user wants to capture a note, to-do, idea, or reminder into their personal ~/notes inbox for later — phrases like "add this to my notes", "send a note/todo/idea to my notes", "jot this down", "remind me to …", "note for daily / for my notes assistant", "capture this", "save this idea". Writes one timestamped file into ~/notes/inbox/, which the user's /daily session drains onto their task board. Do NOT use for editing existing notes, for a project-local TODO file, or for the dotfiles repo's own modules.
---

# Capture a note to ~/notes/inbox

The user keeps a personal notes vault at `~/notes`. Any session, in any project,
can leave a note/to-do/idea/reminder by writing **one file per note** into
`~/notes/inbox/`. The user's notes assistant (`/daily`) drains the inbox onto
their task board each morning and moves processed files to `inbox/done/`.

## Procedure

1. **Compose a stand-alone note.** It will be read later by a *different* session
   on a *different* day with zero memory of this conversation. Give it a short
   `# Title` heading and a line or two of body with enough context to act on
   cold — what, why, where (paths/links), and any next step. Match the user's
   real notes: terse but self-sufficient. Arbitrary markdown is fine (code
   fences, backticks, commands) — the Write tool handles it verbatim.

2. **If it's due / for a specific day, add a `📅 YYYY-MM-DD` as the very first
   line** of the body (before the title). Convert any relative date to absolute
   first — e.g. `date -d tomorrow +%F`, `date -d 'next friday' +%F`.

3. **Get the timestamp and confirm the vault is here** in one shot:

   ```bash
   test -d ~/notes/inbox && date '+%Y-%m-%dT%H%M'
   ```

   If `~/notes/inbox` doesn't exist, the vault isn't synced on this host — stop
   and tell the user rather than creating a stray `~/notes`.

4. **Derive the filename:** `~/notes/inbox/<ts>-<source>-<slug>.md`
   - `<ts>` — the `date` output above (e.g. `2026-06-18T0930`, no colon).
   - `<source>` — the project you're working in: the git repo / cwd basename
     with any leading dot stripped (`.dotfiles` → `dotfiles`). If you're not in a
     project, use a short topical word instead (e.g. `idea`, `misc`).
   - `<slug>` — a few kebab-case words from the title (e.g. `rebuild-supervisor`).

5. **Write the file** with the Write tool (one file per note — never append to an
   existing file; that's what causes Syncthing conflicts). If Write reports the
   path already exists (rare same-minute collision), append `-2` to the slug.

6. **Confirm** back to the user: the created path and a one-line recap.

For several distinct items, write **several files** — one per note — not one
combined file.

## Example

For "remind me to rebuild the supervisor image before Wednesday's redeploy" while
working in the `yggio` project, on 2026-06-18:

Path: `~/notes/inbox/2026-06-18T0930-yggio-rebuild-supervisor.md`

```markdown
📅 2026-06-19

# Rebuild rsmp-supervisor image before the Malmö dev redeploy

The config-schema fix needs to land first, then rebuild — otherwise the redeploy
ships the stale schema. Do it from the yggio repo.
```

## Notes

- **Don't classify personal vs work.** That's the `/daily` triage's job — it files
  each note where it belongs (personal → the board's `## Personal 🏠` section, work
  → `## Projects` / `🔥 Now`). Capture stays simple; just make the note's nature
  clear in the content. The `<source>` already signals which project it came from.
- Keep it out of secrets territory — the vault is git-tracked and Syncthing-synced.
- This is for *capture / hand-off*, not for things you should just do now in the
  current session.
