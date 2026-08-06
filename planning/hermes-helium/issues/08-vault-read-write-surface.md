# Decide the concrete vault read/write surface

Type: grilling
Status: resolved
Blocked by: 03, 07

## Question

The posture is settled — **Send-Receive, narrow write surface, Hermes' memory out
of the vault** (map Notes). **Now make "narrow" concrete:** exactly which paths may
Hermes write, how are conflicts and git history used as the safety net, and how is
the boundary enforced rather than merely intended?

### Inherited from ticket `01` (verified 2026-07-31 — don't re-derive)

From [assets/01-engine-research.md](../assets/01-engine-research.md) §5. The engine
now ships a real write-confinement mechanism — and upstream is explicit that it is
**not** a boundary.

- **`HERMES_WRITE_SAFE_ROOT=/opt/data` is set in the official image.** So
  `write_file` and `patch` are *hard-blocked* outside the state volume — not routed
  through approval. **The vault is therefore not writable by default; opening it is
  an explicit act** (adding paths to a `:`-separated safe root). That inverts the
  v0.14 posture, where the vault *was* the working directory. Item 2's "capability,
  not motive" now starts from deny.
- An always-on protected-path denylist applies regardless: `~/.ssh/`, `~/.aws/`,
  `~/.netrc`, Hermes credential stores, and `.env` / `.envrc` **anywhere on disk**.
- **But the terminal tool escapes all of it.** Upstream: *"Write guards apply to
  `write_file` and `patch` only. The `terminal` tool runs as the same OS user and
  can still … overwrite denied paths via shell commands … it does not sandbox a
  hostile or compromised agent."* The managed-scope doc likewise lists *"a hard
  boundary that the agent itself cannot escape"* as out of scope for v1.
- **⇒ The container bind-mount is the only real boundary** — the same conclusion
  vault-serve `03` reached with per-folder `:ro` mounts. Treat
  `HERMES_WRITE_SAFE_ROOT` as defence-in-depth layered on top, and answer item 6's
  "enforced rather than intended" at the mount layer.
- **Two extra levers worth considering here:** `checkpoints` (filesystem snapshots
  before destructive file operations — opt-in, `enabled: false` by default, 20 per
  directory) composes with `~/vault` already being a git repo; and `approvals.deny`
  is a glob list that blocks matching terminal commands **unconditionally, even
  under `--yolo` or `approvals.mode: off`** — the only hard lever against the
  terminal escape hatch, and the only one that works unattended (a `smart`-mode
  escalation cannot reach a human from inside a cron job).
- Memory placement needs no work: memory is files under `~/.hermes/memories/` and
  sessions are SQLite at `~/.hermes/state.db`. Brain-out-of-vault is the default.

### Inherited from ticket `04` (verified 2026-07-31 — don't re-derive)

Send-Receive was applied to `vault-serve` 004, and checking the Syncthing docs
turned up the fact this ticket most needs: **local deletions propagate upstream.**
`Send-Receive` distributes local changes *including deletions* to every peer;
`Receive Only` did not. So a Hermes reorg or delete on helium's copy destroys the
same files on **krypton and the phone** — the blast radius of item 2's
"capability, not motive" is the whole cluster, not one replica. Two corollaries:

- The `:ro`-mount option in item 2 is not merely tidy — it is the only thing that
  makes deletion of non-`inbox/` paths *impossible* rather than *discouraged*.
- Item 5's git question is load-bearing for the same reason: an uncommitted write
  that Syncthing has already pushed is gone everywhere at once.

Also settled there: `.sync-conflict-*` files are **accepted** (item 4 is about
noticing them, not preventing them), and `Ignore Permissions` must stay on —
turning it off to tidy modes would break Perlite's read path.

One correction to item 4's framing: the folder has **three** read-write peers, not
two. krypton *and the phone* were already `Send & Receive` (vault-serve `02`), so
helium is the third — meaning a phone-vs-helium conflict can occur with krypton
uninvolved, and whatever notices conflicts cannot assume krypton is one side of them.

### Inherited from ticket `03` (verified on the box 2026-07-31 — don't re-derive)

This is the ticket `03` changed most, and one item makes "narrow" far cheaper to
express than either ticket assumed.

- **`HERMES_WRITE_SAFE_ROOT` is a `:`-separated list of path *prefixes*, not a single
  root** (`agent/file_safety.py:84`, plus `tips.py`: *"restricts write_file/patch to
  directory prefixes; multiple paths via os.pathsep"*). So "narrow" is expressible
  **natively** — `/opt/data:/vault/inbox:/vault/journal` — with no bespoke mechanism
  to build. `03` sets the baseline to `/opt/data:/vault`; **narrowing the `/vault`
  half is this ticket's job.** Ticket `01`'s caveat still stands and is the reason
  this is not the whole answer: it constrains `write_file`/`patch` but **does not bind
  the `terminal` tool**, and upstream says so — so it is a strong guardrail against
  the agent's *ordinary* file path, not a boundary.
- **The vault is mounted at `/vault`, outside `HERMES_HOME`.** That is deliberate:
  `stage2-hook.sh` chowns `$HERMES_HOME` non-recursively and then recurses over a
  fixed subdir list (`cron sessions logs hooks memories skills skins plans workspace
  home profiles pairing platforms/pairing lazy-packages`), and mounting the vault
  outside puts it beyond that mechanism entirely. **The bind mount remains the only
  real boundary** (ticket `01`), so what is mounted is the outermost control.
- **Hermes writes as `ms` (uid 1000:1000)**, via `HERMES_UID`/`HERMES_GID` — the
  image *rejects* `docker run --user`. So vault-serve `004`'s permission model is
  unchanged (root `700 ms`, contents `755`/`644`) and **file ownership carries no
  information** about whether the agent or the owner wrote a file. Do not design an
  enforcement or audit mechanism that leans on ownership.
- **The git-as-undo premise is gone — do not build on it.** `~/vault/.stignore`
  excludes `.git`, so helium's replica has **no repo**; `.gitignore` deliberately
  untracks finance *data*; and Syncthing versioning was **off on every krypton
  folder**. The owner declined a git audit repo on helium. The vault's undo is now
  **staggered Syncthing versioning on krypton** (ticket `11`) — path-agnostic, covers
  deletions and untracked files, and is author-agnostic. Ticket `04`'s note that
  `004` *"leans on `~/vault` being a git repo as the real undo"* is therefore
  narrowed: git covers only the 215 tracked files on **krypton**, and nothing on helium.
- **`--workdir <dir>` injects `AGENTS.md`/`CLAUDE.md` from that directory.** A job
  with `--workdir /vault` picks up the vault charter for free — which is a *soft*
  instruction channel worth considering alongside the hard prefix list, given the
  map's "Hermes replaces `/daily`" framing.
- **Traceability now lives in `$HERMES_HOME/logs`** (restic-covered), not in the
  vault. If this ticket wants a per-write record inside the vault, that is a new
  decision, not an inherited one.

### Why this needs its own ticket

"Narrow write surface" is currently a *principle*, and principles do not survive
contact with an autonomous agent. The last one **deleted `.stfolder` while
reorganizing** and silently halted sync for up to an hour, diverging both sides
badly. The redesign (memory in `~/.hermes`, vault as data source) removes the
*motive* for that, but not the *capability*.

### What the answer must settle

1. **The write allowlist.** Concretely which paths. Starting proposal, given board
   ownership is out of scope: **new files in `inbox/` only** — one file per note,
   `<YYYY-MM-DDThhmm>-<source>-<slug>.md`, matching the convention the `note` skill
   and the global cross-session rules already use (one file per note specifically to
   avoid clobbering and Syncthing conflicts — that rationale applies doubly here).
   Then decide what else, if anything, earns write access now vs. later.
2. **Enforcement vs. instruction.** Is the boundary a *prompt* (Hermes is told), a
   *mount* (only `inbox/` is writable, the rest `:ro` — the bind-mount pattern
   vault-serve chose as its actual boundary), or *both*? Note vault-serve ticket
   `03` concluded the mount surface **alone** was the real boundary and a
   configured denylist was explicitly *not* trusted. Same reasoning applies:
   prompt-level restraint is not a boundary.
3. **The read surface.** Full-egress is accepted, so this is about *utility and
   cost*, not secrecy: sending the entire vault on every turn is expensive and
   noisy. Decide how Hermes finds what it needs — full read + retrieval, or a
   curated set of always-loaded entry points. The vault's own `AGENTS.md` is
   deliberately structured for this ("a thin always-on core + routers", "load a
   topic's own doc only when the task needs it"), which is a ready-made answer worth
   reusing rather than reinventing.
4. **Conflict handling.** Two writers on `personal-vault` will produce
   `.sync-conflict-*` files. Who notices, and how? (Ticket `05` owns the alerting
   mechanism; this ticket owns *whether it's a condition worth alerting on*.) Also:
   does Hermes ever *resolve* conflicts, or only report them? Recommended: report
   only.
5. ~~**git as the safety net — made real.**~~ **Struck 2026-08-01 — the premise is
   dead** (`03`, `11`, and now `05`). `~/vault/.stignore` excludes `.git`, so
   **helium's replica has no repo at all**; `.gitignore` untracks finance data; and
   Syncthing versioning was off on every krypton folder. There is nothing on helium
   to commit. **The undo is staggered Syncthing versioning on krypton**
   ([ticket 11](11-vault-undo-riders-to-vault-serve-004.md), `maxAge=31536000` —
   *seconds*), and **the write record is `$HERMES_HOME/logs`** (`03`,
   restic-covered). What survives for this ticket: the two are complementary, and
   **the authorship question is still yours** — versioning is author-agnostic and
   cannot say *who* changed a file, so `$HERMES_HOME/logs` is the only thing that
   attributes a write to Hermes. See the `05` inheritance below, which depends on it.
6. **The `.stfolder` marker guard.** Carry the prior-art unit forward (ticket `02`),
   updated for `personal-vault` on helium. Cheap insurance; should never fire.
7. **`~/vault/AGENTS.md` must be rewritten.** It currently says the vault is synced
   to `titan` and "worked on by … Hermes agent (titan)" — stale on both counts, and
   other agent sessions read it as ground truth. This ticket produces the content;
   the map lists it as fog until then.

### Inherited from ticket `05` (resolved 2026-08-01 — don't re-derive)

- **🔴 A hard constraint on the write surface: it must be enumerable from
  `$HERMES_HOME/logs`.** `05`'s **D4** puts a **`no_agent`-generated list of every
  vault write** into the evening brief, printed beside the agent's own prose account
  of its day — so that *"filed 3 invoices"* above an empty write list is a visible
  contradiction. **If a write path exists that does not land in
  `$HERMES_HOME/logs`, D4's cross-check has a blind spot** and this map's
  headline correctness control is holed. Verify per write mechanism, don't assume.
- **Attribution is the reason this matters.** Syncthing versioning (`11`, the only
  undo) is **author-agnostic** — it cannot distinguish a Hermes write from the
  owner's own edit arriving over sync. `$HERMES_HOME/logs` is the *only* thing that
  attributes a change to Hermes. Undo and record are separate mechanisms; this
  ticket needs both to be real.
- **`05` closed the "inspection surface" fog patch, which narrows `08`'s options.**
  There will be **no read-only web surface** — no dashboard (upstream: it stores API
  keys, unsafe on LAN), no Traefik router. Routine visibility is the brief; deep
  inspection is `docker exec`. So "the owner can go and look" is **not** available
  as an enforcement or review story here.
- **Every source carries provenance** (`05` **D2**), and for `/vault` that is the
  **newest mtime under the read paths**. This exists because a **stalled Syncthing
  replica is indistinguishable from a quiet vault** — precisely the v0.14 failure,
  where sync safety-halted with badly diverged sides. `08` should confirm its chosen
  read paths make that mtime meaningful.

### Inherited from ticket `07` (resolved 2026-08-06 — don't re-derive)

- **The email half writes nothing to the vault. Its write surface is zero.** `07`'s
  **D9** rejected the `inbox/`-note design this ticket's siblings assumed, because
  `~/vault/inbox/` is drained by `/daily` and `/daily` is dead (`~/vault/daily/` is
  empty) — filing notes there is **writing to a queue with no reader**, i.e. a rebuild
  of `Sync/Hermes-Claude-Bridge.md`, the map's founding silent-failure example. The
  durable artifact is a Proton label instead, which is attached to the message and
  visible on the phone.
- **⇒ `08` therefore decides vault writes for the *conversational* path only** — where
  the owner has explicitly asked Hermes to file something and a human is in the loop
  for every write. That is a much narrower and easier trust question than "an
  unattended job may create files in your vault", and it means the *unattended* push
  mode needs **no vault write paths in `HERMES_WRITE_SAFE_ROOT` at all**.
- **Read paths are also unaffected by the email half** — triage reads INBOX, not the
  vault. So `08`'s provenance concern (newest mtime under the read paths) stays scoped
  to the conversational/brief sources, not to mail.
- **A useful precedent for "enforced rather than intended" (item 6):** `07` settled its
  boundary by *removing verbs*, not by configuring guards — one verb (`COPY`), and
  `\Seen`/`MOVE`/delete/label-removal prohibited even though all four were **verified
  working** on the live bridge. The narrowest surface was chosen where the mechanism
  was capable of more. Same shape is available at the mount layer here.

---

## Answer

**Resolved 2026-08-06.** The owner's route to it is worth recording, because the first
pass got the process wrong. Asked to choose between the four open questions, the owner
said *"im unsure"* and restated the purpose: *"the idea is that hermes should be my
assistant that takes admin work off my shoulders."* That was **escalated rather than
resolved unilaterally** (the pattern `07` set — see commit `2551771`): the four
questions were collapsed to **the one that is genuinely the owner's** — *does the
conversational path get write access to `~/vault/inbox/` at all?* — with the other
three called on defaults and named as such. Answer: **"agreed"** — `inbox/` write
access is in, as specced below.

**Every capability claim below was probed against the pinned
digest — full transcripts and commands in
[assets/08-write-surface-probe.md](../assets/08-write-surface-probe.md). ⚠️ **helium
was unreachable during this session** (krypton roaming on `10.25.0.x`, NetBird
`SessionExpired`), so the probes ran **on krypton against the same image**, and
`/vault` does not exist on helium yet — vault-serve
[004](../../vault-serve/issues/004-syncthing-role.md) is still open. Mount semantics
were re-run on **ext4** to remove a tmpfs caveat. Read the ✅/⚠️ tags: this is a spec
against partly-unbuilt infrastructure, not an end-to-end verification.

**One-line answer: one writable directory — `/vault/inbox` — enforced by an
overlapping `:ro`/`:rw` bind mount, with the write record produced by a
filesystem manifest diff rather than by Hermes' logs.**

### The owner's steer, and the scope tension it exposes

Asked to choose, the owner said: *"the idea is that hermes should be my assistant that
takes admin work off my shoulders."* That is the right lens, and applied honestly it
points **past this ticket**.

Measured on the real board (2026-08-06): `tasks.md` holds **45 open items**, `🔥 Now`
has **6**, and **8 dated items are already past due** (oldest `📅 2026-07-14` — `06`
counted six on 2026-08-01, so it is getting worse, not better). Every one of the six
`🔥 Now` items is an **action only the owner can take**: a bank transfer before the
28th, a BankID care-provider registration, two phone bookings, chasing a rental-car
overcharge. **Hermes cannot do any of them.** What it can do is make sure none is
missed — and that is [ticket 06](06-urgent-vs-digest-policy.md)'s brief and interrupts,
already decided.

So the honest finding: **the largest share of "admin work off my shoulders" is
`tasks.md` ownership and the inbox drain, which this map ruled Out of scope** as
"the highest-trust, write-heavy path into the live board… too much trust to extend on
day one." That boundary is not re-litigated here. What *is* recorded is that **the
design below graduates to it without redesign**: adding `tasks.md` to the mount and
the safe-root is a two-line change, and the audit mechanism in **D4** already covers
any path added to the writable set. The scope boundary costs a change of
configuration later, not a change of architecture.

The write surface itself is therefore **deliberately modest**, and that is a
consequence of the map's scope, not timidity.

### D1 — The write allowlist: exactly one path, `/vault/inbox`

```yaml
volumes:
  - /data/ssd/vault:/vault:ro                  # whole vault, read-only
  - /data/ssd/vault/inbox:/vault/inbox:rw      # the single writable path
environment:
  HERMES_WRITE_SAFE_ROOT: /opt/data:/vault/inbox
```

Nothing else in the vault is writable. Files follow the convention the vault's own
`inbox/README.md` already mandates — **one file per note**,
`<YYYY-MM-DDThhmm>-hermes-<slug>.md` — which exists *specifically* to avoid clobbering
and `.sync-conflict`s, a rationale that applies doubly with three read-write peers.

**Why not zero.** Considered seriously, and rejected on two grounds. First, the map's
**Destination** names *"capture a note, ask it to file something"* as pull-mode
capability; resolving this ticket to no vault writes would **amend the Destination**,
which is not a mount decision's business. Second, it would make
[ticket 05](05-loud-failure-verification.md)'s **D4** — the `no_agent` write list
printed beside the agent's own prose, this map's headline correctness control —
**vacuous by construction**: an always-empty list contradicts nothing. Under `inbox/`
rw, D4 gets *stronger* than the version `05` specified (see **D4** below).

A capture target inside `$HERMES_HOME` (`/opt/data`) was also considered and is
**worse than `inbox/`, not safer**: it inherits `07`'s **D9** objection in a harsher
form — not one lossy reader but **zero** readers outside Hermes, invisible to
Obsidian, invisible on the phone. `07` chose a Proton label precisely *because* the
artifact lands where the owner already looks. The same reasoning argues **for** a
vault-visible note.

**Why not wider.** `journal/`, `people/`, `health/` and `finance/` get no write
access: nothing in the design demands it, and each would widen the blast radius of a
mechanism that propagates deletions cluster-wide. `tasks.md` is Out of scope.

⚠️ **An honest limitation: the mount cannot separate the conversational path from
cron.** `07`'s **D9** concluded the unattended half needs *no* vault write path, and
that remains the intent — but **both modes run in the same container**, so the cron
jobs inherit `/vault/inbox` write capability whether or not they are supposed to use
it. "Conversational only" is therefore **instruction, not boundary**. This is
accepted rather than engineered around (a second container purely to hold a narrower
mount is more moving parts than the risk warrants), and it is *why* **D4**'s audit is
author-blind: any file appearing in `inbox/` is reported in the brief regardless of
which mode wrote it.

### D2 — Enforcement is the mount. Everything else is defence-in-depth.

`01` concluded the bind mount is the only real boundary by quoting upstream. That is
now **verified here**, and the result is stronger than upstream's claim:

- ✅ **A `:ro` bind mount holds against `uid 0`.** The probe ran as **root** (the
  `--entrypoint bash` override bypasses the s6 hook that drops to `HERMES_UID`), and
  root still could not write to, overwrite, rename, or `mkdir` inside `/vault`.
- ✅ **Overlapping mounts give exactly the intended surface** — Docker orders by
  destination depth, so `/vault:ro` + `/vault/inbox:rw` yields `ro` everywhere except
  the one subtree. Re-verified on ext4.
- ✅ **`HERMES_WRITE_SAFE_ROOT` as a `:`-separated prefix list works** (`03`'s reading
  of `file_safety.py:84`, confirmed empirically) and denies legibly:
  `Write denied: '/vault/journal/nope.md' is outside HERMES_WRITE_SAFE_ROOT
  (/opt/data:/vault/inbox).`
- ⚠️ **But the shell escapes it** — a `terminal` write outside the safe root yet
  inside the rw mount **succeeds**. So the safe-root is a guardrail on the agent's
  *ordinary* file path, not a boundary. Keep it: it turns an accidental
  `write_file` to `/vault/journal/` into a clean error instead of a silent
  no-op-looking success.

🔴 **The mount enforces *location*, not *creation-only*.** Inside `/vault/inbox` the
shell can overwrite **and delete** — verified — and under `Send-Receive` a deletion
propagates to krypton *and* the phone (`04`). So the ticket's starting proposal,
*"new files in `inbox/` only"*, **is not enforceable by any mechanism available**.
It stands as convention; **D4** is what makes a violation visible. Note also that
`write_file` returns `dirs_created: true` — it creates parent directories, so the
writable surface is a *subtree*, not a flat directory.

**Third layer, cheap, recommended:** `approvals.deny` is the one lever that blocks
matching terminal commands unconditionally — *even under `--yolo` or
`approvals.mode: off`* (`01`) — and it is the only one that works unattended, since a
`smart`-mode escalation cannot reach a human from inside a cron job. Deny globs for
recursive-delete and move verbs aimed at `/vault*`. It does not close the escape
hatch (a determined agent can write Python), but it stops the plausible accident.

**`checkpoints` are rejected.** `01` floated them; they no longer compose. They are
opt-in filesystem snapshots *"before destructive file operations"*, and `01`'s appeal
was that they pair with `~/vault` being a git repo — a premise that died in `03`.
With one creation-shaped writable directory there is little for them to snapshot, and
they would put 20-snapshots-per-directory of state on the SSD for no undo the
manifest and krypton's versioning do not already provide.

### D3 — Read surface: mount the whole vault `:ro`; decide *loading* separately

**The mount governs permission; the prompt governs cost.** These were conflated in
the ticket's framing and must not be: a `:ro` mount of the entire vault costs
**zero tokens**. Only what is loaded into a turn costs anything. So the whole vault
is mounted read-only — consistent with the settled full-egress posture, and it keeps
`finance/`'s 41 MB of data files reachable for a question that needs them without a
mount change.

Loading splits by mode, because the two modes have opposite economics:

**Conversational (pull).** Always-on core = the vault's own `AGENTS.md` +
`tasks.md` + `glossary.md` ≈ **16 300 tokens**, then load a topic on demand via the
vault's existing router tables. This **reuses `~/vault/AGENTS.md`'s own structure**
("a thin always-on core + routers", "load a topic's own doc only when the task needs
it") rather than inventing a retrieval scheme — the file was written for exactly this.
`tasks.md` stays always-on because the vault's charter mandates it (*"Read `tasks.md`
at the start of any assistant session"*) and because this path is human-initiated and
turn-bounded, so the cost is paid only when the owner is actually asking something.

**The brief (push) must NOT read `tasks.md` raw.** The decisive fact is not the token
count but *what the tokens are*: `🔥 Now` is **16 663 characters across six items**,
one of them **7 749 characters**, and it is overwhelmingly **accreted historical
reasoning** — superseded estimates, revision notes, resolved sub-questions — not
current state. An agent handed that wall to work out what is due is reading mostly
retracted analysis. So the `no_agent` gathering script parses `tasks.md` for **dated
items and titles** and emits a compact block, exactly the date-math-in-script shape
`06` chose for interrupts. This resolves the cost question **without overriding the
owner's charter**: the charter governs assistant sessions, and the brief's agent is
handed a digest rather than being asked to skip the board.

Not mounted, deliberately: nothing. Not loaded by default: everything except the core
above — `projects/` alone is **856 821 bytes**, 79 % of the non-`finance/` markdown
corpus (**≈273 000 tokens** total), so a full-read default was never available.

Recorded for accuracy, without reopening egress (settled; provider choice is
[ticket 09](09-choose-inference-provider.md)): **`journal/` is 45 bytes and `home/`
is 20.** The map's Notes name `journal/` repeatedly among the sensitive payload; the
substantive sensitive directories are **`finance/`** (136 KB markdown + 41 MB data)
and **`health/`** (39 KB). The read set's weight sits in two directories, not five.

### D4 — The write record: a filesystem manifest diff, **not** `$HERMES_HOME/logs`

🔴 **This overturns `05`'s **D4** premise.** `05` made it a hard constraint that the
write surface be *enumerable from `$HERMES_HOME/logs`*, and told this ticket to verify
per mechanism rather than assume. **Verified, and it fails.** A successful
`write_file` to `/vault/inbox/probe-note.md` produced **zero** mentions in
`agent.log`. Why, from the image's own source:

- `tools/file_tools.py` logs `write_file` **only on failure** (`logger.debug` on
  expected denial, `logger.error` on error). No INFO log of a success.
- `agent/tool_executor.py:879` is the generic tool log:
  `logger.info("tool %s completed (%.2fs, %d chars)")` — **name, duration, result
  length; never the arguments.** It can say *a* write happened, never *where*.
- The only path-level record, `file_state.note_write()`, lives in a **process-wide
  in-memory singleton** (`tools/file_state.py`) capped at `_MAX_PATHS_PER_AGENT =
  4096` with oldest-dropped overflow. It is a subagent concurrency guard — *"prevents
  mangled edits when concurrent subagents… touch the same file"* — and **dies with the
  process.**
- `agent.log` is additionally **lossy by design**: `RotatingFileHandler`, 5 MiB × 3
  backups.
- `terminal` writes are invisible **as writes** — the mechanism that escapes the
  safe-root escapes the log too.

`state.db` does persist tool-call **arguments** (`messages.tool_name` /
`messages.tool_calls`, v23 schema), so a write list is *derivable* from SQLite — but
that is the agent's **self-report of intent**, it misses `terminal` the same way, and
parsing conversation JSON from a `no_agent` shell script is fragile.

**The replacement inverts the mechanism: observe effects, not intentions.** The
`no_agent` gathering script keeps a **manifest** of `/vault/inbox` (path, size, mtime)
under `/opt/data`, and each run **diffs** the live tree against it:

```
inbox writes since 20:00 yesterday:
  + 2026-08-06T0912-hermes-carrent-refund.md   (412 B)
  ~ 2026-08-05T2140-hermes-brf-invoice.md      (modified, 380 → 611 B)
  - 2026-08-04T1102-hermes-kivra-check.md      (DELETED)
manifest: 14 files, 6.2 KB   (previous run: 13 files)
```

Four properties the log-based version could not have:

1. **Mechanism-agnostic.** `write_file`, `patch`, and `terminal` all land in the diff,
   because the diff looks at the filesystem. The terminal blind spot closes.
2. **Complete — *because* the mount is narrow.** `find` over one directory enumerates
   every possible write, and it is provably every one: the `:ro` mount makes writes
   elsewhere impossible. **Enforcement and audit become the same mechanism**, and each
   makes the other stronger.
3. **Catches deletions.** A pure mtime scan cannot see a removed file; a manifest diff
   can. This matters more than creation does — deletion is the case that propagates
   cluster-wide and the case `Send-Receive` makes dangerous.
4. **Cannot be fabricated.** It is `no_agent` output, so it sits beside the agent's
   prose as ground truth, which is precisely what `05` **D4** wanted: *"filed 3
   invoices"* above an empty diff is a visible contradiction.

The manifest must be **absent-manifest = ERROR, never a silent re-seed** — the same
rule `07` applied to its UID watermark, and for the same reason: a silent re-seed
turns a lost audit trail into a clean-looking first run.

⚠️ **One blind spot, recorded rather than buried:** a file **created and deleted
between two nightly runs** is invisible in both directions — it never enters the
manifest, so its deletion is not a diff either. Severity is low (a note that existed
for under a day and is gone leaves nothing to recover, and krypton's versioning
archives the deletion if it ever reached krypton), but it is the audit story's one
hole and this map records those. Closing it would need a filesystem watcher, which is
one more thing that can fail silently — the trade `05` **D3** already made against an
OTLP collector.

### D5 — Attribution: filename convention, with the manifest as ground truth

Neither available mechanism attributes a change: `$HERMES_HOME/logs` does not record
paths (**D4**), krypton's versioning is author-agnostic (`11`), and `03` established
that **file ownership carries no information** because Hermes runs as `ms` (uid 1000)
— the same user as the owner's own edits.

The answer uses what already exists: the inbox convention's `<source>` field.
`<YYYY-MM-DDThhmm>-**hermes**-<slug>.md` attributes by name, for free, in a form
that is legible on the phone and in Obsidian with no tooling.

Convention is not enforcement — so the **manifest diff is the ground truth**. Any file
appearing in `inbox/` that the diff reports is either Hermes' or arrived over sync;
combined with the `hermes-` prefix, a mismatch is visible rather than hidden. That is
accepted as sufficient: the writable surface is one directory, and the undo
(**D7**) does not need to know who wrote anything.

### D6 — Provenance (`05` **D2**): the read paths make the mtime signal live

`05` **D2** requires every source to emit the upstream's own last-updated time, and
for `/vault` that is the **newest mtime under the read paths** — the check that
distinguishes a **stalled Syncthing replica from a quiet vault**, the exact v0.14
failure. With the whole vault mounted `:ro`, the signal is alive: `tasks.md`
(2026-08-03), `inbox/`, and `claude-log/` all change.

**The best staleness canary in the vault is `claude-log/`**, newly inventoried here
(see **D8**): `~/.claude/hooks/log-session.sh` writes it **every day the owner uses
Claude on krypton**, one file per day. So the brief should report the newest
`claude-log/` filename alongside the whole-vault mtime — a replica stalled for more
than a day shows up as a date that should have advanced and didn't. A read set of
`journal/` + `people/` alone would have been quiet for **weeks**, which is precisely
the failure D2 exists to catch.

### D7 — Conflicts: report, never resolve — and now *enforced*, not intended

`.sync-conflict-*` files are **accepted** (`04`) and **worth alerting on**: with three
read-write peers a conflict means two writers raced, and conflicts anywhere in the
tree signal sync trouble regardless of who caused them.

- **Detector:** the same `no_agent` scan, one extra line —
  `find /vault -name '*.sync-conflict-*'`. Whole-vault, which works because the *read*
  mount is whole-vault even though the *write* surface is one directory.
- **Alert path:** the existing MQTT→HA route (`05` **D3**). No new mechanism.
- **Hermes never resolves a conflict** — and this is the one place the ticket asked for
  "enforced rather than intended" and gets it for free: with `/vault` `:ro`, Hermes
  **cannot** touch a conflict copy anywhere outside `inbox/`. The prohibition is a
  mount property, not a prompt line.

The recovery path stays krypton's staggered versioning, and note `04`'s distinction:
**conflicts are preserved by the conflict copy itself, not by versioning** — the older
file is *renamed aside*, never overwritten.

**One gap, recorded at its true severity.** Versioning fires on **replace and delete,
never on create** — docs re-verified 2026-08-06: *"When a file is deleted or replaced
due to a change on a remote device, it is moved to the trash can."* Since the writable
surface is creation-shaped, a burst of junk files in `inbox/` has **no one-click
undo**. This is a **clutter gap, not a loss gap** — nothing is destroyed, the cleanup
is a manual delete, and the cases that *do* destroy data (overwrite, delete of
existing files) **are** covered. Recorded so nobody later assumes versioning covers
the creation surface; not worth redesigning around.

### D8 — Two vault facts this ticket found, both bearing on the design

**1. `inbox/` has a reader after all — a partial correction to `07`'s D9.**
`07` rejected the inbox-note design as *"writing to a queue with no reader"*, citing
`~/vault/daily/` being empty. Half holds: `daily/` **is** empty (only `.gitkeep`), so
the dated-archive write never happened. But **`inbox/done/` holds four drained notes,
moved as recently as 2026-07-29** — eight days before this ticket — exactly as
`inbox/README.md` documents (*"moves it to `done/`* (audit trail, not a hard delete)").
The drain **does** run; it is weekend-ish and lossy. Three notes sit undrained, oldest
**25 days**.

This cuts both ways, and both cuts are honoured: it **strengthens** D9 for the
*unattended* path — a human drain on an unknown cadence is not a reader an unattended
job may assume, which is why `07`'s Proton-label choice for the email half stands
unchanged — and it **weakens** D9 for the *conversational* path, where the owner just
asked for the write and therefore knows it is there.

**And it hands the brief a job that fixes the queue.** Because the brief already
reports `inbox/` writes (**D4**), it can also report the **backlog**: *"3 notes
undrained, oldest 25 days."* The queue-with-no-reader objection dissolves — not by
adding a drainer, but by making the queue's depth a **visible daily condition**
instead of a silent one. The 25-day-old note becomes impossible to keep not noticing.
That is the anti-`Hermes-Claude-Bridge` move, built from machinery this map is already
committed to.

**2. `claude-log/` is a second Bridge-shaped artifact, live right now.**
`~/vault/claude-log/` is agent-written (`~/.claude/hooks/log-session.sh`), one file per
day, latest entry **2026-08-06 10:30**, and **synced** — it is absent from
`.stignore`, so it will replicate to helium and the phone. Its own README says:
*"read-only, never curated, **nothing reads it today**."*

Three consequences: it is **prior art for D1** (a machine already writes into this
vault daily, append-mostly, one file per day — driven by a **hook, not by judgment**,
which is exactly D4's shape); it is the **best staleness canary** (**D6**); and it is
a live instance of the founding failure pattern, named here so Hermes is not made its
second instance.

### D9 — `.stfolder` marker guard: retained, but demoted to insurance

Carry the prior-art unit forward per `02`'s verdict table, with `02`'s three
fail-silent paths made loud, and the owner stays **vault-serve 004** (already
assigned there).

But its risk profile has changed and the spec should say so: with `/vault` mounted
`:ro`, **Hermes cannot delete `.stfolder`** — verified, `mkdir /vault/.stfolder` was
blocked even as root. The v0.14 catastrophe's actual mechanism is now **structurally
impossible**, not merely discouraged. The guard remains worthwhile for non-Hermes
causes (a stray `rsync`, a provisioning mistake, a human `rm`), which is real but is
a different and smaller thing than what it was built for. Cheap insurance; should
never fire.

### D10 — `~/vault/AGENTS.md`: content decided here, edit graduates as a ticket

Item 7 asked this ticket to produce the content. It does — and the **edit graduates as
[ticket 14](14-vault-agents-md-rewrite.md)**, following the
[ticket 13](13-kineret-machine-readable-block.md) precedent, because *"this ticket
produces the content"* names no artifact and a vault file is outside this map.

⚠️ **`--workdir /vault` gives item 7 real teeth, and it is not optional.** Verified in
`cron/scheduler.py:3502`: cron passes `skip_context_files=not bool(_job_workdir)`, so
the vault's `AGENTS.md` reaches the brief **only if the job sets a workdir**. It is
therefore a live instruction channel to the unattended path, not documentation
housekeeping — and `14` should be built and verified as such.

Three stale claims to fix, and one that needs a **decision** rather than an edit:

- *"synced via Syncthing (krypton · phone · titan)"* → krypton · phone · **helium**.
- *"worked on by … Hermes agent (titan)"* → Hermes on **helium**, and state its
  surface: **reads the whole vault, writes only `inbox/`, never reorganizes.**
- *"`daily.md` … once the pipeline is wired up"* — the pipeline was never wired and
  `/daily` is dead (map Notes). Say what is true.
- 🔴 **`"assume only one device runs an assistant at a time"` becomes false** the
  moment Hermes runs on helium while Claude runs on krypton. This is a real rule
  change, and the replacement follows from D1: *there are now two concurrent
  assistants on three read-write peers; **never** assume exclusivity. Prefer
  append-mostly edits and one file per note. Hermes writes only `inbox/`, so a
  collision outside `inbox/` is between a Claude session and the phone.
  `.sync-conflict-*` copies are expected, are never resolved automatically, and are
  reported in the evening brief.*

### D11 — Two build-time traps that would fail silently

**1. 🔴 Docker root-creates a missing bind source.** Verified: with
`-v /data/ssd/vault/inbox:/vault/inbox:rw` where the host path does **not** exist,
Docker creates it **`root:root`**. Hermes runs as **uid 1000**, so its only writable
path would be **unwritable** — and on a fresh helium this is the *likely* case, because
`inbox/` arrives via Syncthing from krypton and `004` mandates the folder start
**genuinely empty**. It also pushes a root-owned directory upstream under
`Send-Receive`, the class of thing `004` explicitly warns about.

⇒ The Hermes service must **not be what creates `inbox/`**. Guard it: a startup
precondition that `/vault/inbox` exists **and is writable by uid 1000**, and that
`ERROR`s loudly and refuses to run otherwise — never creating it, never continuing.
This is `05`'s fail-closed discipline applied to the one directory the whole write
surface depends on.

**2. The mount layout belongs to the Hermes service spec, not to `004`.** Following
`03`'s precedent (which specced the compose service without amending vault-serve),
**no third amendment to `004` is made here.** `004` is the Syncthing role; the mounts
above are consumed by the Hermes implementation issue, which does not exist yet. The
one item that *would* have been a rider — pre-creating `inbox/` — is deliberately
resolved the other way in trap 1: the service **verifies** rather than the role
**creates**, so `004`'s "leave the folder genuinely empty" rule stays intact.

### Corrections to closed tickets

- 🔴 **`05` **D4**'s premise is false** — the write surface is **not** enumerable from
  `$HERMES_HOME/logs` (proven, not argued). Replaced by the manifest diff in **D4**,
  which is strictly stronger: mechanism-agnostic, deletion-aware, unfabricatable.
- ✅ **`02`'s SOUL.md worry is structurally satisfied** — `cron/scheduler.py:3504`
  passes **`load_soul_identity=True`** independently of `skip_context_files`, with the
  comment *"Cron jobs should always inherit the user's SOUL.md identity from
  HERMES_HOME."* So SOUL.md always loads for cron jobs. `05`'s requirement to **assert
  on content, not existence** still stands — `hermes doctor`'s `✓ SOUL.md exists` is
  green on the image's own 513-byte default.
- ✅ **`06`'s `skip_memory` finding independently confirmed** at
  `cron/scheduler.py:3504` — *"Cron system prompts would corrupt user
  representations."* (`cli.py:4468`, which also mentions `skip_memory`, is the
  `--ignore-rules` path, **not** cron — worth knowing, since it is the grep that
  looks like the answer and isn't.)
- **`07`'s **D9** is partially corrected** — see **D8**. Its conclusion for the email
  half stands entirely; only the *"no reader"* premise is narrowed to *"an
  intermittent, lossy human reader."*
- **Map Notes drift:** git tracks **249** files in `~/vault` today, not 215.

### Done when

1. The Hermes service mounts `/data/ssd/vault:/vault:ro` **plus**
   `/data/ssd/vault/inbox:/vault/inbox:rw`, and a deliberate test proves the surface:
   a write to `/vault/inbox` succeeds, and writes to `/vault/journal`, `/vault/tasks.md`
   and `/vault/.stfolder` all fail — **including from a shell** (`docker exec`), not
   only via `write_file`.
2. `HERMES_WRITE_SAFE_ROOT=/opt/data:/vault/inbox`, verified by the legible denial
   message on an out-of-prefix `write_file`.
3. `approvals.deny` blocks recursive-delete/move globs against `/vault*`, verified
   under `approvals.mode: off`.
4. The startup precondition **refuses to run** when `/vault/inbox` is missing or not
   writable by uid 1000 — tested by renaming it, and confirming a loud failure rather
   than a container that starts and quietly cannot capture.
5. The evening brief prints the **manifest diff** (creations, modifications,
   **deletions**) beside the agent's prose, plus the **undrained-`inbox/` backlog with
   the oldest note's age**, plus the newest `claude-log/` date as the staleness canary.
   A missing manifest is an **ERROR**, never a silent re-seed.
6. A conflict-copy scan over the whole vault runs in the same script and alerts via
   MQTT→HA; Hermes resolves nothing.
7. The brief's `tasks.md` block is **script-generated** (dated items + titles), and the
   brief's agent is never handed raw `tasks.md`.
8. Cron jobs that must see the vault charter set **`--workdir /vault`**, verified by
   confirming `AGENTS.md` content reaches the prompt.
9. [Ticket 14](14-vault-agents-md-rewrite.md) is resolved — `~/vault/AGENTS.md` no
   longer claims titan, no longer claims one-assistant-at-a-time, and states Hermes'
   read/write surface.
