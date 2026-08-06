# Rewrite ~/vault/AGENTS.md for helium, Hermes' real surface, and two assistants

Type: task
Status: open
Blocked by: 08

> ⚠️ **Contingent.** `08` is still `claimed`, not resolved — its **D10** is a *proposal*
> pending the owner's confirmation. Items 1–3 below are corrections of plainly stale
> facts and hold either way; **item 4's replacement wording depends on `08`'s write
> surface landing as proposed.** Don't build this until `08` is resolved.

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
