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
  therefore carries the weight (still fog).
- **The last catastrophe was self-inflicted by making the vault the agent's brain.**
  v0.14 Hermes autonomously reorganized its vault, deleted `.stfolder`, and
  Syncthing safety-halted with no self-heal → silent stall up to an hour, badly
  diverged sides (see `project_hermes_vault_sync`; a marker-guard path-unit was
  built to babysit it). v0.19 has first-class persistent memory of its own in
  `~/.hermes` plus `/journey` to inspect it. **Keep Hermes' memory in `~/.hermes`
  and treat `~/vault` as a data source it reads and files into — never as its
  brain.** Then it has no reason to restructure the tree.
- **Scope escalated vs. every prior attempt:** old Hermes read its own separate,
  sparse `~/hermes-vault` (different structure — `Areas/Health/…`). That folder is
  **gone**; krypton's Syncthing now shares `personal-vault` (`~/vault`) and `Notes`
  (`~/notes`). This effort puts the agent in the **real** vault — `finance/`,
  `health/`, `journal/`, `people/`, and the live `tasks.md` board. `~/vault` **is a
  git repo** with real history: that is the safety net for agent writes.
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
- **Engine is open, but hermes-agent is the incumbent.** Nous hermes-agent is now
  **v0.19.1** (2026-07-30) vs the v0.14 that ran on titan — named releases every
  2–3 weeks. v0.18.0 claims 700+ P0/P1 issues resolved plus completion contracts
  for goals and `/learn`; v0.19.0 added durable message delivery. Backends are now
  local/**Docker**/SSH/Singularity/Modal. **That cadence is itself a durability
  risk** — pinning and upgrade policy are part of the answer, not an afterthought.
- **Reusable prior art:** branch `hermes/briefings` (commit `abb62a6`, never
  merged) holds ~740 lines of already-debugged config deleted from `main` by
  `4ed7e63` — `configs/hermes-agent/` (SOUL.md, morning+weekly briefing scripts and
  prompts, env.example, vault-skeleton), `modules/hermes-agent/`,
  `modules/hermes-vault/`, `bin/hermes-vault-ensure-marker.sh`, and
  `hosts/titan-hermes-agent/`. Recover, don't rewrite.
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

_The destination-shaping decisions taken during charting are recorded in **Notes**
above (egress posture, write posture, channel, replaces-`/daily`,
memory-out-of-vault, beachhead scope)._

## Not yet specified

- **Model/provider choice under full egress.** Which inference provider, on what
  retention/no-training posture, and bring-your-own-key (the old openrouter setup)
  vs the new paid **Nous Portal** credit tier. Hangs on the engine ticket — a
  non-hermes-agent engine changes the option set entirely.
- **Telegram identity/authorization.** How the conversational mode establishes that
  it is *you* messaging, given it can read `finance/` and `health/` and act on the
  vault. Old setup pinned a single chat id (8468278488); whether that is sufficient
  is unexamined.
- **Whether `/daily` and the `note` skill get retired or rewired.** Hermes taking
  over ambient capture makes the inbox-file convention partly redundant; can't be
  specified until the board-ownership follow-on is scoped.

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
