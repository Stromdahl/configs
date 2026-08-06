# 025 — Email triage: one label, on the mail that means something

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [024](024-brief-remaining-sources.md)

## What to build

The mail half. **"Filing" means applying one label, and nothing else** — no moves, no replies, no
vault writes, no read flags.

- **One verb: copy into a `hermes-*` label namespace.** Ticket `07` verified on the live bridge
  that moves, custom keywords and even label removal all work — the prohibitions are **judgements,
  not limits**, so don't "fix" them later without reading why.
- **Exception-only, never a classification of everything.** "412 labels applied" is uncheckable by
  anyone and would hide a drifted classifier for months. Only the small minority that means
  something needs doing gets touched.
- **Four topical buckets — bill, escalation, action, unsure — deliberately not severity-based**, so
  the interrupt policy remains the single owner of urgency. Mail it cannot classify goes to
  **unsure** rather than being guessed at.
- 🔴 **Never set the read flag and never move a message.** The document pipeline sharing this
  mailbox fetches **only unseen inbox mail**, so marking read (or moving) first means an invoice's
  attachments are **never ingested, silently**. Every read must peek; ⚠️ **a bare body fetch sets
  the flag implicitly**.
- **A UID watermark is the "already examined" signal, not the read flag** — the mailbox holds 444
  messages and 2 unseen, so the flag carries no information here. ⚠️ **A changed mailbox-validity
  id and an absent watermark are both `ERROR`, never a silent re-seed** — and the bridge
  self-updated unattended once already, so its cache and anything derived from it is not stable
  state.
- **One shared bridge session** with the document pipeline — deliberately, because that makes this
  brief's provenance check the monitor that pipeline never had. ⚠️ The bridge publishes no ports,
  so the consumer must be a container on its internal network. Its session also **dies silently**
  when invalidated, which is precisely what provenance catches.
- **Outbound mail is a documented non-capability, not a blocker** — no verb here needs a send path.
- **The examined/flagged ratio rides the footer, not the mail section.** 🔴 That is load-bearing:
  the section is allowed to collapse on a zero-flag day, and without the ratio in the
  never-collapsing footer, a classifier that has quietly stopped flagging would read as a calm
  inbox. The footer also carries the skipped-backlog count.
- **Mail is not interrupt-eligible** — its only channel is the evening brief.

**Out of scope here, deliberately:** feeding the finance importer from these labels (it would give
them a second consumer with different correctness needs before the first is trusted), and Kivra,
which has no IMAP at all and is already a weekly human check — so the brief must never imply it
watches everything official.

## Acceptance criteria

- [ ] A bill in the inbox gets exactly one `hermes-*` label; ordinary mail gets none.
- [ ] Mailbox-wide, **no message's read flag changes** and no message moves, verified before and
      after a run.
- [ ] The document pipeline still ingests a test invoice's attachments after Hermes has examined it.
- [ ] Ambiguous mail lands in **unsure** rather than a confident bucket.
- [ ] Re-running examines only mail past the watermark.
- [ ] A changed mailbox-validity id produces `ERROR` and **no re-seed**; an absent watermark does
      the same.
- [ ] The footer shows examined and flagged counts, and the skipped-backlog count.
- [ ] With zero flags, the mail **section** may be absent while the footer still shows the ratio.
- [ ] No vault file is written by the mail path at all.

## Blocked by

- [024 — The brief's remaining sources](024-brief-remaining-sources.md) — the ratio and backlog
  counts ride the footer this chain has been building.
