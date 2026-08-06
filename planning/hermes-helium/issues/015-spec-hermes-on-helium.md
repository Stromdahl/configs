# Spec: Hermes on helium — the buildable version

Type: spec
Status: open
Source: [the hermes-helium map](../map.md) — all 14 wayfinder tickets resolved or closed
Depends on: `planning/vault-serve/issues/004` (Send-Receive vault replica on helium)

<!--
Two deviations from the /to-spec skill's defaults, recorded rather than silently taken:

1. Published map-local rather than to top-level `issues/`. `issues/README.md` defines an
   issue as "one independently-grabbable thin vertical slice… independently demoable";
   an epic-level spec is neither. vault-serve's graduated execution work lives in its own
   map folder (`004`, `005`) and this map's Notes name that as the precedent. Numbering
   continues the map's sequence with 3-digit padding, exactly as vault-serve did
   (01–03 wayfinder → 004/005 execution; here 01–14 wayfinder → 015 onward).
2. No `ready-for-agent` label. That string appears nowhere in this repo's 47 issues —
   the live vocabulary is `epic:*`, `needs-human`, `wayfinder:*`. `Status: open` plus
   `Type: spec` is this repo's actual "takeable" signal.
-->

## Problem Statement

The owner has no assistant between his hands and his own life-admin. The vault holds the
board, the money, the health facts and the journal; the Proton inbox holds the bills and
the escalations; and the only thing that ever joins them up is a laptop session he has to
start himself. `/daily` was supposed to be that habit and it isn't one — `~/vault/daily/`
is empty and the inbox drain happened once, on 2026-07-29. Dated items go past due
unnoticed: **six were already overdue** when the board was measured, the oldest by more
than two weeks.

This is attempt five. Four previous Hermes installs died — two LXCs and a VM, the last as
collateral when titan was rebuilt as helium. **No ADR ever ruled against Hermes**; the
commit that killed it cites one that doesn't mention it. So the reason to be careful isn't
that the idea was judged bad. It's the second cause of death: **trust**. This homelab's
signature failure is a thing that looks fine and isn't — the morning briefing shipped
hardcoded fake weather it never queried, a bridge file was written to for weeks with no
reader, the Proton bridge session dies and Paperless reports nothing, and disks return
success to spin-down commands while still spinning. An assistant that reads mail
unattended and reports on your health and money is worthless the moment it might be
inventing, and an assistant nobody checks is exactly where invention hides.

There is also a live loss of a different kind: the last Hermes reorganized the vault by
itself, deleted a Syncthing marker, and stalled sync for up to an hour with badly diverged
sides. That happened because the vault was the agent's brain.

## Solution

**A single Hermes container on helium, in two modes, that cannot fail quietly.**

- **Pull — conversational.** Telegram DM from the phone: query the board, capture a note,
  ask about the vault. Human in the loop every exchange.
- **Push — ambient.** Email triage that flags the small minority of mail that means
  something needs doing; date-driven interrupts two days ahead of anything dated; and one
  **20:00 evening brief** that always arrives.

Three structural choices carry the trust half, and they're what makes this different from
attempts one through four:

1. **The brief always arrives, so silence is itself the alarm.** No condition renders
   nothing. A quiet day is a short brief, not an absent one.
2. **Judgment is confined to one job.** The interrupt channel and every verification job
   are scripts with no model in the loop — they cannot fabricate. The 20:00 brief is the
   only place an LLM exercises judgment, and it is handed pre-gathered facts, each
   stamped with its upstream's own last-updated time. **A fabricated fact has nowhere to
   come from**, rather than being something a checker hopes to catch later.
3. **The vault is a data source, never the brain.** Mounted read-only, with exactly one
   writable directory. Hermes' own memory lives on its state volume. The founding
   catastrophe becomes structurally impossible rather than prohibited by instruction.

## User Stories

**The owner, receiving**

1. As the owner, I want one brief at 20:00 every day, so that checking in on my own life
   is a habit with a time rather than a thing I remember to do.
2. As the owner, I want the brief to arrive even when there is nothing to say, so that a
   silent evening means something is broken rather than meaning nothing happened.
3. As the owner, I want a quiet day to render as a short brief, so that always-arriving
   doesn't train me to skim past it.
4. As the owner, I want the brief to fit one phone screen, so that I actually read it
   standing in the kitchen.
5. As the owner, I want the most important thing first, so that I get the point before I
   decide whether to read on.
6. As the owner, I want a fixed footer on every brief, so that I can tell a working system
   from a wedged one in one glance without reading the prose.
7. As the owner, I want each section to name where its facts came from and how fresh they
   are, so that a confidently-worded lie has to survive a timestamp.
8. As the owner, I want anything dated to reach me two days before it's due, once, so that
   a bill I can still pay on time is not something I discover afterwards.
9. As the owner, I want the first day not to fire six overdue interrupts at me, so that my
   first act isn't muting the thing I just built.
10. As the owner, I want interrupts to be date arithmetic done by a script, so that an
    interrupt at 09:00 is never a hallucination.
11. As the owner, I want to be told on injection nights that tonight is a Kineret night,
    so that an every-other-night schedule stops living in my head.
12. As the owner, I want the dose section to go loud rather than quiet when its schedule
    runs out, so that a taper boundary can't silently turn correct arithmetic into wrong
    arithmetic.
13. As the owner, I want the undrained inbox depth and its oldest note's age in the brief,
    so that a queue nobody is reading becomes visible instead of accumulating.
14. As the owner, I want to know what Hermes actually changed today, listed by something
    other than Hermes, so that its account of itself can be contradicted.

**The owner, on the go**

15. As the owner, I want to DM Hermes from my phone and get an answer about my own vault,
    so that "what's on the board" doesn't need a laptop.
16. As the owner, I want to capture a note by messaging it, so that an idea on a walk lands
    somewhere the system will drain.
17. As the owner, I want Hermes to answer only me, in DMs, so that asking it a question in
    a family group out of habit cannot put my finances on a group screen.
18. As the owner, I want a second person to be addable later by adding one id, so that
    today's decision doesn't foreclose Hanna.
19. As the owner, I want to correct Hermes and have the correction stick, so that telling
    it something twice isn't the normal experience.
20. As the owner, I want a visible count of corrections in the brief, so that "it stuck"
    is something I can check rather than assume.

**The owner, trusting it**

21. As the owner, I want Hermes unable to reorganize or delete my vault, so that the
    failure that stalled Syncthing for an hour cannot recur.
22. As the owner, I want exactly one writable directory, so that "what could it have
    touched?" has a one-line answer.
23. As the owner, I want a point-in-time copy of anything overwritten in the vault, so that
    a bad write days ago is still recoverable.
24. As the owner, I want to be told when a source is broken rather than having it omitted,
    so that a dead mailbox never reads as an empty one.
25. As the owner, I want an alarm when the brief doesn't arrive, delivered by something
    other than the brief, so that the channel's own death can be reported.
26. As the owner, I want an alarm when the Telegram transport dies while the container
    keeps running, so that pull mode failing silently isn't possible.
27. As the owner, I want a monthly cost ceiling that trips an alarm, so that an unattended
    agent cannot quietly become expensive.
28. As the owner, I want to know which provider and model actually served each run, so that
    a silent switch is detectable.
29. As the owner, I want a rehearsed rebuild, so that "it's backed up" is a thing that has
    been demonstrated rather than believed.
30. As the owner, I want the mail it examined and the mail it flagged counted side by side,
    so that a classifier that has quietly stopped classifying reads as a ratio, not as a
    calm inbox.

**The owner, filing mail**

31. As the owner, I want the small minority of mail that means something needs doing
    labelled, so that a bill doesn't wait for me to scroll past it.
32. As the owner, I want labels that say what kind of thing it is, not how urgent it is,
    so that only one part of the system decides what interrupts me.
33. As the owner, I want Hermes never to mark my mail read or move it, so that Paperless
    keeps ingesting my invoice attachments.
34. As the owner, I want mail it can't classify put in its own bucket rather than guessed
    at, so that "unsure" is a visible state.
35. As the owner, I want mail excluded from interrupts on day one, so that a misread
    invoice cannot be the thing that teaches me to ignore notifications.

**The builder**

36. As the builder, I want the whole thing provisioned by ansible from this repo, so that
    helium is reproducible rather than hand-wired like the host that shipped fake weather.
37. As the builder, I want the image pinned by digest, so that a project releasing six
    times in two months cannot upgrade my assistant overnight.
38. As the builder, I want secrets in sops, so that a public repo never carries the API key
    or the Telegram token.
39. As the builder, I want a healthcheck that reads output rather than exit codes, so that
    three separate commands that exit 0 while reporting failure cannot report health.
40. As the builder, I want the two steps only a human can do named as prerequisites, so
    that a build doesn't stall halfway with no note of why.
41. As the builder, I want the verification scripts testable without the container, so that
    the date math and the failure paths have tests rather than a live trial.
42. As the builder, I want every rejected alternative recorded with its reason, so that the
    next session doesn't re-derive eight settled decisions.

**The next session**

43. As a future session, I want the write surface enumerable from outside the agent, so
    that "what did it change yesterday" doesn't require trusting the agent's own log.
44. As a future session, I want the always-loaded context measured, so that adding to it is
    a decision with a number rather than a habit.
45. As a future session, I want the vault's own instructions to describe Hermes' real
    surface, so that two assistants sharing a vault don't assume exclusivity.

## Implementation Decisions

Every decision below is inherited from a resolved ticket on
[the map](../map.md); the ticket holds the reasoning and the verification. Where a
ticket **corrected** an earlier one, the correction is what's written here.

### Deployment (`03`, `01`)

- **One compose service in helium's existing single stack**, from a **derived image** built
  on the pinned upstream — same pattern as the Proton bridge service. The derived image is
  where extra binaries (e.g. `himalaya`, absent upstream) get pinned.
- **Engine: hermes-agent v0.19.1, pinned by digest** (`v2026.7.30@sha256:b869e64d…`).
  Never `:latest` — CI tags that on **every main commit**, so it's main HEAD, not the
  newest release.
- **The entrypoint must be set explicitly to the gateway command.** The image's default
  CMD is the interactive CLI, which **exits 0** — under a restart policy that is a restart
  loop that reports success.
- **Runs as uid/gid 1000 via the image's own env vars.** `--user` is rejected by the image.
  This is why the vault replica needs no second re-spec.
- **State on the SSD app-data path, so restic already covers it.** The vault mounts
  **outside** the agent's home, beyond the reach of the image's boot-time chown.
- **No published ports, no Traefik router, no HTTP probe** — the API server and dashboard
  are both opt-in and nothing listens by default.
- **Helper scripts are copied onto the state volume by ansible, not baked into the image** —
  a bind mount masks baked-in paths, and the loader rejects a symlink that resolves outside
  its root.
- **Rebuild is split by authorship:** human-authored config from git, agent-accumulated
  memory from restic.

### Secrets and identity (`03`, `09`, `10`)

- **One sops-fed `.env` inside the state volume** carries every secret. Placement is
  verified, not assumed: the gateway reads the allowlist with a bare env lookup, and
  without the file bridged it would have DM'd **pairing codes to strangers** while looking
  locked down.
- **sops rather than plain vars**, because this repo is public.
- **Telegram: one numeric user id allowlisted, DM-only.** The group block is
  `TELEGRAM_ALLOWED_CHATS` set to a sentinel that is not a reachable chat id — measured to
  stop all five group shapes while DMs pass. It goes in the `.env`, **not** the YAML config,
  whose platforms block ships commented out and would win if uncommented.
- **`guest_mode` stays false** — the one bypass never to enable.
- **BotFather's join-groups setting is deliberately not load-bearing**: BotFather state is
  invisible to ansible and to the rebuild drill, which is this map's enemy class reached
  through its own defence.
- **Pairing dissolves rather than being rejected** — any allowlist flips unauthorized DMs to
  silent-ignore, so no pairing code can ever be generated. This also closes a drift path
  where an in-app approval would write the ansible-templated `.env` and be reverted on the
  next run.
- **A compromised Telegram account is accepted as total compromise.** No second factor.
- ⚠️ **Two needs-human prerequisites** (see *Further Notes*): the Anthropic API account,
  and one `getUpdates` call to acquire the real numeric id — the id currently written down
  has **no provenance** and may be the bot's.

### Inference (`09`)

- **Anthropic direct, one provider for both modes, BYO API key, no fallback chain.**
- **No router.** The routing-preference object has six axes and the **cron path forwards
  only four** — the two dropped are the privacy-relevant ones, so a `deny` would be honoured
  on every Telegram exchange the owner can see and **inert on the 20:00 brief**. Going
  direct makes the defect unreachable rather than mitigated.
- **No fallback chain**, because a hop is invisible to the drift guard, to the executions
  ledger, and to the owner. An outage arrives as a failed job instead.
- **Cost ceiling: $25/month, converted once into a token ceiling recorded with the price
  and the date it was priced** — token counts come from the API, while a hardcoded price
  table goes stale silently.
- **Provider, model and cost are recovered from the state database's per-session usage
  table** (the cron executions table has no model or provider column at all); a fallback hop
  would write a second row.
- ⚠️ **A pre-run script can only ever report the *previous* run** — it executes before the
  session id exists. So routine visibility rides the footer as a trailing line, and the
  ceiling tripwire is a separate post-brief script job.
- **The model drift guard is inert for a digest-pinned job** — pinning is stronger, but say
  so rather than let a closed ticket's advice quietly stop applying.

### The vault surface (`08`, `04`, `11`, `14`)

- **Whole vault mounted read-only; exactly one writable directory — the inbox — via an
  overlapping read-write bind mount.** A read-only mount holds even against uid 0, but it
  enforces **location, not creation-only**.
- **The service must verify its writable path exists and never create it** — Docker
  root-creates a missing bind source, which would silently produce a root-owned directory.
- **Reading is separated into permission and cost:** mount everything read-only (free), but
  always-load only a measured ~16 300 tokens. **Never hand the brief the raw board file** —
  its top section alone is ~16 700 characters of largely superseded reasoning.
- **Hermes files into the vault inbox under the vault's existing note convention**, tagged
  as its own source, and the brief reports the undrained backlog depth and oldest note age.
- **The vault's undo is staggered Syncthing versioning on krypton** — not git (helium's
  replica has no repo; finance data is untracked). ⚠️ Its retention field is in **seconds**;
  the human-friendly number yields six minutes of history while looking configured.
- **Versioning fires on replace and delete, never on create** — so the creation-shaped
  write surface has no one-click undo. Clutter, not loss; recorded so nobody assumes
  otherwise.
- **The vault's own agent instructions already describe this surface** (whole-vault read,
  inbox-only write, never reorganizes, enforced by the mount).

### The two push channels (`06`)

- **They differ in kind.** The interrupt channel is a **script with no model**, silent when
  all is well. The brief is **the one agent job** and the only place judgment happens.
- **Interrupts are edge-triggered, T-2, fire-once**, with a **seeded-and-announced cold
  start** — a level-triggered "due or overdue" test would fire six times on day one and
  forever after, because the board is pruned by deletion and holds no completed items.
- **The brief runs at 20:00**, always arrives, adaptive length: BLUF first line, then
  sections, then a footer.
- **A section may collapse if and only if its source can distinguish *empty* from
  *exhausted*.** This is the general rule; the dose section is only allowed to be
  injection-nights-only because its machine-readable block makes exhaustion detectable.
- **The footer never collapses**, and it is load-bearing rather than cosmetic: it is what
  makes the gathering script **incapable of empty output**, which is what closes a verified
  silent-skip path. It carries the mail examined/flagged ratio, the inbox backlog, vault
  status, the interrupt-state count, and the corrections count.
- **Delivery is job configuration, never prompt text.** Cron jobs have messaging disabled,
  so a prompt instructing "send this to Telegram" is unexecutable *and* invites silent
  non-delivery.
- ⚠️ **The engine prepends a silence instruction to every cron job**, so the brief's prompt
  must **countermand** it — an earlier ticket's "no prompt may instruct silence" is
  unachievable as written.
- ⚠️ **Cron runs with memory writes disabled**, so a correction told in Telegram **cannot**
  reach the brief. Corrections are therefore a file on the state volume that the gathering
  script includes verbatim, with the footer's count as the falsifiable did-it-stick test.
- **Grace is half the period capped at two hours; missed runs collapse to one catch-up
  fire.** A non-zero exit is reported; a zero exit with no output is silence.
- **Household data and weather are out** — see *Out of Scope*. This makes the founding
  fake-weather bug **unwritable** rather than merely detectable.
- **The dose section computes from the machine-readable block only** — never the prose, never
  a hardcoded parity rule. Ticket `13` landed that block; two riders travel with it, in the
  map's Notes.

### Email triage (`07`)

- **"Filing" means applying one label, and nothing else.** One verb: copy into a
  `hermes-*` label namespace.
- **Exception-only, never a classification of everything.** "412 labels applied" is
  uncheckable by anyone and would hide a drifted classifier for months.
- **Four topical buckets — bill, escalation, action, unsure — deliberately not
  severity-based**, so the interrupt policy stays the single owner of urgency.
- **No vault writes at all from the mail half.**
- 🔴 **Never set the read flag and never move a message.** The document pipeline fetches
  **only unseen inbox mail**, so marking read first means an invoice's attachments are
  **never ingested, silently**. Every read uses a peek fetch; a bare body fetch sets the
  flag implicitly.
- **A UID watermark replaces the read flag as the "already examined" signal** — the mailbox
  has 444 messages and 2 unseen, so the flag carries no information here. A changed
  mailbox-validity id and an absent watermark are both **errors**, never a silent re-seed.
- **One shared bridge session** with the document pipeline, because that makes the brief's
  provenance check the monitor that pipeline never had.
- **Outbound mail is a documented non-capability, not a blocker** — no verb in the contract
  needs a send path.
- **A consumer must be a container on the bridge's internal network** — it publishes no
  ports.

### Verification (`05`, plus corrections to `03`)

- **Three liveness alarms that fire on absence, four correctness controls, one rebuild
  drill.**
- **Correctness rests on provenance timestamps**: every source emits its *upstream's own*
  last-updated time. This makes the fake-weather class **unwritable**. A variance tripwire
  covers real-but-wedged sources.
- **The audit trail is a filesystem manifest diff produced by a script, printed beside the
  agent's own prose**, so a claim with no matching write is visibly contradicted. 🔴 This
  replaced an earlier plan to enumerate writes from the agent's logs: a successful write
  produces **zero** log mentions. The manifest diff is strictly stronger — mechanism-agnostic,
  deletion-aware, unfabricatable, and complete *because* the write surface is narrow.
- **Alarms ride the existing MQTT→Home-Assistant path.** No metrics collector, no dashboard —
  standing one up to watch the watchman is one more thing that can fail silently.
- ⚠️ **The alarm must key on the container-state entity, not the health entity** — the
  health entity **does not clear when a container stops**.
- 🔴 **The healthcheck must bound the last *successful* tick, not just the heartbeat** — as
  first specced it reports healthy when no scheduled run has **ever** succeeded.
- **The healthcheck gains one assertion for a dead Telegram transport**: a rejected or
  revoked token leaves the gateway up and running cron by upstream design, so cron-liveness
  alone reports healthy while pull mode is dead — and the dead channel cannot report its own
  death over itself.
- **The identity file that carries the two anti-fabrication rules must be asserted on by
  *content***, not existence: the built-in doctor command reports it present against the
  image's own 513-byte default, and **exits 0 with failures printed**.
- **Restore is the engine's import command**, not the obvious name.
- **Rebuild drill, falsifiable:** a rebuild from git **plus the age key** must yield a
  working but **amnesiac** Hermes.

## Testing Decisions

**What makes a good test here:** it asserts on **externally observable output** — the text a
script prints, the label state in the mailbox, the entity Home Assistant receives, the files
present after a run. It never asserts on how the output was produced, and it **never asserts
on the model's prose**. The model is not under test; the facts it is handed, and the
structures that make a fabricated fact impossible to source, are.

**The primary seam: the gathering script's standard output.** One seam, chosen deliberately
over several. Every source — dose dates, board dates, mail counts, inbox backlog, cost,
write manifest — feeds it, and it is a pure function of fixtures in to text out. Prior art
exists in shape: the recovered briefing scripts already used a per-source `STATUS=OK/ERROR`
contract, verbatim passthrough, and date math in the script rather than in the prompt. Test
at that seam:

1. **Every source's OK and ERROR rendering**, including that an unreachable source renders
   `ERROR` rather than being omitted.
2. **Empty vs exhausted**, per source that is allowed to collapse. A source that cannot
   distinguish them must not collapse.
3. **The dose boundary:** a date past the schedule's phase-1 end emits `ERROR`, not a
   computed answer, and not silence. Fixture-driven, with the block's dates parsed as dates
   (they deserialize as date objects, not strings — a string comparison would pass by luck
   on ISO ordering while being wrong in kind).
4. **Interrupt edge-triggering:** an item two days out fires exactly once; the same item on
   subsequent runs fires never; a cold start seeds and announces rather than flooding.
5. **Two required negative tests, both for verified silent-skip paths.** Empty output makes
   the engine skip the agent call entirely, and a trailing wake-gate marker in the output
   skips the whole run. Both are reachable from a script that emits structured blocks, so:
   assert the footer makes empty output **impossible**, and assert no emitted block can be
   read as a wake-gate marker.
6. **Provenance:** every source line carries an upstream timestamp, and a stale-but-alive
   source trips the variance tripwire.
7. **The footer's invariants:** always present, carries the mail ratio and the corrections
   count, and the rendered output can neither begin nor end with a silence marker.

**Second seam: the healthcheck's output parse.** Three separate engine commands were
measured to **exit 0 while printing failure** — cron status with a dead gateway, the doctor
command with failures, and gateway status with the gateway down. So the test feeds recorded
output (both healthy and each failing shape) to the parser and asserts the verdict, and
asserts specifically that a never-succeeded scheduler reads as unhealthy. Prior art: the
verified probe transcripts already captured in this map's assets.

**Third seam: an ansible converge on helium.** Idempotence (a second run changes nothing),
the digest pin materializing as the intended digest, the mount pair being read-only plus one
writable directory, the secrets file present and readable inside the container, and the
service surviving a restart. Prior art: this repo's existing roles and the metrics/MQTT
issue's wiring.

**Not seams, deliberately:** the delivered Telegram message (cron has messaging disabled and
the transport can die while the container lives — its liveness is an MQTT assertion, not a
message assertion), and any second write-audit mechanism beside the manifest diff.

**One drill, not a test:** the rebuild — from git plus the age key to a working, amnesiac
Hermes. It is verified by doing it once, and its result recorded.

## Out of Scope

Carried forward from the map, where each was ruled out with its reason. Re-deriving these is
how they creep back:

- **Owning the board file and the inbox drain** — the write-heavy, highest-trust path. A
  named follow-on, not a prerequisite.
- **Kivra** — official and legal mail has no IMAP and no bridge; already assigned a weekly
  human check. A stated coverage limit, so the brief must never imply it watches everything
  official. The spam folder is a second, smaller accepted gap (1 message).
- **Wiring the finance importer to consume Hermes' labels** — better than that importer's
  own plan, and still out: it makes an unbuilt pipeline a dependency and gives the labels a
  second consumer before the first is trusted.
- **Home Assistant as a read source, and with it all household data and weather.** Ruled out
  on demand, not risk. This is what makes the fake-weather bug unwritable. (The MQTT alarm
  path is the opposite direction and is in scope.)
- **Mail-triggered interrupts.** Accepted cost: a bill arriving at 09:00 and due tomorrow
  waits until 20:00.
- **Calendar** — needs credentials re-established and an owner-tagging scheme that was never
  verified working. Cheap to add later.
- **Goals / completion contracts** — rests on an engine feature to adopt once the base is
  trusted.
- **Reporting the routing-preference gap upstream** — a real two-line upstream fix, but it
  cannot affect this deployment under the direct-provider decision.
- **A local model on helium** — a host PRD non-goal; the GPU is pulled and the RAM won't
  carry it.
- **A metrics collector, and with it the engine's OTLP exporter.** Noted trap if one ever
  arrives: each metric is emitted only when non-null, so "never succeeded" is an **absent**
  metric, not a zero.
- **Public internet exposure** — forbidden by the host PRD; Telegram is outbound-only.

## Further Notes

**Two prerequisites only the owner can do**, and the build should stop rather than work
around either:

1. **Create the Anthropic API account and key.** There is no key and no provider profile on
   krypton, so this is a **new metered account**, not the existing Claude Code subscription —
   a real new cost, and outside ansible.
2. **One `getUpdates` call to acquire the Telegram numeric id.** The id in the tickets has no
   provenance anywhere else and may be the bot's. That single call yields both the allowlist
   id and the brief's delivery chat id — the same number for a DM.

**A third, adjacent:** staggered versioning on krypton's vault folder is the vault's only
undo, and it sits outside helium's play. Owned by the vault-serve replica ticket as
*responsibility*, with the mechanism left to the builder — flagged here because it is the
item most likely to be quietly dropped.

**Egress is settled and deliberate.** Vault contents — including finance, health, journal and
people — and inbox mail stream to a third-party inference endpoint continuously and
unattended. Chosen over a read include-list because the board's live items are almost
entirely finance, and the inbox already carries bank statements and official mail, so
excluding finance while ingesting email is theatre. For Anthropic specifically this is a new
**workload**, not a new **counterparty**: 90 prior sessions already had this vault as their
working directory. ⚠️ That narrows the counterparty point, **not** the posture — a
subscription and a metered API key are governed by different documents, and the API one is
stricter.

**Two riders with no home yet** live in the map's Notes and belong to whoever builds the dose
section: the provenance timestamp for that file crosses Syncthing to helium and is
**unverified** (compare both sides after an edit), and its dates parse as date objects rather
than strings.

**Slicing.** This spec is the epic; thin vertical slices graduate from it as `016` onward in
this folder. Suggested cut, each independently verifiable: the service and its mounts; the
gathering-script framework and its footer; the interrupt channel; the brief; email triage;
the alarm and healthcheck wiring; the rebuild drill.

## Acceptance criteria

- [ ] Hermes runs as a compose service on helium from a digest-pinned derived image,
      provisioned by ansible, and survives a host reboot.
- [ ] A second ansible run reports no changes.
- [ ] The vault is mounted read-only with exactly one writable directory, verified from
      inside the container; a write outside it fails.
- [ ] A Telegram DM from the owner is answered; the same message in a group is not.
- [ ] The 20:00 brief arrives on a day with nothing to report, carrying BLUF and footer.
- [ ] Every brief section names its source's own last-updated time.
- [ ] An unreachable source renders `ERROR` in the brief; it is never omitted.
- [ ] A dated board item two days out produces exactly one interrupt, and none thereafter.
- [ ] On an injection night the dose section renders; on a date past the schedule's phase-1
      end it renders `ERROR`.
- [ ] Mail that means something needs doing carries a `hermes-*` label; the read flag is
      unchanged mailbox-wide and the document pipeline still ingests attachments.
- [ ] The brief's footer shows the examined/flagged ratio, inbox backlog, and corrections
      count.
- [ ] A correction written to the corrections file appears in the next brief and increments
      the footer count.
- [ ] A missing brief raises an alarm in Home Assistant that did not travel via the brief.
- [ ] A revoked Telegram token raises an alarm while the container is still running.
- [ ] The healthcheck reports unhealthy when the scheduler has never succeeded.
- [ ] The write manifest for a run matches what the agent claims it changed.
- [ ] The monthly token ceiling trips an alarm when crossed.
- [ ] The rebuild drill has been performed once: from git plus the age key to a working,
      amnesiac Hermes.
