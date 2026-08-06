# Rewrite ~/vault/AGENTS.md for helium, Hermes' real surface, and two assistants

Type: task
Status: resolved
Blocked by: 08

> ✅ **Unblocked 2026-08-06** — `08` resolved with the `inbox/`-only write surface
> confirmed by the owner, so item 4's replacement wording below is final as written.

## Question

Apply [ticket 08](08-vault-read-write-surface.md)'s **D10** to the vault's own charter
file. The content was decided in `08`; this is the mechanical follow-through — the same
shape as [ticket 04](04-respec-vault-serve-004-send-receive.md),
[ticket 11](11-vault-undo-riders-to-vault-serve-004.md) and
[ticket 13](13-kineret-machine-readable-block.md): a decision in this map that changes
a file **outside** it.

It exists as a ticket because `08` item 7 said *"this ticket produces the content"*,
which names no artifact — and no implementation issue exists to inherit the edit.
Ticket `13` exists for exactly this reason; this is the same gap, caught earlier.

## Why it is not documentation housekeeping

⚠️ **`~/vault/AGENTS.md` is a live instruction channel to the unattended agent.**
Verified in `08`: `cron/scheduler.py:3502` passes
`skip_context_files=not bool(_job_workdir)`, so a cron job with **`--workdir /vault`**
gets this file injected into its prompt. Whatever it says will be read by the evening
brief, every night, unattended. It is currently **wrong about the host, wrong about
which agent runs, and wrong about concurrency.**

Other agent sessions also read it as ground truth (it is the vault's charter), so a
stale claim propagates into their reasoning too — `08` and `03` both had to correct
map-level beliefs that traced back to it.

## The change

Four items. The first three are corrections; **the fourth is a rule change**, and it
is the one to get right.

1. **Sync peers.** *"synced via Syncthing (krypton · phone · titan)"* → krypton ·
   phone · **helium**. titan is decommissioned (map Notes).
2. **Which agent, and its surface.** *"worked on by … Hermes agent (titan)"* → Hermes
   on **helium**, and state what it may actually do, per `08` **D1**: **reads the whole
   vault, writes only `inbox/`, never reorganizes.** State it as fact, not aspiration —
   it is enforced by an overlapping `:ro`/`:rw` bind mount, so a session reading this
   file can rely on it.
3. **`daily.md`.** *"generated live 'today' page (once the pipeline is wired up)"* —
   the pipeline was never wired, `~/vault/daily/` is empty, and `/daily` is dead (map
   Notes). Say what is true rather than describing an intention. Note the neighbouring
   claim about `daily/YYYY-MM-DD.md` being *"written by `/daily` runs"* has the same
   problem — but see the nuance in `08` **D8**: the **inbox drain did run** as recently
   as **2026-07-29** (`inbox/done/` holds four drained notes); it is the dated-archive
   write that never happened. Correct it precisely; do not overstate the death.
4. 🔴 **The concurrency rule is now false.** *"Syncthing: edits can collide mid-sync —
   prefer append-mostly edits, keep to a few files per session, **assume only one
   device runs an assistant at a time**."* The last clause stops being true the moment
   Hermes runs on helium while Claude runs on krypton. `08` **D10** decided the
   replacement:

   > There are now **two concurrent assistants** on **three read-write peers**
   > (krypton, phone, helium). **Never assume exclusivity.** Prefer append-mostly
   > edits and one file per note. Hermes writes only `inbox/`, so a collision outside
   > `inbox/` is between a Claude session and the phone. `.sync-conflict-*` copies are
   > expected, are **never resolved automatically**, and are reported in the evening
   > brief.

   Keep the surrounding advice (append-mostly, few files per session) — it gets *more*
   load-bearing, not less.

## Constraints

- **Keep the file thin.** Its own charter says so: *"This file is deliberately thin: an
  always-on core + routers. Don't front-load everything."* `08` **D3** then made that
  structure load-bearing — the conversational read surface *is* this file plus
  `tasks.md` plus `glossary.md`, ≈16 300 tokens always-on. **Every line added here is
  paid on every conversational turn.** Net bytes should not grow much; items 1–3 are
  replacements, and item 4 is roughly a wash.
- **Don't append dated narration** — the file explicitly forbids it (*"condense it into
  the right line here… git history is the changelog"*).
- The vault is a **Send-Receive** replica with three peers; this edit lands on
  **krypton** (the authoritative copy) and syncs from there.
- `CLAUDE.md` is a symlink to `AGENTS.md` — no second edit needed.

## Done when

- `~/vault/AGENTS.md` contains no reference to titan, and names helium.
- It states Hermes' surface: whole-vault read, `inbox/`-only write, no reorganization.
- The one-assistant-at-a-time claim is gone, replaced per item 4.
- The `daily.md` / `daily/` claims match reality, including the `inbox/done/` nuance.
- File size has not materially grown (it is paid per turn — see Constraints).
- Committed in `~/vault`'s local git (249 tracked files; **never** pushed — the repo
  holds bank data and has no remote by design).

## Answer

**Applied. `~/vault/AGENTS.md` @ `be9314e`** — *"AGENTS.md: helium not titan, Hermes'
inbox-only surface, no exclusivity"*. All four items landed; **one clause of `08` D10 was
deliberately not written** (item 4, below). Committed on **krypton** (the authoritative
copy) touching **only** `AGENTS.md` — the vault tree was dirty with a dozen unrelated
changes, so the commit named the path rather than staging broadly, and the untracked
`CLAUDE.md` symlink was left untracked so the 249-file count is unchanged.

### What each item became

1. **Sync peers** — `krypton · phone · titan` → `krypton · phone · helium`. No occurrence
   of *titan* remains in the file (`grep -i titan` → no match).
2. **Which agent, and its surface** — *"Hermes agent (helium — **reads the whole vault,
   writes only `inbox/`, never reorganizes**; enforced by its mount, not by prompt)"*.
   The trailing clause is the part that earns a session's reliance: `08` **D1**/**D2**
   make this a mount property, and saying *why* it is trustworthy is worth its bytes.
3. **`daily.md` / `daily/`** — rewritten to `08` **D8**'s precision: the dated archive was
   *"never written — `daily/` is empty"*, while the **inbox drain does run** (*"drain
   `inbox/` into `inbox/done/`, on a weekend-ish and lossy cadence"*). `daily.md` is
   *"planned … never generated"*. The old line's operative consequence — `📅`-dated items
   and birthdays must surface **late rather than never** — was kept; it survives the
   correction intact and is the only actionable part.
   ⚠️ **The `2026-07-29` date was deliberately omitted.** D8's evidence for "the drain runs"
   is a last-run date, but a hardcoded date in an always-on file goes **stale silently** —
   the exact class this map exists to kill. *"weekend-ish and lossy"* is true today and
   stays true; the dated evidence lives here and in `08`, where it is timestamped.
4. **The concurrency rule** — the exclusivity clause is gone (`grep "one device"` → no
   match), replaced with *"prefer append-mostly edits, one file per note, a few files per
   session, and **never assume exclusivity**: two assistants run concurrently (Claude on
   krypton, Hermes on helium) over three read-write peers. Hermes writes only `inbox/`, so
   a collision outside `inbox/` is a Claude session vs. the phone."*

### 🔴 One deviation from D10, and it is this map's own enemy class

D10's replacement wording ends *"`.sync-conflict-*` copies are expected, are never resolved
automatically, and **are reported in the evening brief**."* **That last clause was not
written.** It is a forward-dated claim about a *reporter*, and unlike the others it is
**acted upon**: a Claude session that finds a `.sync-conflict-*` today, reads that a nightly
job reports it, and therefore stays silent — while **no brief exists**. `05` designed it,
`08` **D7** specced the detector, nothing is built. That is `Sync/Hermes-Claude-Bridge.md`
reached through this map's own artifact: a writer believing in a reader that isn't there.

Written instead: *"are **never** resolved automatically — **flag them to the owner**."*
True today with no brief, still true once the brief exists (the brief becomes an
*additional* reporter, not the only one), and **fewer bytes**. The detector half of D7 is
unaffected — it is a `no_agent` scan on helium, and nothing in this file bears on it.

The two *other* forward-dated statements were written present-tense as D10 mandates,
because nobody acts on them: a **peer list** is descriptive (and leaving `titan` is
strictly worse than naming helium early), and *"never assume exclusivity"* is safe advice
**today regardless of Hermes** — the phone has always been a second writer, so the clause
it replaces was arguably already false before this map existed.

### Size — the Done-when that needed a number

**5347 → 5763 bytes, +416 (+7.8 %).** Two framings, because the constraint is *paid per
turn*: +7.8 % of this file, but **+0.6 % of `08` **D3**'s ≈16 300-token always-on surface**
(≈105 tokens/turn). Items 1 and 3 were roughly a wash; **item 4 is where the growth is**,
and it is content `08` **D10** mandates — trimming it further would cost the *why*
(which collision is possible where), which is the part that changes behaviour. Judged
immaterial at 0.6 % of the read surface rather than trimmed. Dropping the evening-brief
clause saved ~55 of those bytes.

### Verified, not assumed

Every premise re-checked on krypton rather than inherited — commands so the next reader
re-runs rather than re-derives:

| Claim | Check | Result |
|---|---|---|
| `daily/` empty | `ls -la ~/vault/daily/` | only `.gitkeep` ✅ |
| drain ran 2026-07-29 | `stat -c '%n %z' ~/vault/inbox/done/*` | **ctime** `2026-07-29 11:58` on the newest (mtimes are the *notes'* dates, 07-07→07-23 — a move preserves mtime, so ctime is the drain evidence) ✅ |
| 3 notes undrained | `ls ~/vault/inbox/*.md` | 3, oldest `2026-07-12` ✅ |
| 249 tracked files | `git ls-files \| wc -l` | 249 ✅ |
| `CLAUDE.md` is a symlink | `ls -l ~/vault/CLAUDE.md` | `-> AGENTS.md` ✅ no second edit |
| `daily.md` absent + ignored | `ls daily.md`; `grep daily .gitignore` | absent; ignored at `:18` ✅ |
| no conflicts pending | `find . -name '.sync-conflict-*'` | none ✅ (nothing for the new rule to trip over) |

### Two things left alone on purpose

- **`~/vault/.gitignore:17`** carries the *same* stale claim this ticket killed —
  `# Live "today" page — generated by /daily once the pipeline is wired up`. Real, and
  outside this ticket's Done-when; a comment in an ignore file is read by humans editing
  that file, **not** injected into any agent prompt, so it lacks the property that made
  `AGENTS.md` urgent. Recorded, diff not widened. Free to fix alongside the next
  `.gitignore` change.
- **The vault-map row** *"`inbox/` (drained by `/daily`)"* is **still true** per D8 and was
  left as-is. Hermes' write into that same queue is stated in the header paragraph; saying
  it twice costs per-turn bytes for no new information.
