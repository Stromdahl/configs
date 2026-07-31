# Decide the email triage contract — what "filing" concretely means

Type: grilling
Status: open
Blocked by: 01, 05

## Question

The owner's ask: *"I shouldn't need to check my emails all the time. The agent
should categorize and file whatever is needed."* **What does "file" actually mean,
given what the Proton bridge can and cannot do?**

### The constraint that shapes this

Proton Mail Bridge is live on helium (issue `029`, since 2026-07-10) serving IMAP
for `mattias.stromdahl@pm.me`. But:

- **SMTP send is broken** — `454 4.7.0 unknown error`. IMAP receive is fine. So
  Hermes **cannot reply, forward, or send** through the bridge as it stands. Any
  design that assumes "the agent handles the email" by *replying* is dead on
  arrival unless the send path is fixed first.
- IMAP is a **read/write** protocol though — flags, moves and folder creation are
  IMAP operations, not SMTP. So labelling and filing *within* the mailbox is
  probably available even with send broken. **Verify this against the bridge rather
  than assuming it**, since the bridge is a local re-serving proxy and its IMAP
  write support is not something the `029` work exercised (Paperless only reads and
  marks-read).
- The bridge sits on an **internal bridge network with no published ports** — a
  consumer must be a container on that network. Constrains ticket `03`.
- The bridge **session dies silently** when Proton invalidates it. Feeds ticket `05`.
- Paperless already consumes **attachments** from INBOX via mail rule id 1
  (attachments-only, action=3 mark-read). **Do not build a second thing that fights
  it** — decide explicitly how Hermes and Paperless coexist on one mailbox. The
  mark-read action in particular is shared state: if Hermes also marks read, or
  reads *before* Paperless, the two interleave.

### What the answer must settle

1. **The verb set.** Which of these Hermes does: *label/flag* in Proton, *move to a
   folder*, *mark read*, *record a note in the vault*, *create a task*, *only report
   in the brief*. Each is a different trust level and a different blast radius.
2. **Destructive operations.** Explicitly rule on delete/archive. Recommended
   default: never delete, never archive — the value is in *triage*, and irreversible
   mailbox mutation is a bad first place to spend trust.
3. **The categories.** What buckets, derived from what actually arrives (bank
   statements, Proton/One.com renewals, collections correspondence, receipts,
   newsletters, personal mail). Note the vault's own `tasks.md` shows the
   high-value pattern: a **silent** failed payment or an escalating bill is exactly
   what the owner needs caught, and Proton reminders go to *alias addresses he does
   not necessarily read* — that is the killer use case, and it argues for
   content-aware triage over sender-based rules.
4. **Which mailbox(es).** `mattias.stromdahl@pm.me` is the personal account with a
   live bridge. **Work mail (`@sensative.com`) is out** — the vault is personal-only
   and routing is by content (see the global cross-session rules); confirm and
   record that boundary. Also decide about aliases, given the point above.
5. **Vault interaction.** When triage produces something durable, where does it go —
   `inbox/` as a note, straight onto `tasks.md`, or neither? Board ownership is
   **out of scope** for this map, so the likely answer is `inbox/`-only; confirm,
   and hand the surface question to ticket `08`.
6. **Whether the send path needs fixing at all.** If the answer to (1) excludes
   replying, the broken SMTP stops being a blocker and becomes a documented
   non-capability. Prefer that over fixing SMTP as a prerequisite.
7. **Shared vs dedicated bridge instance.** Currently fog on the map; this ticket
   may sharpen it enough to graduate. One 2FA login and one silent-death surface, vs
   blast-radius isolation from document ingest.
