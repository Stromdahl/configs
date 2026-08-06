# Ticket 08 — write-surface probe

Premise checks run **2026-08-06** before the grilling, per wayfinder step 3.

**Where each fact was established.** helium was unreachable during this session
(krypton roaming on `10.25.0.x`, NetBird `SessionExpired`), so every probe below ran
**on krypton** against the pinned digest
`nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d…` — the same image helium will
run. Mount semantics are mount-flag level, not host-specific, and were re-run on an
**ext4** path to remove a tmpfs caveat. Nothing here was verified end-to-end on
helium, and `/vault` does not exist there yet — vault-serve
[004](../../vault-serve/issues/004-syncthing-role.md) is still open.

Reproduce: image exported with `docker create` + `docker export`; source read under
`/opt/hermes`.

---

## 1. 🔴 A successful vault write leaves no path in `$HERMES_HOME/logs`

This is the load-bearing check ticket `05`'s **D4** demanded ("verify per write
mechanism, don't assume"). **It fails.**

### The probe

Ran `write_file_tool` directly in the container (no API key needed — the tool is
importable), with `HERMES_WRITE_SAFE_ROOT=/opt/data:/vault/inbox`:

```bash
docker run --rm -e HERMES_UID=1000 -e HERMES_GID=1000 \
  -e HERMES_WRITE_SAFE_ROOT=/opt/data:/vault/inbox \
  -v "$D/state:/opt/data" -v "$D/vault:/vault:ro" -v "$D/vault/inbox:/vault/inbox:rw" \
  --entrypoint bash nousresearch/hermes-agent@sha256:b869e64d… -c '
cd /opt/hermes; export HERMES_HOME=/opt/data
python - <<EOF
import hermes_logging
hermes_logging.setup_logging()
from tools.file_tools import write_file_tool
print(write_file_tool(path="/vault/inbox/probe-note.md", content="hello\n", task_id="probe"))
print(write_file_tool(path="/vault/journal/nope.md", content="x", task_id="probe"))
EOF
grep -c "probe-note.md" /opt/data/logs/agent.log'
```

The write **succeeded**:

```json
{"bytes_written": 18, "dirs_created": true, "resolved_path": "/vault/inbox/probe-note.md",
 "files_modified": ["/vault/inbox/probe-note.md"]}
```

`grep -c probe-note.md /opt/data/logs/agent.log` → **`0`**. The whole of `agent.log`
after the write was environment setup/teardown noise:

```
INFO tools.file_tools: Creating new local environment for task default...
INFO tools.environments.base: Session snapshot created (session=067bb617c424, cwd=/opt/hermes)
INFO tools.file_tools: local environment ready for task default
INFO tools.terminal_tool: Shutting down 1 remaining sandbox(es)...
```

### Why — three call sites, read in the image

- **`tools/file_tools.py`** logs `write_file` only on **failure**:
  `logger.debug("write_file expected denial: …")` (line 1642) and
  `logger.error("write_file error: …")` (1644). There is no INFO log of a success.
- **`agent/tool_executor.py:879`** is the generic tool log:
  `logger.info("tool %s completed (%.2fs, %d chars)", …)` — **tool name, duration and
  result length; never the arguments.** So the log can say *a* `write_file` ran, never
  *which path*.
- **The only path-level record is `file_state.note_write(task_id, _resolved)`**
  (`file_tools.py:1638`), and `tools/file_state.py` is explicit about what it is: *"A
  process-wide singleton `FileStateRegistry`"* holding plain dicts and
  `threading.Lock`s, whose purpose is *"Cross-agent file state coordination …
  prevents mangled edits when concurrent subagents … touch the same file."*
  **In-memory only, capped at `_MAX_PATHS_PER_AGENT = 4096` with oldest-dropped
  overflow, and it dies with the process.** It is a concurrency guard, not an audit
  trail.

### Two aggravating factors

- **`agent.log` is lossy by design** — `RotatingFileHandler`, 5 MiB × 3 backups
  (`hermes_logging.py`). Even if writes *were* logged, a busy day could rotate the
  record away.
- **`terminal` writes are invisible as writes.** A shell write shows up as
  `tool terminal completed (…)` and nothing more — so the mechanism `01` found
  escapes `HERMES_WRITE_SAFE_ROOT` also escapes the log.

### What *does* hold a durable record

`hermes_state.py` persists tool-call **arguments**: the `messages` table carries
`tool_name` and `tool_calls` columns (v23 schema; both are indexed into
`messages_fts`). So the write list is derivable from `state.db` — but that is the
agent's **self-report of intent**, it misses `terminal` writes the same way, and
parsing conversation JSON from a `no_agent` shell script is fragile.

### ⇒ Enumerate from the filesystem instead

`find <writable path> -newermt <since>` observes **effects, not intentions**, covers
every write mechanism including `terminal`, needs nothing from Hermes, and is
**complete precisely because the mount is narrow**. Enforcement and audit collapse
into one mechanism: the narrower the rw mount, the more complete the enumeration.

---

## 2. The mount is the only real boundary — and it is stronger than upstream claims

Overlapping bind mounts, re-run on **ext4** (`/dev/mapper/krypton--vg-root`) after a
first run on tmpfs:

```
/dev/… /vault      ext4 ro,relatime,…
/dev/… /vault/inbox ext4 rw,relatime,…
```

Docker orders mounts by destination depth, so `-v vault:/vault:ro` +
`-v vault/inbox:/vault/inbox:rw` gives exactly the intended surface.

| Attempt | Result |
|---|---|
| write new file in `/vault/inbox` | ✅ succeeds |
| write new file in `/vault/finance` (ro) | ❌ `Read-only file system` |
| overwrite existing `/vault/finance/data.md` | ❌ `Read-only file system` |
| rename a top-level dir `mv /vault/finance /vault/finance2` | ❌ blocked |
| `mkdir /vault/.stfolder` at vault root | ❌ blocked |
| **shell** write to `/vault/journal` (outside safe root, on ro mount) | ❌ blocked **by the mount** |
| **shell** write to `/vault/inbox/sub/` (outside safe root, inside rw mount) | ⚠️ **succeeds — terminal escapes `HERMES_WRITE_SAFE_ROOT`** |
| **shell** `rm /vault/inbox/probe-note.md` | ⚠️ **succeeds — deletion inside the rw submount** |

Three consequences:

- **`01`'s "the container bind-mount is the only real boundary" is now verified here,
  not just quoted from upstream** — and it is stronger than stated: the probe ran as
  **uid 0** (the `--entrypoint bash` override bypasses the s6 stage2 hook that drops
  to `HERMES_UID`), and *even root* could not write through the `:ro` mount. A `:ro`
  bind mount holds against the worst case, which is exactly what upstream says
  `HERMES_WRITE_SAFE_ROOT` does not do.
- **`HERMES_WRITE_SAFE_ROOT` as a `:`-separated prefix list works** — `03`'s reading
  of `file_safety.py:84` confirmed empirically. Denial is explicit and legible:
  `Write denied: '/vault/journal/nope.md' is outside HERMES_WRITE_SAFE_ROOT
  (/opt/data:/vault/inbox).`
- 🔴 **The mount enforces *location*, not *creation-only*.** Inside the rw submount
  the shell can overwrite and **delete**. Under `Send-Receive` a deletion propagates
  to krypton *and* the phone (`04`). So the starting proposal's *"new files in
  `inbox/` only"* is **not** mount-enforceable — only *"writes confined to `inbox/`"*
  is. Anything narrower than the mount is instruction, not boundary.

Minor, but it shapes the surface: `write_file` reports `dirs_created: true` — it
**creates parent directories**, so a write to `/vault/inbox/a/b/c.md` silently makes
the tree. Contained by the mount, but the rw path is a subtree, not a flat dir.

---

## 3. `inbox/` has a reader after all — a correction to `07`'s **D9**

`07` **D9** rejected the `inbox/`-note design as *"writing to a queue with no
reader"*, citing `~/vault/daily/` being empty. Half of that holds; half does not.

- `~/vault/daily/` **is** empty — only `.gitkeep`. The dated-archive write never
  happened. ✅
- But **`~/vault/inbox/done/` holds four drained notes**, moved there as recently as
  **2026-07-29** — 8 days before this probe:

  ```
  2026-07-07T1248-custom-keyboard-order-phase1-hardware.md
  2026-07-11T2109-dotfiles-protonmail-bridge-upstream-debt.md
  2026-07-13T2240-obsidian-immich-selfhost-link.md
  2026-07-23T2339-vault-finance-report-crash-unbooked-rows.md
  ```

  `inbox/README.md` documents exactly this: `/daily` *"moves it to `done/`* (audit
  trail, not a hard delete)". So the drain **does** run — intermittently.
- Three notes sit **undrained**: `2026-07-12` (25 days), `2026-07-19` (18 days),
  `2026-08-03` (3 days).

⇒ The reader exists but is **weekend-ish and lossy**, and the map's own Notes already
say `/daily` is dead. This cuts both ways and the grilling should decide which:
it **strengthens** D9 for the *unattended* path (a human drain on an unknown cadence
is not a reader an unattended job may assume) and **weakens** it for the
*conversational* path, where the owner just asked for the write and therefore knows
it is there.

---

## 4. `claude-log/` — a second Bridge-shaped artifact, live right now

Not previously inventoried by this map. `~/vault/claude-log/` is:

- **Agent-written**, by `~/.claude/hooks/log-session.sh`, one file per day
  (`YYYY-MM-DD-daily.md`), one `##` section per Claude Code session. Latest entry
  **2026-08-06 10:30** — today.
- **Synced.** It is absent from `~/vault/.stignore`, so it will replicate to helium
  and the phone.
- By its own README: *"read-only, never curated, **nothing reads it today**."*

Two uses for this ticket:

- **Prior art for item 1.** A machine already writes into this vault daily on an
  append-mostly, one-file-per-day path — and it is driven by a **hook, not by
  judgment**. That is the shape `05`'s `no_agent` write list wants.
- **Candidate read source.** "What did I work on today" is already materialised here
  in prose, which is relevant to the brief and to item 3's read set.

It is also, on its README's own admission, the `Sync/Hermes-Claude-Bridge.md` pattern
the map was founded on — worth naming so Hermes is not made its second instance.

---

## 5. Read surface, measured

| Always-on candidate | Bytes | ≈ tokens |
|---|---|---|
| `AGENTS.md` | 5 347 | 1 340 |
| `glossary.md` | 1 700 | 425 |
| **`tasks.md`** | **56 765** | **14 190** |
| `inbox/README.md` | 1 318 | 330 |
| **core total** | **65 130** | **≈ 16 300** |

Whole-vault markdown, excluding `finance/` and `learning/`: **188 files, 1 093 442
bytes ≈ 273 000 tokens** — and `projects/` is **856 821** of that (79 %). Full-read
as an always-on surface is not on the table; the only question is retrieval vs
curation.

Per-directory markdown bytes:

```
projects  856821   finance  135908   health  38651   learning 37890
zettel     24562   travel    20834   howto   17955   claude-log 16512
people      8750   tools      8449   recipes  7286   templates  6747
inbox       6359   cars       6329   lists    5689   archive    4612
journal        45   home         20
```

Two things fall out of the numbers:

- **`tasks.md` is 87 % of the always-on core.** Any per-turn cost argument is really
  an argument about `tasks.md`, and it is the one file the vault's own `AGENTS.md`
  mandates: *"Read `tasks.md` at the start of any assistant session."*
- **`journal/` is 45 bytes and `home/` is 20.** The map's Notes name
  `journal/` repeatedly as sensitive content streaming to the provider; substantively
  the sensitive-and-large directories are **`finance/`** (136 KB markdown plus 41 MB
  of data files) and **`health/`** (39 KB). This does not reopen egress — settled, and
  provider choice is [ticket 09](../issues/09-choose-inference-provider.md) — but it
  does mean the read set's real weight sits in two directories, not five.

**Provenance (`05` **D2**, newest mtime under the read paths).** The signal is only
alive if the read set contains something that changes often. `tasks.md` (2026-08-03)
and `claude-log/` (daily, today) both qualify; a read set of `journal/` + `people/`
alone would be quiet for weeks, making a stalled replica indistinguishable from a
quiet vault — the exact failure D2 exists to catch.

---

## 6. Versioning does not cover file *creation*

Checked against the docs `11` already cited
([docs.syncthing.net/users/versioning](https://docs.syncthing.net/users/versioning.html),
fetched 2026-08-06), because krypton's staggered versioning is the vault's only undo:

> *"When a file is deleted or replaced due to a change on a remote device, it is
> moved to the trash can."*

> *"Versioning applies to changes received from other devices… If Alice changes a
> file locally on her own computer Syncthing will not and can not archive the old
> version."*

So versioning fires on **replace and delete**, never on **create** — a new file has no
prior version to archive.

**Severity, stated honestly:** this is a *clutter* gap, not a *loss* gap. Overwrite
and delete of existing files — the cases that destroy data, and the ones
`Send-Receive` propagates cluster-wide — **are** covered. "Hermes created 400 junk
files in `inbox/`" has no one-click undo, but nothing was lost; the cleanup is a
manual delete. Worth recording so nobody later assumes versioning covers the
creation-only surface, not worth redesigning around.
