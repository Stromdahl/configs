# Asset: what the Proton Bridge mailbox actually looks like (ticket 07)

Probed live on helium 2026-08-05 against `protonmail-bridge:143` from inside the
`paperless` container (the only container on that network with `python3`). The
read probe opened `INBOX` with `readonly=True` and used `BODY.PEEK` exclusively,
so no `\Seen` flag was set and nothing was modified. Sender **domains** only were
collected — no subjects, no bodies.

Script: `scratchpad/probe_read.py` (read-only) and `scratchpad/imap_probe.py`
(write probe, **not yet run** — needs the owner's go-ahead, see bottom).

## 1. The bridge session is live, and the freshness token works

- `LOGIN: ok`. Newest `Date:` header in INBOX: **2026-08-05 13:46 UTC**, i.e. today.
- So `05`'s **D2** provenance requirement is satisfiable with nothing new built:
  `newest message Date:` *is* the upstream's own last-updated time, and it is
  unavailable when the session is dead. `⚠ stale` and `0 new mail` cannot collide.
- Runtime bridge version is **3.25.0**, not the image's 3.19.0 — the bridge
  self-updated (`/root/.local/share/protonmail/bridge-v3/updates/3.25.0/bridge
  --cli --session-id 20260805_082239983`). That is the documented behaviour the
  `libfido2` patch exists to survive, and it means `tasks.md`'s "stuck at 3.19.0"
  worry is about the *base image*, not the running binary.

## 2. Capability string — MOVE and UIDPLUS are advertised

```
pre-login:   AUTH=PLAIN ID IDLE IMAP4rev1 STARTTLS
post-login:  AUTH=PLAIN ID IDLE IMAP4rev1 MOVE STARTTLS UIDPLUS UNSELECT
```

`MOVE` and `UIDPLUS` appear **only after login**. So folder moves are
protocol-supported, and `IDLE` is there if a push consumer is ever wanted.
Advertised ≠ working — the write probe still has to confirm it.

## 3. A taxonomy already exists — do not invent one

```
INBOX                                    444 msgs,  2 unseen
Archive                                  108        9
Starred                                   14        0
Spam                                       1        1
Trash                                   3144        2
Sent                                       9        0
Drafts                                     0        0
All Mail                                3744       14
Folders/Lysa                              22        0
Folders/Färöarna resa                     16        0     (LIST shows it UTF-7 encoded)
Labels/Newsletters                      1748        3
Labels/Receipts                          357        3
Labels/Shipping                           78        1
Labels/Travel                             61        0
Labels/mattias.stromdahl@gmail.com        16        0
Labels/Important                           8        0
Labels/Adverts                             4        1
```

Both parents (`Folders`, `Labels`) are `\Noselect` containers. `INBOX`,
`Archive`, `All Mail`, `Trash`, `Sent`, `Starred`, `Spam` are `\Noinferiors` — so
**nothing can be nested under INBOX**; a new bucket has to be `Folders/x` or
`Labels/x`.

Two shapes are available and they mean different things in Proton:
- **Label** = `COPY` into `Labels/<name>` — the message *stays* in INBOX and can
  carry several labels. Non-destructive, and invisible to Paperless's INBOX rule.
- **Folder** = `MOVE` into `Folders/<name>` — the message *leaves* INBOX and can
  be in exactly one folder. Destructive with respect to INBOX.

## 4. INBOX is a 444-message pile, not a work queue

**444 messages, 2 unseen.** The owner reads mail and leaves it in place; only 108
messages have ever been archived against 3144 trashed. Consequences:

- **`\Seen` is not a triage signal here** and "mark read" is close to a no-op as a
  *state* — its only real effect is the collision with Paperless (§6).
- Any Hermes design keyed on unread-vs-read inherits a 444-item backlog on day one.
- `Labels/Newsletters` holding 1748 and `Labels/Receipts` 357 says the owner
  already sorts by *class of mail*, which is exactly what triage would produce.

## 5. Alias coverage is better than the vault feared — and gmail is already inside

`tasks.md` line 47 says invoices scatter across `*.passmail.net` aliases and
gmail, and that reminders get missed as a result. Measured, on INBOX:

| recipient pattern | in `To:` | in `Delivered-To:` |
|---|---|---|
| `passmail.net` | **291** / 444 | 0 |
| `gmail.com` | **85** | 86 |
| `pm.me` | 24 | 25 |
| `protonmail.com` / `simplelogin` | 0 | 0 |

- **66 % of INBOX is alias-addressed** and it all lands in this one mailbox. The
  "reminders go to alias inboxes I don't read" problem is therefore **reachable
  from the bridge** — the aliases were never separate mailboxes, just separate
  `To:` headers. This is the single most important finding for the killer use case.
- **Gmail is already flowing in** (85 messages, plus a
  `Labels/mattias.stromdahl@gmail.com` label with 16). So gmail is very likely
  forwarded/imported into Proton rather than a second mailbox to reach —
  **confirm with the owner whether that forward is still live**, because if it is,
  no second mail source is needed. Note the label has only 16 messages while 85
  match by header, so the label is stale/partial — don't use it as the filter.
- **Kivra is still outside.** No IMAP, no bridge. Official/legal mail (Kronofogden,
  inkasso) goes there, and the vault's own habit-fix note makes Kivra "the single
  weekly check for anything heading to inkasso". That is a real coverage gap and it
  is not closable by this ticket.

## 6. The Paperless collision is real, and it is an *ordering* defect

Read out of the live DB (`paperless_mail_mailrule`, paperless-ngx 2.20.15):

```
rule 1  "Proton inbox -> consume attachments"
  folder INBOX · no from/to/subject/body/filename filters
  maximum_age 30 (days) · attachment_type 1 (attachments only)
  consumption_scope 1 (attachments only) · action 3 = MARK READ · enabled
```

And in `src/paperless_mail/mail.py`:

```python
class MarkReadMailAction(BaseMailAction):
    def get_criteria(self):
        return {"seen": False}
```

**⇒ Paperless only ever fetches UNSEEN INBOX mail.** If Hermes marks a message
read before Paperless's next poll, that message's attachments are **never
ingested**, silently — the invoice PDF simply never reaches Paperless. This is
this map's own enemy class reached through the email half:

- **Hermes must not set `\Seen` on INBOX mail.** Not as a verb, not as a
  side-effect. Every FETCH must use `BODY.PEEK` (a bare `FETCH BODY[]` sets
  `\Seen` implicitly — the probe itself had to be written around this).
- A **`MOVE` out of INBOX has the same effect** if it happens before Paperless
  polls: gone from INBOX means invisible to rule 1. Labels (`COPY`) do not.
- Paperless's 30-day `maximum_age` bounds the damage window but doesn't remove it.

## 7. A third consumer of this mailbox is already planned

`~/vault/finance/notes/email-ingest-plan.md` + `tasks.md` line 48 specify
`finance.py ingest-email`: Proton Bridge IMAP, server-side `SEARCH FROM
klarna.com`, receipts matched to bank transactions by date+amount, "bank = cash
flow truth, email = itemisation only". It is unbuilt, and its stated next step
("install Proton Bridge") is **already done by issue 029**.

It overlaps `07` in *purpose*: it exists to crack exactly the receipt/invoice
class this ticket calls the killer use case. Three consumers on one mailbox, with
different postures:

| consumer | reads | writes | status |
|---|---|---|---|
| Paperless rule 1 | UNSEEN INBOX, attachments, ≤30d | sets `\Seen` | **live** |
| `finance.py ingest-email` | scoped `SEARCH FROM <merchant>` | nothing | **planned, unbuilt** |
| Hermes triage | TBD | TBD | this ticket |

The sender domains below show how much they'd both be looking at the same mail.

## 8. What actually arrives (sender domains, last 60 INBOX messages)

```
 12  email.bonniernews.se        2  nordea.com            1  swedbankpay.se
  6  notify.proton.me            2  receipt.max.se        1  billogram.com
  4  bornholmslinjen.dk          2  lysa.se               1  walley.se
  3  teknikmagasinet.se          2  uber.com              1  klarna.se
  3  billetto.se                 2  mg.easytablebooking   1  bokadirekt.se
  2  apotekhjartat.se            1  aimopark.io           1  booli.se
  2  banknorwegian.se            1  vrsverige.com         1  github.com
  2  apoteket.se                 1  earlybird.se          1  nabucasa.com
```

Newsletters dominate by volume (20 % from one publisher). The finance-critical
senders are present and thin — `banknorwegian.se` (the 28 Aug card invoice),
`nordea.com`, `billogram.com` and `swedbankpay.se` (invoicing rails),
`klarna.se`, `walley.se`, `lysa.se`. **Content-aware triage over sender rules is
the right read**: `notify.proton.me` at 6/60 is the class the vault says gets
missed, and one `billogram.com` message can be a bill or a receipt.

## 9. The write probe — IMAP writes work, and the mailbox is mutable

Run by the owner 2026-08-05 (`scratchpad/imap_probe.py`, synthetic messages only,
self-cleaning; `LIST` after cleanup showed no leftovers).

| operation | result |
|---|---|
| `CREATE Folders/hermes-probe` | **OK** |
| `CREATE hermes-probe-toplevel` (bare) | **NO** — `invalid mailbox name: operation not allowed` |
| `CREATE Labels/hermes-probe` | **NO 409** — see §9.1, the test was botched, not the capability |
| `APPEND` into a folder | **OK** — `[APPENDUID 110731944 1]` (UIDPLUS live) |
| `STORE +\Seen` | OK |
| `STORE +\Flagged` | OK |
| `STORE +$hermes-triaged` (custom keyword) | **OK**, returned in FLAGS |
| `STORE +hermes_triaged` (custom keyword) | **OK**, returned in FLAGS |
| `UID MOVE` folder→folder | **OK** — source emptied, destination holds 1 |
| `COPY` into a label | **not tested** — see §9.1 |
| `DELETE` of both created folders | OK |

So: **filing can mean real mailbox mutation.** Folders can be created and messages
moved between them; flags and custom keywords are accepted. Item 6 of the ticket
resolves the way it hoped — broken SMTP is a documented non-capability, not a
blocker, because nothing in this verb set needs a send path.

Two hard constraints fell out:

- **Nothing can be created at the top level.** A new bucket must be `Folders/<x>`
  or `Labels/<x>`. (`INBOX` is `\Noinferiors`, so not under it either.)
- **Folders and labels share one Proton namespace.** The 409 read *"Label or
  folder with this name already exists"* — you cannot have both `Folders/x` and
  `Labels/x`. Any naming scheme has to pick a side per name.

### 9.1 The one result that is still missing, and why

Probe #1 created `Folders/hermes-probe` **before** trying `Labels/hermes-probe`,
so the label CREATE hit the shared-namespace 409 above — and because the mailbox
never existed, the `COPY` into it failed `[TRYCREATE] no such mailbox`. **The
label path was never actually exercised.** That is my script's bug, not a bridge
limitation, and it is precisely the result the labels-only recommendation rests on.

One strong piece of indirect evidence in the meantime: the 409 came back as
`409 POST https://mail-api.proton.me/core/v4/labels`. So an IMAP `CREATE` under
`Labels/` is proxied to Proton's **real label API** — meaning a label applied over
IMAP would be a genuine Proton label, visible in the web and phone UI, not
bridge-local state.

### 9.2 Probe #2 — labels verified, and label removal is safe

Run by the owner 2026-08-05 (`scratchpad/imap_probe2.py`, distinct names,
synthetic mail only, `LEFTOVERS: none`).

| operation | result |
|---|---|
| `CREATE Labels/hermes-lbl-probe` | **OK** — probe #1's 409 was purely the namespace collision |
| `UID COPY` folder → label | **OK** |
| source folder after `COPY` | **still holds the message** ⇒ label semantics confirmed |
| `SELECT Labels/…` after `COPY` | **1 message** ⇒ the label really is applied |
| `$hermes-triaged` after **reconnect** | **persisted** — `FLAGS ($hermes-triaged)` |
| `SEARCH KEYWORD $hermes-triaged` | **OK**, matched ⇒ keywords are searchable |
| `\Deleted` + `EXPUNGE` **inside the label** | **OK** |
| source folder after that | **message SURVIVED** |
| label after that | **0 messages** ⇒ the label was detached, not the mail deleted |

**⇒ `COPY` into `Labels/<x>` is a real, non-destructive Proton label operation, and
detaching a label does not destroy the message.** The labels-only verb set is
fully verified on the live bridge.

Two caveats worth carrying forward:

- **Custom keywords persisted across a reconnect, but that does not prove
  server-side storage.** Proton has no arbitrary-keyword concept in its API; the
  bridge almost certainly kept it in its local `imap-sync` cache (which is what
  survived the reconnect — the same process was still running). A keyword is
  therefore **invisible in the Proton web and phone UI**, and probably lost on a
  bridge cache rebuild — and the bridge self-updates unattended. So keywords are
  **not** an audit trail. Anything the owner must be able to see belongs in a
  label. And for "have I examined this?" bookkeeping the **UID watermark is
  strictly better**: pure local state under our own backup regime, needing no
  mailbox write at all.
- **Label removal being safe does not mean Hermes should do it** — see D6 in the
  ticket's answer. A retractable flag is indistinguishable from a flag that was
  never raised, which is the silent-failure shape this map exists to prevent.
