# Map: Hermes as a durable personal assistant on helium

`wayfinder:map` — child tickets live in `planning/hermes-helium/issues/`.

## Destination

A **decision-complete plan** for Hermes running **durably** on **helium** as a
personal assistant over `~/vault` + the Proton inbox, in **both modes**:

- **Pull — conversational, on the go.** Message it from the phone (Telegram):
  query the board, capture a note, ask a question, ask it to file something.
  Human in the loop for every exchange.
- **Push — ambient background.** Email triage + filing, urgent interrupts, and an
  end-of-day brief. Unattended.

Decision-complete means: engine chosen and **version-pinned**; deployment shape
and state placement settled; vault **write posture** (Send-Receive, narrow write
surface) and the **full-egress** boundary settled; notification policy
(urgent-interrupt vs evening-digest) settled; and a **verification story that
makes silent failure impossible**.

## Notes

- **Domain:** `~/.dotfiles` homelab. helium = bare-metal Debian NAS+services box,
  ansible-provisioned, docker-compose stack behind internal Traefik, NetBird mesh
  + split-horizon DNS `*.home.stromdahl.tech`. See `hosts/helium/PRD.md`.
- **This is attempt five, and that is the requirement.** Prior lives:
  `argon-hermes` LXC 201 → removed; `titan-hermes` LXC 102 → removed;
  `titan-hermes-agent` VM 101 (the real one — Nous hermes-agent v0.14, Telegram +
  openrouter, internal cron, morning/weekly briefings) → decommissioned
  2026-06-21 in `4ed7e63` when titan was rebuilt as helium. That commit cites
  "(ADR 0001)" but **`adr/0001` is `public-app-tier-radon`, created 2026-07-02 —
  eleven days later — and never mentions Hermes.** The reference is dangling:
  **no ADR ever ruled against Hermes.** It died as collateral of host churn, not
  by judgment. Cause of death was diagnosed as **both** host churn *and* lost
  trust (see next note); helium is the first stable services host, so the churn
  half is nearly solved for free — this map owns the trust half.
- **Silent failure is the enemy — treat it as first-class, not ops polish.**
  The recurring pattern across this homelab: the morning briefing shipped
  **hardcoded fake weather** (11.3 °C/Sunny, never queried HA) for an unknown
  span; `Sync/Hermes-Claude-Bridge.md` was written to for weeks and **nothing
  ever read it**; the Proton bridge session dies and Paperless surfaces **no
  error**; helium's HDDs return `rc=0` to spin-down commands and keep spinning.
  Every one *looked* fine. An agent trusted to watch email unattended must fail
  loudly by construction.
- **Egress is settled and deliberate: full egress accepted.** helium has **no
  discrete GPU** (RTX 2060 pulled; i5-9400 6C/6T, 16 GB) and
  `hosts/helium/PRD.md` lists a **local LLM as an explicit non-goal** — so cloud
  inference it is. Vault contents (incl. `finance/`, `health/`, `journal/`,
  `people/`) and inbox mail go to a third-party inference provider continuously
  and unattended. Chosen over a read include-list because (a) `tasks.md`'s
  `🔥 Now` is *entirely* finance items — excluding `finance/` guts the highest-value
  use cases, and (b) the inbox already carries bank statements, Proton invoices and
  Kronofogden mail, so excluding `finance/` while ingesting email is theatre, not a
  boundary. **The vault-serve map's "helium already holds Immich photos + Paperless
  docs, so it's not a new sensitivity class" reasoning does NOT transfer here** —
  at-rest on own hardware ≠ streamed to an inference endpoint. Provider choice
  therefore carries the weight — now [ticket 09](issues/09-choose-inference-provider.md),
  graduated from fog once `01` confirmed BYO key is still first-class.
- **The last catastrophe was self-inflicted by making the vault the agent's brain.**
  v0.14 Hermes autonomously reorganized its vault, deleted `.stfolder`, and
  Syncthing safety-halted with no self-heal → silent stall up to an hour, badly
  diverged sides (see `project_hermes_vault_sync`; a marker-guard path-unit was
  built to babysit it). v0.19 has first-class persistent memory of its own in
  `~/.hermes` plus `/journey` to inspect it — **`/journey` is CLI-only though**, so
  inspecting memory needs a shell into the container, not Telegram. **Keep Hermes'
  memory in `~/.hermes` and treat `~/vault` as a data source it reads and files
  into — never as its brain.** Then it has no reason to restructure the tree.
  Ticket `01` verified this is now the *default*: the official image ships
  `HERMES_WRITE_SAFE_ROOT=/opt/data`, so the vault isn't writable until we open it.
  `03` adds that it is a **`:`-separated list of prefixes**, not a single root, so
  opening it is a narrow act — and that the vault mounts at **`/vault`**, outside
  `HERMES_HOME`, beyond the reach of the image's boot-time chown.
- **Scope escalated vs. every prior attempt:** old Hermes read its own separate,
  sparse `~/hermes-vault` (different structure — `Areas/Health/…`). That folder is
  **gone**; krypton's Syncthing now shares `personal-vault` (`~/vault`) and `Notes`
  (`~/notes`). This effort puts the agent in the **real** vault — `finance/`,
  `health/`, `journal/`, `people/`, and the live `tasks.md` board. **Correction from
  `03`: git is NOT the safety net for agent writes** — this note used to say it was.
  `~/vault/.stignore` excludes `.git`, so helium's replica has **no repo at all**;
  `.gitignore` deliberately untracks finance *data* (`.stignore` says why: *"the
  sensitive-data boundary is git"*); and Syncthing file versioning was **off on every
  krypton folder**. The owner declined a git audit repo on helium ("dont think we need
  git for the vault"). The undo is now **staggered Syncthing versioning on krypton**
  — see [ticket 11](issues/11-vault-undo-riders-to-vault-serve-004.md), and note its
  `maxAge` is in **seconds** (`31536000`), a trap that looks configured when wrong. Git still
  covers the 215 tracked files on krypton, and nothing on helium.
- **Hermes replaces `/daily`, which is dead.** The vault's charter in
  `~/vault/AGENTS.md` ("keep the owner's personal life organized — board,
  inbox/reminders, records, planning, drafts; do not do project execution work") is
  almost exactly this ask, minus the at-a-laptop constraint. `~/vault/daily/` is
  **empty** — the drain never became habitual. Board/inbox-drain ownership is
  nonetheless a **follow-on**, not this map (see Out of scope): it is the
  write-heavy path into the live board, too much trust to extend on day one.
- **The email half is already built.** Proton Mail Bridge runs on helium (issue
  `029`, live 2026-07-10), serving IMAP for `mattias.stromdahl@pm.me` to Paperless.
  Carry these forward: **SMTP send is broken** (`454 4.7.0 unknown error`; IMAP
  receive fine) → Hermes cannot reply or move mail by sending; the **session dies
  silently** when Proton invalidates it; it sits on an **internal bridge network
  with no published ports**, so a consumer must be a container on that network.
  Details in `project_helium_protonmail_bridge_paperless`.
- **Channel:** Telegram. Proven, a hermes-agent first-class integration, and
  outbound-only — fits helium's no-ingress posture with no port to open.
- **Engine is settled: hermes-agent v0.19.1, pinned by digest** —
  `v2026.7.30@sha256:b869e64d…`. See the decision below; don't reopen. Two things
  that note used to get wrong: `:latest` is **main HEAD**, not the newest release
  (CI tags it on every main commit), and the "local/**Docker**/SSH/Singularity/Modal
  backends" list is about the agent's *own tool sandbox*, **not** about running the
  agent in a container — those are separate settings and only the sandbox one is a
  `terminal.backend`. The release cadence is worse than assumed (six named releases
  in ~2 months), which is why the pin is by digest and upgrades are rare.
- **Reusable prior art — inventoried, and the recovery recipe is not what it looks
  like.** ~740 lines of already-debugged config were deleted from `main` by
  `4ed7e63`. **Do not try to merge `hermes/briefings`: `abb62a6` is an *ancestor of
  `main`* (and of `origin/main`), so merging it is a no-op** — the branch is a stale
  local pointer, never pushed. **Recover with `git checkout 4ed7e63^ -- <path>`**,
  which is also one commit richer than the branch. All 21 files are judged
  keep/adapt/discard in
  [ticket 02](issues/02-recover-briefings-branch-inventory.md) — read that verdict
  table before recovering anything; several items are stale or actively harmful, and
  only `SOUL.md` is a straight keep.
- **Skills:** `/grilling` + `/domain-modeling` for the grilling tickets;
  `/research` for the research ticket.
- **Plan, don't do:** this map produces decisions. Execution graduates into
  implementation issues once the way is clear (mirroring how vault-serve graduated
  `004`/`005`).

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Re-spec vault-serve 004 to Send-Receive and cross-link both maps](issues/04-respec-vault-serve-004-send-receive.md) —
  applied; the flip touched **four** files, not one (`02` and `03` *reasoned from*
  Receive-Only). Perlite's read path is **unaffected — verified**: `Ignore
  Permissions` is folder-type independent, so `UMask=022` still yields `755`/`644`.
  New ground truth for tickets `05`/`08`: **Send-Receive propagates local deletions
  upstream**, so a Hermes reorg on helium destroys files on krypton *and* the phone;
  and the replica folder must be created **empty** or provisioning content is pushed
  upstream. vault-serve `004` stays open execution work.
- [Choose the engine and land a version-pinning policy](issues/01-choose-and-pin-engine.md) —
  **hermes-agent v0.19.1 stays**, pinned by digest
  (`v2026.7.30@sha256:b869e64d…`); nothing was *clearly* better on unattended-push
  reliability so the tie rule decided it. Full findings, per-claim verification
  tags, in [assets/01-engine-research.md](assets/01-engine-research.md). The three
  findings that change other tickets: **`:latest` is main HEAD**, not the newest
  release, and every upstream compose example uses it; **the container bind-mount is
  the only real write boundary** — `HERMES_WRITE_SAFE_ROOT` and the denylist don't
  bind the `terminal` tool, and upstream says so; and **v0.19 doesn't remove v0.14's
  gathering-script scaffolding, it blesses it** (`no_agent` jobs make it first-class
  and alert on non-zero exit). Real fail-closed primitives now exist (drift guard,
  failed-jobs-always-deliver, mutation verifier) but **none catches
  plausible-but-fabricated content** — the fake weather would still ship, so `05`
  carries this map's weight, not `01`. Also: BYO key stayed first-class (no drift to
  the hosted product), there is **no container `HEALTHCHECK`**, `himalaya` isn't in
  the image, and the Email *gateway adapter* marks the whole inbox seen on first
  start — inherited into `03`/`05`/`07`/`08`.

- [Inventory the hermes/briefings branch: what survives, what is superseded](issues/02-recover-briefings-branch-inventory.md)
  — **Of 21 files, exactly one is a straight keep: `SOUL.md`** — and it matters more
  than its 18 lines suggest, because it states the two anti-fabrication rules `01`
  found *no engine primitive enforces*, making it the only current defence against
  the fake-weather class (so `05` must verify it loads, not assume it). Four files
  adapt, and what survives in the briefing scripts is the **shape, not the sections**
  — the per-source `STATUS=OK/ERROR` contract, `<verbatim>` passthrough, date-math-in-script,
  and a credential read from `.env` that is *accidentally correct* given cron's
  sanitized env. Every emitter is out of scope (calendar, inbox/board, news) or
  **sourceless**: the medication note the script read no longer exists in `~/vault`,
  so a 💊 section is a prerequisite for `06`, not an adaptation. The
  `vault-skeleton/` three-tier memory pattern and both dotfiles modules are
  **discarded** — superseded by v0.19 memory, and by ansible-only helium. Four
  defects must not be carried forward, the worst being **"send the briefing to
  Telegram" in all three prompts** — cron jobs have `messaging` disabled, so it is
  unexecutable *and* invites a silent non-delivery. Three provenance corrections
  (see Notes): the branch was already merged, recovery point is `4ed7e63^`, and
  **the fake-weather script was never in this repo** — `abb62a6` is the fix, born
  clean, which narrows `03`'s "never in version control" claim to *the module was
  commented out and the live host was wired by hand*. The marker guard's owner is
  already vault-serve `004`.

- [Decide the deployment shape and state placement on helium](issues/03-deployment-shape-and-state.md)
  — compose service in helium's one stack, derived image (`protonmail-bridge`
  pattern), `command: ["gateway", "run"]`, state at `/data/ssd/appdata/hermes`,
  vault at `/vault`, secrets in one sops-fed `.env` **inside** the volume. Four boots
  of the pinned image on helium overturned four assumptions, three of them agreed
  earlier in the same session — read the ✅ tags before re-deriving anything.
  **`--user` is rejected by the image**; `HERMES_UID=1000`/`HERMES_GID=1000` is the
  supported path and works, so Hermes runs as `ms` and **vault-serve `004` needs no
  second re-spec**. **The default CMD exits 0** (it's the interactive CLI; s6 then
  stops the container) — under `restart: unless-stopped` that is a restart loop
  reporting success. **`hermes cron status` exits 0 even when the gateway is dead**,
  so the healthcheck parses output, never the exit code — it greps the affirmative
  line *and* bounds the ticker-heartbeat age, accepting false alarms on upgrade as
  the correct failure direction. **Scripts cannot be baked into the image** (the
  bind mount masks them and `resolve()`-then-`relative_to` rejects a symlink out),
  so ansible copies them onto the volume — which also closes `02`'s
  porting worry, since v0.14's symlink mechanism would now be rejected outright.
  **Nothing listens on 8642 or 9119** (API server and dashboard are both opt-in), so
  no Traefik router and no HTTP probe — a correction to `01`. Rebuild is **split by
  authorship** — human-authored → git, agent-accumulated → restic — with the
  falsifiable test handed to `05`: *a rebuild from git **plus the age key** must yield a working but
  amnesiac Hermes.* And the git-audit-trail idea died: `.stignore` excludes `.git`,
  `.gitignore` untracks finance data, and **versioning was off on every krypton
  folder**, so the vault's only undo is now a rider to vault-serve `004` (ticket `11`).

- [Hand the vault-undo riders to vault-serve 004](issues/11-vault-undo-riders-to-vault-serve-004.md)
  — applied; `004` now carries staggered versioning on **krypton** (`maxAge`
  365 days), `.git` in helium's ignore patterns, and the cross-link, under a
  **"required — the only undo there is"** heading. Re-verifying rather than
  propagating caught one defect: **`maxAge` is in *seconds*** — the "365 days" this
  map has been repeating is the GUI's unit, and a role templating `config.xml` with
  `365` gets **six minutes** of history while *looking* correctly configured. That is
  this map's own enemy class reached through its own undo, so `004`'s Done-when now
  demands `31536000` plus a round-trip test (edit on helium → prior version appears
  in krypton's `.stversions/`). Both docs claims behind the krypton-only choice are
  now quoted inline in `004`: versioning fires **only on incoming changes** (so
  helium, where Hermes writes *locally*, is the wrong side), and `.stignore` is
  **never synced** (so krypton's `.git` exclusion doesn't travel). Also struck `004`'s
  two remaining *"git is the safety net"* claims, stale since `03`. One seam left
  open on purpose: **item 1 is a krypton change, outside helium's ansible play** —
  `004` owns that it happens, not how.

- [Design the loud-failure / verification story](issues/05-loud-failure-verification.md)
  — the trust half, settled: **three liveness alarms that fire on *absence*, four
  correctness controls, one rebuild drill.** The brief **always arrives**
  (adaptive-length), so silence is itself the alarm and **no job prompt may instruct
  `[SILENT]`**. Correctness rests on **provenance timestamps** — every source emits the
  *upstream's own* last-updated time, which makes the fake-weather bug *unwritable*
  rather than merely detectable — plus a variance tripwire for real-but-wedged
  sources. The audit trail is a **`no_agent` write list printed beside the agent's own
  prose**, so a claim with no matching writes is visibly contradicted. Alerts ride the
  **existing MQTT→HA** path; no OTLP collector, no dashboard. **Two corrections to
  closed work, both this map's own enemy class:** `03`'s healthcheck reports
  **healthy when no cron tick has *ever* succeeded** (it bounds `ticker_heartbeat`
  but not `ticker_last_success`), and its onward path must key on docker2mqtt's
  **`state`** entity — `046` verified **`health` does not clear when a container
  stops**. Also verified on the box: **`hermes doctor` exits 0 with `✗` failures**,
  and its `✓ SOUL.md exists` is **green on the image's own 513-byte default**, so
  `02`'s "verify it loads" must assert on *content*. Restore is **`hermes import`**,
  not `hermes restore`.

_The destination-shaping decisions taken during charting are recorded in **Notes**
above (egress posture, write posture, channel, replaces-`/daily`,
memory-out-of-vault, beachhead scope)._

## Not yet specified

- **Whether `/daily` and the `note` skill get retired or rewired.** Hermes taking
  over ambient capture makes the inbox-file convention partly redundant; can't be
  specified until the board-ownership follow-on is scoped.
_(The **Telegram identity/authorization** patch graduated to
[ticket 10](issues/10-telegram-authorization.md) once `03` landed the deployment
shape and a real boot surfaced `TELEGRAM_ALLOWED_USERS` plus the deny-by-default
posture.)_

_(The **human inspection surface** patch is **closed, not graduated** — `05` answered
it rather than sharpening it into a ticket. Routine visibility is pushed into the
evening brief as a script-generated write list; deep inspection stays CLI-only via
`docker exec`, and that is now an accepted answer. No read-only web surface. See
`05`'s **D4**.)_

## Out of scope

- **Owning `tasks.md` and the inbox drain** (i.e. fully replacing `/daily`'s write
  path) — the highest-trust, write-heavy path into the live board. A named
  follow-on once the agent is alive and trusted, not a prerequisite for it existing.
- **Calendar.** Asked for, deliberately deferred: needs Google Workspace creds
  re-established, and colour-ID owner tagging (11=Mattias, 5=Hanna, 2=Both) was
  **never verified working** on titan because no GCal events existed. Cheap to add
  once Hermes is alive.
- **Goals / completion contracts.** Asked for, deliberately deferred: rests on a
  hermes-agent feature that shipped four weeks ago (v0.18.0). Add once the base is
  trusted.
- **A local LLM on helium** — `hosts/helium/PRD.md` non-goal; the GPU is pulled and
  16 GB RAM won't carry it. Not revisitable without different hardware.
- **Public internet exposure** — helium PRD forbids it; Telegram is outbound-only
  by design.
