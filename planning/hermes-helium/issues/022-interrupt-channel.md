# 022 — The interrupt channel: one message, two days before

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [021](021-vault-read-write-surface.md)

## What to build

The first push channel, and the one with **no model in it**: a scheduled script that notices
anything dated two days out and says so once. Because it is date arithmetic rather than
judgment, an interrupt **cannot** be a hallucination.

- **A script-only scheduled job** — no agent call. Silent when all is well: a zero exit with no
  output is silence, while a **non-zero exit is reported** by the engine, so failure is loud and
  quiet means nothing was due.
- **Edge-triggered, T-2, fire-once.** 🔴 Measuring the real board killed the obvious rule: **six
  dated items were already past due**, the oldest by over two weeks, and the board holds **zero**
  completed items because it is pruned by deletion. A level-triggered "due or overdue" test
  therefore fires six times on day one and forever after — the mute reflex delivered by the
  anti-mute feature.
- **A seeded-and-announced cold start**: on first run, record what is already past without
  firing for each, and say that it did so. Never silently swallow the backlog.
- **State for what has already fired lives on the state volume**, not in the vault.
- **Delivery is job configuration, never prompt text.** ⚠️ Scheduled jobs have messaging
  disabled, so any instruction to "send this" is unexecutable *and* invites a silent
  non-delivery.
- **Mail is not interrupt-eligible** (`06` D1): the mailbox's signature failure is *looking
  fine*, and a false interrupt from a misread invoice is exactly the mute trigger. Accepted
  cost: a bill arriving at 09:00 due tomorrow waits for the 20:00 brief.
- **Grace is half the period capped at two hours; missed runs collapse to a single catch-up
  fire.**

This ticket establishes the script-on-volume, scheduled-job and delivery path that `023`
reuses — which is why the push chain is deliberately linear.

## Acceptance criteria

- [ ] A board item dated two days out produces **exactly one** Telegram message.
- [ ] The same item on every later run produces **nothing**.
- [ ] A first run against the real board **seeds and announces** the existing backlog instead of
      firing once per overdue item.
- [ ] A day with nothing due produces **no message at all** — and that silence is distinguishable
      from a broken job, because a failure exits non-zero and is reported.
- [ ] Date arithmetic is done in the script; no prompt text and no model call is involved.
- [ ] Fired-state survives a container restart.
- [ ] No prompt text anywhere instructs the agent to send a message. **Not a duplicate of
      `018`'s identical criterion** — that one checks what was *recovered*, this one checks what
      this ticket *wrote*. Both are needed; neither covers the other.

## Blocked by

- [021 — The vault surface](021-vault-read-write-surface.md) — the dates come from the vault, so
  the read mount must exist first.
