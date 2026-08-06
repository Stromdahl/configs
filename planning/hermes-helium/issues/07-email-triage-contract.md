# Decide the email triage contract — what "filing" concretely means

Type: grilling
Status: resolved
Blocked by: 01, 05

## Question

The owner's ask: *"I shouldn't need to check my emails all the time. The agent
should categorize and file whatever is needed."* **What does "file" actually mean,
given what the Proton bridge can and cannot do?**

### Inherited from ticket `01` (verified 2026-07-31 — don't re-derive)

From [assets/01-engine-research.md](../assets/01-engine-research.md) §6. **There are
two email mechanisms and the obvious one is wrong for us.**

- **The Email gateway adapter is disqualified twice over.** It makes email a *chat
  channel* (people mail the bot, it replies) — so it needs SMTP, which Proton
  Bridge cannot do — and **at startup it "marks all existing inbox messages as
  'seen'"** so it only handles new mail. Pointed at the real personal inbox that
  silently marks the entire backlog read. Do not use it, and do not let a future
  session reach for it because it is the first thing the docs show.
- **The triage path is the bundled Himalaya skill** (`skills/email/himalaya`,
  v1.1.0, installed by default, documented as *"separate from the Hermes Email
  gateway adapter"*). It drives the external `himalaya` CLI over IMAP/SMTP and can
  inspect, move, and flag **without SMTP** — so "filing" can mean IMAP flags and
  folder moves, with no send path involved.
- **The binary is not in the image** — a derived image layer is required (written
  into `03`), plus a config at `~/.config/himalaya/config.toml`, which lands on
  the `/opt/data` state volume rather than in git.
- Consequence for item 6: the broken SMTP most likely **is** just a documented
  non-capability rather than a blocker, exactly as that item hoped — but confirm
  it against whatever "file" turns out to mean here.

### Inherited from ticket `03` (verified on the box 2026-07-31 — don't re-derive)

- **Reachability is settled and needs no new plumbing.** The Hermes container sits on
  helium's `paperless` network, which is a **plain bridge with `internal=false`**
  (checked live) — so it reaches `protonmail-bridge:143` *by container name* **and**
  the internet, on one network. The "internal" in the compose comments means
  *unpublished*, not docker's `internal:` flag. No shared netns is involved, so the
  `project_helium_gluetun_netns_restart` hazard does not apply; the only coupling is
  that a `protonmail-bridge` recreate is invisible to Hermes until its next poll.
- **`himalaya` comes from the derived image**, pinned there alongside the base digest
  (ticket `01`'s requirement). It is *not* in the base image.
- **Scripts live at `/data/ssd/appdata/hermes/scripts/`, ansible-copied** — not baked
  into the image. `cron/scheduler.py` resolves script paths and rejects anything
  outside `$HERMES_HOME/scripts`, and a bind mount masks baked content anyway. So a
  himalaya-driven triage script is an ansible role file, versioned in git.
- **Credentials reach the script by *reading* the file, not by inheritance.** Cron
  subprocesses get a sanitized env, so the script does
  `set -a; . "$HOME/.hermes/.env"; set +a` — ticket `02`'s "accidentally correct"
  pattern, now the deliberate one. Ansible templates that `.env` from sops
  (`0600`, owner `1000:1000`), **single-quoting every value** so a `$` in a token
  survives bash sourcing. Any Proton/IMAP credential this ticket needs goes there.
- **Writes land as `ms` (uid 1000)**, and the vault is mounted at **`/vault`**.
- **The Proton Bridge login remains needs-human on a rebuild** (2FA) — already known
  from `project_helium_protonmail_bridge_paperless`, and `03` confirms it is one of
  only three needs-human items in the whole design.

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

### Inherited from ticket `05` (resolved 2026-08-01 — don't re-derive)

- **Freshness comes free — use it, don't rebuild it.** `05`'s **D2** requires every
  source to emit the **upstream's own** last-updated time. For the inbox that is the
  **newest message date**, and it is the control for this map's most-repeated real
  failure: the Proton bridge session dies *live-but-unauthenticated* and Paperless
  *"surfaces no error"*. No auth → no message dates → the brief renders **`⚠ stale`,
  not "0 new mail"**. **`07` must not let "inbox empty" and "inbox unreachable"
  share a status.**
- **An independent cross-fetch was explicitly offered for mail and declined**
  (`05` **D2**, option C). Don't reopen it: a second IMAP client rots the same way
  the first does. Provenance covers the dead-session case.
- **Generalized from `02`'s `emit_labs` bug:** an expired or exhausted
  configuration must be **`ERROR`, never `count=0`**.
- **The write list is generated from `$HERMES_HOME/logs`** (`05` **D4**), so
  whatever "filing" means, it must leave a trace there — see the `08` note below.
- **Delivery is job configuration, never prompt text**, and no prompt may instruct
  `[SILENT]` (`05` **D1**).

## Answer

**"Filing" means applying one Proton label. Nothing else.** Hermes reads INBOX and
writes exactly one verb — `COPY` into a `Labels/hermes-*` label — on the small
minority of messages that mean something needs doing. It never marks read, never
moves, never archives, never deletes, never removes a label, and never writes to
the vault. Every capability question the ticket raised was **verified on the live
bridge**, not assumed: see [assets/07-imap-probe.md](../assets/07-imap-probe.md).

Item 6 resolves the way the ticket hoped: **the broken SMTP is a documented
non-capability, not a blocker.** No verb in this contract needs a send path, so
fixing `454 4.7.0 unknown error` is not a prerequisite for anything here.

### D1 — The verb set: labels only

The only mutation is `UID COPY <uid> Labels/hermes-<bucket>`. **Verified**: the
source message stays in INBOX, the label really is applied, and `CREATE` under
`Labels/` is proxied to Proton's own label API (`POST
https://mail-api.proton.me/core/v4/labels`), so a label is a genuine Proton label
visible in the web and phone UI — not bridge-local state.

Explicitly ruled out, each for its own reason:

- **`\Seen` — prohibited, and this is the load-bearing prohibition.** Paperless
  mail rule 1 is mark-read, and `MarkReadMailAction.get_criteria()` returns
  `{"seen": False}` (read out of paperless-ngx 2.20.15 on the box). Paperless
  therefore **only ever fetches UNSEEN INBOX mail**. If Hermes marks a message read
  before Paperless's next poll, that message's attachments are never ingested —
  the invoice PDF simply never arrives, silently. **Every fetch must use
  `BODY.PEEK`**; a bare `FETCH BODY[]` sets `\Seen` implicitly and is a defect.
- **`MOVE` — prohibited**, for the same reason one step removed: gone from INBOX is
  invisible to rule 1. (It works — verified — it just must not be used.)
- **Delete / archive — prohibited.** The ticket's recommended default, taken as-is.
  Irreversible mailbox mutation is a bad first place to spend trust, and the value
  is in triage, not tidying.
- **Custom IMAP keywords — not used.** They work and persist and are searchable
  (verified), but Proton has no arbitrary-keyword concept, so persistence is almost
  certainly the bridge's local `imap-sync` cache — invisible in the Proton UI and
  probably lost when the bridge rebuilds it (and it self-updates unattended, 3.19.0
  → 3.25.0 on its own). For "have I examined this?" the **UID watermark (D7) is
  strictly better**: local state under our own backup regime, needing no write.

The owner noted they may want write verbs on some future occasions. That is
designed for rather than merely noted: because the labels are *topical* (D4), a
later action — "archive everything labelled `hermes-bill` once it's 30 days paid" —
bolts onto this taxonomy instead of needing a new one.

Two structural constraints, both verified:

- **Nothing can be created at the top level** (`invalid mailbox name: operation not
  allowed`). A bucket must be `Folders/<x>` or `Labels/<x>`; `INBOX` is
  `\Noinferiors`, so not under it either.
- **Folders and labels share one Proton namespace** — `CREATE Labels/x` returns
  `409 Label or folder with this name already exists` if `Folders/x` exists. Any
  naming scheme picks a side per name.

### D2 — Its own flat namespace, `Labels/hermes-*`

Hermes does not write into the existing taxonomy (`Newsletters` 1748, `Receipts`
357, `Shipping` 78, `Travel` 61, `Important`, `Adverts`, `Folders/Lysa`). Four
reasons: it cannot corrupt a hand-built 1748-message taxonomy; deleting the label
*is* the complete undo, one action; attribution stays possible, which `05`'s audit
trail requires; and the write list becomes trivially derivable as "everything under
`hermes-`".

The two taxonomies are not redundant — the owner's says *where mail lives*, Hermes'
says *what it concluded*, and those genuinely differ (a Billogram mail is a receipt
to the owner and possibly an unpaid bill to Hermes).

**Flat, hyphenated names, never `hermes/sub`.** Proton labels may not nest the way
folders do and it was not verified; a flat prefix sidesteps the question and stays
clear of the 409 above.

### D3 — Exception-only, not classification

The overwhelming majority of mail gets **no label at all**. Nothing labelled means
nothing to do. Full classification was rejected on three grounds:

- It reproduces what already exists — Proton's own filters put 1748 messages in
  `Newsletters` with no LLM, and paying an inference provider to re-derive "this is
  a newsletter" buys no decision.
- **It destroys checkability.** `05`'s audit trail prints what Hermes wrote beside
  its own prose; "3 labels applied" can be eyeballed against three claims, and "412
  labels applied" cannot be checked by anyone, ever. A drifted or fabricating
  classifier would run for months looking healthy — the fake-weather failure with a
  far bigger surface.
- It degrades worse. Exception-only failing wrong-quiet is caught by `05`'s liveness
  alarms; full classification failing wrong-quiet just looks like a slightly
  emptier taxonomy.

The real weakness of exception-only is that it has **no visible negative space** —
too narrow a test and you never learn what was skipped. Mitigation, required in the
brief: **the count of messages examined vs flagged**, so a suddenly-zero-flag day
reads as a *ratio* rather than an absence.

### D4 — Four buckets, topical not severity-based

**The labels must not encode urgency.** `hermes-urgent` / `hermes-later` would put
this ticket in direct collision with
[ticket 06](06-urgent-vs-digest-policy.md), which owns the urgency test and the
interrupt-vs-digest routing. Topical labels let `06` consume them and stay the
single owner of how loud it gets; severity labels would split routing logic across
two tickets and let it drift.

| label | means | evidence it is a real class |
|---|---|---|
| `hermes-bill` | money is owed, there is a due date | `banknorwegian.se`, `billogram.com`, `swedbankpay.se`, `walley.se`, `klarna.se`, `nordea.com`, Loopia/One.com renewals — all present in the probe's sender sample |
| `hermes-escalation` | a **second** notice: reminder, påminnelse, krav, inkasso, service cutoff | the documented failure. Loopia 149,85 went through **two** reminders unnoticed — and the first was *already archived in Paperless*. Filing was never the missing step. 327 kr → 1 340 kr in the KFM case |
| `hermes-action` | a non-money act with a time element: appointment, booking cutoff, a personal mail awaiting a reply | means "you need to answer this", never "I answered it" — there is no send path |
| `hermes-unsure` | might matter, not confident | see below |

`hermes-escalation` is technically a subset of `hermes-bill` and still earns its own
label: it is the documented failure, escalation language is the cheapest
high-precision signal in the corpus, and it demands a different response.

**Not buckets:** newsletters, adverts, shipping, receipts — all no-action by nature,
and the first three already have labels.

**`hermes-unsure` is included, with backpressure instead of a daily cap.** It is
included because the brief is ephemeral: if Hermes is unsure about a Billogram mail
and the owner doesn't read that evening's Telegram message, the doubt is gone
forever — the same argument that made labels beat brief-only in D1, so rejecting it
for the *uncertain* cases (the ones most likely to be a missed bill) would be
backwards. The pile-up risk is killed by construction: Hermes reads `STATUS
Labels/hermes-unsure (MESSAGES)` before adding and **above a threshold (start at 20)
stops adding and says so in the brief**. Overflow becomes a loud signal instead of
silent growth, and it needs no verb beyond `COPY`. Side-effect worth keeping: the
owner's clearing rate is a free calibration signal for `06`'s correction loop.

### D5 — Stay clear of `finance.py ingest-email`; "feed" is a named follow-on

There are **three** consumers of this mailbox, not the two the ticket knew about.
`~/vault/finance/notes/email-ingest-plan.md` + `tasks.md` line 48 specify
`finance.py ingest-email` — scoped `SEARCH FROM klarna.com`, receipts matched to
bank transactions by date+amount, "bank = cash-flow truth, email = itemisation
only". Unbuilt, and its stated blocking step ("install Proton Bridge") was already
done by issue `029`. It overlaps `07` in *purpose*: it exists to crack the same
receipt/invoice class this ticket calls the killer use case.

| consumer | reads | writes | status |
|---|---|---|---|
| Paperless rule 1 | UNSEEN INBOX, attachments, ≤30d | sets `\Seen` | live |
| `finance.py ingest-email` | scoped `SEARCH FROM <merchant>` | nothing | planned, unbuilt |
| Hermes triage | INBOX above the watermark, `BODY.PEEK` | `hermes-*` labels | this ticket |

**Decision: stay clear.** Hermes emits no `hermes-receipt`, and `finance.py` keeps
that lane. *Subsume* is out on the map's own logic — writing into `finance.db` is
the write-heavy high-trust path the board is ruled out of scope for, and the
double-counting hazard the plan itself warns about is invisible until a month-end
number looks odd. *Feed* (Hermes labels receipts, `finance.py` consumes the label
instead of a hand-maintained merchant allowlist that silently misses new merchants)
is genuinely better than the current plan and is recorded **out of scope** as a
follow-on: it would make an unbuilt pipeline a dependency of this one, and give
Hermes' labels a second consumer with different correctness requirements before the
first consumer is trusted.

### D6 — Hermes never removes a label; clearing is human-only

**Removal is safe — verified.** `\Deleted` + `EXPUNGE` inside `Labels/x` detached
the label (label → 0) and left the message intact in its source folder. So the
prohibition is a judgement, not a limitation.

It stands anyway: **a label Hermes can retract is, after the fact,
indistinguishable from a label it never applied.** Auto-aging `hermes-bill` after 30
days would erase precisely the evidence of an escalating bill — the failure the
bucket exists to catch. Keeping removal out holds the write surface at exactly one
verb, which is also the narrowest possible thing to hand
[ticket 08](08-vault-read-write-surface.md).

### D7 — A UID watermark, and the backlog is skipped deliberately

`\Seen` was the only *shared* notion of "new" and D1 forbids it — and it was
useless here anyway: **444 messages, 2 unseen.** So Hermes keeps its own high-water
mark (last INBOX UID examined) in `/data/ssd/appdata/hermes/` per `03`'s state
placement.

Two guards, both this map's enemy class in miniature:

- **A `UIDVALIDITY` change is an `ERROR`, never a silent re-seed.** INBOX currently
  reports `UIDVALIDITY 108417068`. The bridge self-updates unattended, and a cache
  rebuild can change that number, voiding every stored UID. Quietly re-seeding skips
  everything that arrived in the gap. Same rule as `05`'s "an exhausted
  configuration is `ERROR`, never `count=0`".
- **An absent watermark must not mean zero.** `03`'s falsifiable rebuild test is
  that git plus the age key yields a working but amnesiac Hermes. An amnesiac Hermes
  **re-seeds and says so in the brief** — it does not scan 444 messages, and it does
  not treat the whole mailbox as new.

**The backlog is skipped at first run, and the brief says how many were skipped.**
Permanently ignoring it would be wrong — there may be an open escalating bill in
those 444 right now, and a system whose first act is to miss the live case has
failed its own premise. But doing it *on first boot* is worse: 444 messages of
egress at once, immediate blowout of the `hermes-unsure` threshold, and a wall of
labels that destroys the checkability that made D3 right. Nothing is trusted on day
one; that is the wrong moment to spend the whole trust budget. So a **bounded
backlog scan is a separate, deliberate, human-triggered act** once the daily path
has earned trust — 90 days covers the Loopia case with room; 30 would align with
Paperless's `maximum_age` but might miss something older still open.

### D8 — INBOX only; the coverage boundary, measured

The recipient dimension needed no decision once measured — **the aliases were never
separate mailboxes, just separate `To:` headers**, so there is no per-alias
filtering to do (filtering would be work to *reduce* coverage):

| recipient class | in INBOX | oldest | newest |
|---|---|---|---|
| `*.passmail.net` alias | **295** | 2025-09-04 | today |
| gmail address | **85** | 2026-07-06 | 2026-08-04 |
| `pm.me` direct | 24 | 2025-11-07 | 2026-08-02 |
| `@sensative.com` (work) | **0** | — | — |

- **The killer use case is reachable.** `tasks.md` line 47 says invoices scatter
  across alias inboxes and reminders get missed — but **66 % of INBOX is
  alias-addressed** and all of it lands here.
- **Gmail is a live forward, not a historical import** — 85 messages inside one
  month, starting 2026-07-06, still arriving at ~3/day. It comes in-scope for free;
  no second mail source is needed. (Don't filter on `Labels/mattias.stromdahl@gmail.com`
  — it holds only 16 of the 85 and is stale.)
- **Work mail is out, and already empirically absent** (zero messages). The
  personal-only boundary the global routing rules require is a fact, not a policy to
  enforce.

**Mailboxes: INBOX only.** `Trash` (3144) and `Archive` (108) are decisions the
owner already made — re-triaging them second-guesses them and inflates egress ~8×.
`All Mail` (3744) is just the union; `Sent`/`Drafts` are the owner's.

**`Spam` is a recorded, accepted gap.** A bill landing in spam is exactly this
ticket's failure mode, and it is left out on evidence: `Spam` holds **1 message**.
Proton's filter is not misfiring at a rate that costs anything, and spam is the
highest-risk, lowest-value corpus to stream to an inference provider. Revisit if
that count climbs.

**Kivra is out of scope** — no IMAP, no bridge, an entirely different mechanism, and
the owner's own board already assigns it a weekly human check as the consolidation
point for anything heading to inkasso. Stated plainly so the brief never implies it
is watching everything official.

### D9 — No vault writes from the email half

The ticket guessed `inbox/`-only. **Zero is the answer**, and the reason is the
map's own worst example: `~/vault/inbox/` is drained by `/daily`, and `/daily` is
dead — `~/vault/daily/` is empty because the drain never became habitual. Filing
notes there is **writing to a queue with no reader**, which is precisely
`Sync/Hermes-Claude-Bridge.md`, written to for weeks while nothing ever read it.
Rebuilding that on day one in the same vault is not acceptable.

Nor is it needed. **The label already is the durable artifact**, and a better one: it
is attached to the message, visible on the phone, and clicks through to the mail. A
vault note would be a lossy copy of something that already exists in a better place.
`05`'s audit trail comes from `$HERMES_HOME/logs`, not the vault.

**Consequence for [ticket 08](08-vault-read-write-surface.md): the email half's
vault write surface is zero.** `08` decides vault writes for the *conversational*
path alone, where a human is in the loop for every write — a far easier trust
decision than "an unattended job may create files in your vault".

The honest cost: some triage output genuinely wants to become a task. That is board
ownership, out of scope by name; until the follow-on, `hermes-bill` plus the evening
brief carries it.

### D10 — One shared bridge instance

Hermes uses the existing `protonmail-bridge` container, and the ticket's item 7
resolves here rather than graduating.

**The reason is better than saving effort: it turns Hermes into the monitor
Paperless never had.** Today when the session dies, Paperless surfaces no error —
one of the map's founding silent-failure examples. On the *same* instance, `05`'s D2
provenance check covers both: no auth → no message dates → `⚠ stale`. One
instrument, two consumers. A dedicated instance would leave Paperless exactly as
blind as it is today and add a second thing that can die quietly, plus a second
un-automatable 2FA login (`03` counted three needs-human items; this would make
four).

Blast radius, the argument for isolation, is small by construction: one
non-destructive verb, a watermark-bounded read, one poll per cycle. With `\Seen` off
the table the only shared state left is the TCP listener.

**Two implementation riders, one of them a trap:**

1. The bridge IMAP password exists in exactly one place today — the Paperless
   database (`paperless_mail_mailaccount`, plaintext, 22 chars). It is **not** in
   `ansible/host_vars/helium/secrets.sops.yml` (key list checked). It must be added
   there and templated into the `.env` inside the state volume per `03`.
2. **That password is regenerated on every bridge re-login**, so a 2FA re-login
   requires updating it in **two** places — Paperless's DB and sops. Exactly the
   two-place update that gets half-done. Saving grace: the half-done case is already
   loud — a stale sops password means `LOGIN` fails, no message dates, `⚠ stale`. It
   fails in the correct direction.

### The emitter contract (derived, not decided)

Falls out of `05` D2 and `02`'s per-source `STATUS=OK/ERROR` shape; recorded here so
implementation has it:

- **Provenance = the newest INBOX message `Date:` header.** Verified live
  (2026-08-05 13:46 UTC). This is the upstream's own last-updated time, and it is
  *unavailable* when the session is dead — so `⚠ stale` and `0 new mail` cannot
  collide, which is `07`'s inherited requirement from `05`.
- **`STATUS=ERROR` on: login failure, `UIDVALIDITY` change, absent watermark,
  `hermes-unsure` at threshold.** Never `count=0` for any of them.
- **Every read is `BODY.PEEK`.** Non-negotiable (D1).
- **The brief reports examined-vs-flagged counts** (D3) and skipped-backlog size
  (D7).
- **Delivery is job configuration, never prompt text**. And per `02`: no prompt may
  say "send the briefing to Telegram" — cron jobs have `messaging` disabled.

**Reconciled with [ticket 06](06-urgent-vs-digest-policy.md), resolved concurrently
2026-08-06.** No conflict — `06` **D1** rules mail **not interrupt-eligible on day
one**, so these labels feed the 20:00 brief and nothing else, and `06` remains the
sole owner of severity exactly as D4 intends. Two of its verified findings bind this
contract and sharpen it:

- **The mail section's emitter must never exit 0 with empty stdout.** `06` found in
  the engine that a pre-run script producing no output **skips the agent call
  entirely** (`return None`), while a non-zero exit injects `## Script Error … Report
  this to the user` and the agent still runs. So `exit 1` is *loud* and `exit 0` with
  nothing is *silent*. The mail emitter must therefore **always** print its
  `STATUS` + provenance + counts block — including on a clean, genuinely-empty day —
  which the contract above already requires. Stated explicitly because the tempting
  optimisation ("nothing to report, print nothing") is a silent-failure path.
- **`05` D1's "no prompt may instruct `[SILENT]`" was unachievable** — the engine
  prepends that instruction to every cron job with no way to disable it. `06`
  rewrote the requirement: the brief's prompt must **countermand** the engine's hint.
  Nothing in this ticket may reintroduce a "say nothing if the inbox is quiet"
  instruction; a quiet inbox is `count=0` *with* provenance, which is a report.

### Inherited hazard, restated as a prohibition

**The Email gateway adapter must never be pointed at this mailbox.** From `01`: at
startup it *"marks all existing inbox messages as 'seen'"*. Against this account
that is 444 messages marked read in one shot — and given the Paperless
`{"seen": False}` criteria proven above, it would **also silently sever document
ingest for everything in the 30-day window**. It is the first thing upstream's docs
show. Use the bundled Himalaya skill, or a `no_agent` script driving IMAP directly.

Status: resolved
