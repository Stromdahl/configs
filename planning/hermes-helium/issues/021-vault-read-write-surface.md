# 021 — The vault surface: read everything, write one directory

Type: execution
Status: resolved
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [020](020-pull-mode-dm-only.md), and externally on `planning/vault-serve/issues/004`

## What to build

The thing that makes pull mode useful, and the boundary that makes the founding catastrophe
**structurally impossible** rather than merely forbidden: Hermes can read the whole vault and
write exactly one directory in it.

- **Whole vault mounted read-only; the inbox directory made writable by an overlapping
  read-write bind mount.** ⚠️ A read-only mount holds even against uid 0, but it enforces
  **location, not creation-only** — so it stops a reorganization, not clutter.
- ⚠️ **The service must verify its writable path exists and must never create it.** Docker
  root-creates a missing bind source, which silently yields a root-owned directory the agent
  cannot use.
- **Reading separates permission from cost**: mount everything read-only (free), but
  always-load only the measured ~16 300-token surface. 🔴 **Never hand the agent the raw board
  file** — its top section alone is ~16 700 characters of largely superseded reasoning.
- **Captured notes follow the vault's existing one-file-per-note convention**, tagged with
  Hermes as the source, so the same drain already handles them.
- **The agent's own memory stays on its state volume, never in the vault.** The vault is a data
  source it reads and files into — never its brain. That is what ended attempt four: the last
  Hermes reorganized the vault, deleted a sync marker, and stalled Syncthing with badly
  diverged sides.

⚠️ **External blocker: the Send-Receive vault replica** (`planning/vault-serve/issues/004`).
That ticket also owns the vault's **only undo** — staggered Syncthing versioning on krypton,
whose retention field is **in seconds**, so the human-friendly number yields six minutes of
history while looking configured. Do not build this ticket against a replica without it.
Note also that versioning fires on **replace and delete, never on create**, so the
creation-shaped write surface has no one-click undo — clutter, not loss.

## Acceptance criteria

- [x] From the phone, a question about the board gets an answer drawn from the real vault.
- [x] From the phone, "capture this" produces one new note file in the vault inbox, in the
      existing naming convention, tagged as Hermes-sourced, and it reaches krypton.
- [x] A write attempt **anywhere else in the vault fails**, including as uid 0.
- [x] The service refuses to start rather than creating a missing writable path.
- [x] The always-loaded context is **measured** and recorded, and the raw board file is not
      part of it.
- [x] The agent's memory lives on the state volume; nothing agent-authored appears outside the
      vault inbox.
- [x] **Confirmed, not performed:** vault-serve `004` is closed with its own round-trip
      versioning test passed and the retention value in **seconds**. That test belongs to `004`
      (ticket `11` handed it there, and item 1 is a **krypton** change outside helium's play) —
      this ticket only checks it happened, and stops if it didn't.

## Blocked by

- [020 — Pull mode](020-pull-mode-dm-only.md) — the demo for this ticket *is* a DM exchange.
- **External:** `planning/vault-serve/issues/004` — the Send-Receive replica and its versioning.

## Progress (2026-08-13)

**Premise checked before building anything, per the map's own doctrine:** read krypton's live
Syncthing `config.xml` directly rather than trusting `004`'s `Status: resolved` — `personal-vault`
is `type="sendreceive"`, `versioning type="staggered"` with `maxAge=31536000` (the field this
map's own Notes warn "looks configured when wrong" at a 10× smaller value). Confirmed on helium:
`/data/ssd/vault` exists, owned `ms:ms`, `.stignore` contains `.git`. The external blocker is
real, not just claimed.

**The load-bearing unknown, resolved by reading the pinned image's own source (`docker exec`,
not assumed):** `08` established cron reaches the vault's `AGENTS.md` only with `--workdir
/vault`; nobody had established what the Telegram/gateway path uses. `agent/runtime_cwd.py`
(`resolve_agent_cwd`/`resolve_context_cwd`) is the single source of truth for context-file
discovery, the terminal tool's cwd, *and* cron jobs with no per-job `workdir` — all three read
one env var, `TERMINAL_CWD`. It was unset. Measured before changing anything:
`hermes prompt-size --platform telegram` showed `context (AGENTS.md/cwd files): 0 B`. Without
addressing this, a DM session had no route to the vault's naming convention or its
never-reorganize instruction at all. Fixed by setting `TERMINAL_CWD=/vault` directly (bypasses
the `MESSAGING_CWD`/docker-workspace placeholder machinery entirely — `TERMINAL_CWD` set to a
non-placeholder value is returned verbatim by `gateway/cwd_placeholder.py`).

**Built:**
- `docker-compose.yml.j2`: `${HERMES_VAULT_PATH}:/vault:ro` plus the narrower
  `${HERMES_VAULT_PATH}/inbox:/vault/inbox:rw` (Docker resolves the more specific mount inside
  the read-only tree — the parent stays read-only, including against uid 0, while `inbox/` alone
  is writable). `TERMINAL_CWD=/vault` and `HERMES_WRITE_SAFE_ROOT=/opt/data:/vault/inbox` added
  to `environment:`. 🔴 The write-safe-root var **replaces** the image's own default rather than
  extending it (`Dockerfile` ships `ENV HERMES_WRITE_SAFE_ROOT=/opt/data`) — `/opt/data` had to
  be repeated in the same value or Hermes' own memory writes (criterion 6) would have broken.
- `host_vars/helium/vars.yml` + `stack.env.j2`: `hermes_vault_path` aliasing
  `syncthing_vault_path`, same pattern as `arr_puid`/`jellyfin_puid`.
- `tasks/stack.yml`: a pre-flight `stat` + `assert` that fails the whole deploy if
  `{{ hermes_vault_path }}/inbox` doesn't already exist, isn't a directory, or isn't owned `ms` —
  compose_stack can never let Docker root-create it.
- `hermes-healthcheck`: standing check (`/vault/AGENTS.md` present, `/vault/inbox` present and
  writable) as defense-in-depth beyond the one-time ansible assert, so a hand-run
  `docker compose up` or the mount later disappearing would also surface as unhealthy.

**Deployed:** `--check --diff` first (clean), then for real —
`ansible-playbook site.yml --limit helium --tags compose` (never a full play; issue `028`'s
ufw/iptables-persistent eviction). `docker compose up -d` recreated the container (confirmed via
a fresh `Created` timestamp, not just the `Restart hermes-agent` handler firing, which would not
have picked up new mounts).

**Verified on the live container, both mounts and both directions:**
- `docker inspect` mounts: `/data/ssd/vault -> /vault (ro)`, `/data/ssd/vault/inbox ->
  /vault/inbox (rw)`.
- Write inside `/vault/inbox` (default uid 1000): succeeds.
- Write to `/vault/finance/` — direct path, **and** via `/vault/inbox/../finance/` traversal —
  fails `Read-only file system`, **at both default uid and `-u 0`**. `cap_drop: ALL` (already
  set for this service) removes `CAP_DAC_OVERRIDE`, so root inside the container still can't
  override the mount's read-only bit — "structurally impossible" is now a verified claim, not an
  assumption about uid 0 specifically.
- Re-measured after the change: `context (AGENTS.md/cwd files)` went from 0 B to **5,881 B**
  (`system_prompt.bytes` total 21,768 B), essentially all of it `AGENTS.md` (5,771 B on disk —
  the gap is formatting overhead). `tasks.md` is 57,086 B and does **not** appear in the context
  tier — confirmed excluded, only reachable via an explicit `read_file` tool call (measured at
  43,152 chars when the live board-query test below actually made one). Full breakdown recorded
  via `hermes prompt-size --platform telegram --json` on the box; this map's earlier ~16,300-token
  estimate (`08`) is in the right range once tool-schema JSON (46,874 B, a separate always-sent
  budget line) is added to the system-prompt total.

**Live acceptance test, both halves run by the owner from his phone, `@harmes_helium_bot`:**
- `"what's overdue on tasks.md"` → `agent.log`: `Session snapshot created (session=…,
  cwd=/vault)`, then `tool read_file completed (43152 chars)`, then a 1,124-char real answer
  delivered over Telegram. (A first message, `"what's on my board right now"`, was superseded by
  this one via the engine's own mid-run interrupt — expected multi-message behavior, not a
  defect.)
- `"capture this: wayfinder 021 vault surface test"` → `tool write_file completed (299 chars)`,
  landing as `/data/ssd/vault/inbox/2026-08-13T1519-hermes-wayfinder-021-vault-surface-test.md`
  — exact `<timestamp>-<source>-<slug>.md` convention, `hermes` as source, 33-byte body. Appeared
  on krypton at `~/vault/inbox/` within the next sync cycle (checked ~5s later, already present).
  Deleted afterward (throwaway probe, per this map's own "probe with new files only, never edit
  an existing vault file" caution) — the delete will propagate and pick up a staggered version on
  the receiving replicas, per `11`.

**Criterion 6** (memory never leaves the state volume) holds by the same construction verified
above: `HERMES_HOME=/opt/data` is a separate mount from `/vault`, and the only writable path
inside `/vault` is `inbox/`.

With `016`–`020` already resolved, `021` closes the pull-mode chain — Hermes now reads the real
vault and writes exactly one directory in it, verified rather than assumed. The frontier moves to
[022 — the interrupt channel](022-interrupt-channel.md).
