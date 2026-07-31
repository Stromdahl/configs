# Choose the engine and land a version-pinning policy

Type: research
Status: resolved

> ✅ **Scope settled 2026-07-31 (owner decision) — the comparison stays, but it is
> tight and asymmetric. Do not re-ask this.**
>
> The alternative was to lock hermes-agent in and collapse this ticket to a pinning
> policy. Rejected, because that saves no session: the pinning/upgrade policy and
> the "does v0.19 actually remove v0.14's scaffolding" question are open either way,
> so collapsing makes this session thinner, not absent — the fair look is nearly free.
>
> Two rules for it:
> 1. **Scope the comparison to one axis: reliability under *unattended* operation
>    (the push mode).** That is where v0.14 actually failed — not on features. The
>    real work was a 122-line bash script; the agent prose-ified its output, and the
>    fake weather went unnoticed. Do **not** run a general feature bake-off; many
>    candidates do pull well and push badly, and only that gap matters here.
> 2. **The incumbent wins all ties.** hermes-agent has real sunk knowledge, so an
>    alternative must be *clearly* better on that axis to displace it — "roughly
>    comparable" resolves to hermes-agent. Owner's position: *"it's hermes-agent but
>    I'm open to anything, just need to get it working reliably once and for all."*
>
> Everything in requirement 1 below still applies; these rules bound how much effort
> the candidate survey deserves relative to requirements 4 and 5, which are the
> ticket's real weight.

## Question

Is **Nous hermes-agent v0.19.x** the right vehicle for *both* modes this map
targets — conversational-on-Telegram **and** unattended ambient background work
over a markdown vault + IMAP — running as a **Docker** workload on helium? And
whatever wins: **which exact version do we pin, and what is the upgrade policy?**

The engine is genuinely open (owner: *"open to anything, just need to get it
working reliably once and for all"*), but hermes-agent is the incumbent with real
sunk knowledge. Answer it fast and fairly rather than assuming either way.

### What makes this non-obvious

- The owner ran **v0.14**; it is now **v0.19.1** (2026-07-30). Five minor releases
  in ~2 months. v0.18.0 claims **700+ P0/P1 issues resolved** — which implies v0.14
  was rough, and that the specific v0.14 grievances may already be gone.
- **The v0.14 experience was mostly scaffolding, not agency.** The morning briefing
  was a 122-line hand-written bash script that gathered everything; hermes-agent
  only prose-ified it and posted to Telegram. It also **confabulated its own
  internals** when interrogated. The open question is whether v0.19's built-ins
  (persistent memory, `/journey`, `/learn` skills, Automation Blueprints replacing
  raw cron) actually remove that scaffolding, or just rename it.
- **A 2–3-week major-release cadence is a durability risk in its own right** for
  something the owner's daily life depends on. Pinning policy is part of the
  answer, not an afterthought. v0.14→v0.19 also spans a shift in monetization
  (free tier + paid Nous Portal credits) — check whether self-host-with-own-key
  remains a first-class path or is drifting toward the hosted product.

### What the answer must contain

1. **Verdict + reasoning** on hermes-agent v0.19.x vs the alternatives, judged on
   *reliability under unattended operation*, not feature count. Candidates worth a
   look: hermes-agent, Claude Code headless / Agent SDK on a timer, an
   n8n-or-similar pipeline with an LLM step, OpenWebUI-class tools. Explicitly
   assess the two-modes requirement — many candidates do pull well and push badly.
2. **How each mode is actually served** by the winner: what carries the Telegram
   conversation, and what carries scheduled/triggered background work.
3. **Docker-backend fitness on helium** — the deployment *shape* is ticket `03`,
   but flag anything here that constrains it (privileged needs, host-network
   assumptions, sandbox/namespace requirements, whether the Docker backend is for
   *running the agent* or for the agent's own tool sandboxing — these are different
   things and the v0.19 docs list both).
4. **An exact pinned version** and a written upgrade policy: how often, how
   verified before adopting, how rolled back, and what state-format migration risk
   looks like.
5. **Whether the incumbent's known v0.14 defects are fixed** — self-internals
   confabulation, and any tendency to restructure its own working directory (the
   `.stfolder` catastrophe; see the map's Notes).
6. **Bring-your-own-key vs Nous Portal** as it bears on the engine choice — note
   the provider decision itself is deliberately left as fog on the map.

Capture findings as a markdown asset under `planning/hermes-helium/assets/` and
link it from the resolution.

## Answer

**Verdict: hermes-agent v0.19.1 stays, pinned by digest.** Full findings,
with per-claim verification tags, in
[assets/01-engine-research.md](../assets/01-engine-research.md).

```
nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d6496d4763d5e4fb675b5f504cb23b0e35ec9b790481a56118602b10f
```

Requirement-by-requirement:

### 1 — Verdict vs alternatives (unattended-push axis only)

Nothing is *clearly* better, so the tie rule decides it. The predicted pattern
held exactly: the strongest push candidate (n8n-class — real scheduler,
per-execution history, error workflows) has no conversational pull mode;
OpenWebUI-class has no scheduler at all. **Claude Code headless / the Claude
Agent SDK is a harness only — you host it, and it ships no scheduler, no
messaging channel, and no failure alerting**, so every fail-loud primitive below
would become homework. (Anthropic's *Managed Agents* does offer cron-scheduled
deployments, but Anthropic hosts the agent loop *and* the tool sandbox — not a
helium workload, and it would stream vault contents into a hosted container.)
hermes-agent is the only candidate covering both modes in one supervised process.

### 2 — How each mode is served

One container, one long-running gateway. Telegram via the gateway's messaging
adapter; push via the **gateway's background cron ticker (60 s)**. Consequence
worth carrying: a CLI session does **not** fire cron jobs, so no gateway = no
push mode, and there is no container healthcheck to notice (see 3).

### 3 — Docker fitness: confirmed, and the two senses are genuinely different

**Mode 1 (agent in a container) is fully supported** — official multi-arch image,
s6-overlay PID 1, non-root `hermes` UID 10000, one volume at `/opt/data`, gateway
on 8642. **No privileged, no host network, no docker socket required.** Mode 2
(`terminal.backend: docker`) is the agent's *own tool sandbox* and is a separate
choice; keep `terminal.backend: local`. The map's Notes conflated the two — `03`
should keep them apart.

Two things `03` must own, both verified from the `Dockerfile`:

- **No `HEALTHCHECK` exists**, and the gateway is *supervised* (auto-restarts).
  So a crash-looping gateway presents as a healthy container. We add our own probe.
- **`himalaya` is not in the image** ⇒ a derived image is required, which is also
  where the digest pin belongs.

### 4 — The pin and upgrade policy

**`:latest` is a trap and the docs walk you into it.** Verified in
`.github/workflows/docker.yml`: on main pushes CI tags both `:main` **and**
`:latest`; on releases it tags **only** the release tag. The registry confirms
`latest` == `main` by digest, distinct from `v2026.7.30`. Every compose example
in the upstream docs says `:latest` — following the quickstart verbatim puts
helium on unreviewed main HEAD.

Policy: pin by digest; upgrade quarterly or on a *named* need; never
`:latest`/`:main`/Watchtower. Pre-upgrade restic snapshot of `~/.hermes` **is**
the rollback plan, because the container runs non-interactive config-schema
migrations on boot and those don't roll back with the image. Verification after
upgrade is `hermes doctor` + `hermes cron list` + one forced `cron run` that must
**arrive on Telegram** — "container is up" proves nothing.

Cadence is worse than the map assumed: **six named releases in ~2 months**, and
v0.19.1 rolled up ~1,000 merged PRs in the *ten days* after v0.19.0. Reading the
delta is not feasible; time-in-the-wild is the only stability proxy we have.

### 5 — v0.14 defects

**Memory placement: the map's premise is verified.** Memory is files under
`~/.hermes/memories/`, sessions are SQLite at `~/.hermes/state.db`. Keeping the
brain out of the vault is the *default*, not something we engineer. One
correction: **`/journey` is CLI-only** — not available on messaging platforms, so
inspecting memory needs a shell into the container.

**Working-directory restructuring: a real mechanism now exists, and it's on by
default.** `HERMES_WRITE_SAFE_ROOT=/opt/data` is set in the official image, so
`write_file`/`patch` are hard-blocked outside the state volume — **the vault is
not writable by default; opening it is an explicit act.** Plus an always-on
protected-path denylist (`~/.ssh/`, `.env` anywhere, Hermes credential stores),
opt-in `checkpoints` (filesystem snapshots before destructive file ops), and
`approvals.deny` globs that block commands *unconditionally, even under
`--yolo`*.

But upstream is explicit that this is **not** a boundary: *"Write guards apply to
`write_file` and `patch` only. The `terminal` tool runs as the same OS user and
can still … overwrite denied paths via shell commands … it does not sandbox a
hostile or compromised agent."* The managed-scope doc lists *"a hard boundary
that the agent itself cannot escape"* as out of scope for v1.

⇒ **The container bind-mount is the only real write boundary** — the same
conclusion vault-serve `03` reached with `:ro` mounts. Inherited by `08`.

**Confabulation about its own internals: not answerable from docs, and I am not
inferring a fix.** The upstream issue tracker has zero hits for `confabulat`, so
there is no record to verify as closed. Routed to `05` as a working rule instead:
never ask the agent about its own state — read `hermes cron list`,
`hermes doctor`, `hermes logs`, and the files under `~/.hermes/`.

### 6 — BYO key vs Nous Portal

**BYO key stayed first-class.** Portal is *"the recommended way"* — recommended,
not required. 30+ providers configure by plain env var, `OPENROUTER_API_KEY`
among them: the exact titan setup is a supported configuration today. The
monetization shift did **not** narrow the self-host path, which retires that
durability worry. `cron.model` additionally routes unattended spend
independently of the interactive default.

---

## The finding that actually matters

**Does v0.19 remove v0.14's scaffolding, or rename it? Neither — it blesses it.**
`no_agent=True` makes the 122-line-gathering-script shape a *first-class
supported mode* and bolts loud failure onto it (*"non-zero exit or timeout → an
error alert is delivered, so a broken watchdog can't fail silently"*). That is
the right answer for reliability — determinate content should have no LLM in its
path — but plan for maintaining scripts, not for built-ins replacing them.

v0.19 does bring real fail-closed primitives that did not exist in the v0.14 era:
a **model/provider drift guard on by default** (an unpinned cron job whose global
default changed *skips the run, makes no inference call, and alerts you*);
*"failed jobs always deliver regardless of the `[SILENT]` marker"*; zero delivery
targets recorded as a delivery failure; and `display.file_mutation_verifier`,
documented as catching *"the 'batch of parallel patches, half silently fail,
model summarises success' class of over-claim."*

**And yet the verdict is conditional, because none of it closes the gap that
burned us.** Every primitive above catches **crashes, non-delivery, and failed
writes**. None catches **plausible-but-fabricated content**. The v0.14 fake
weather was hardcoded constants inside the gathering script: exit 0, non-empty
stdout, delivery succeeded. `no_agent` mode would have shipped it too.

So the engine choice is **not** the load-bearing decision on this map — the
verification story is. Ticket `05` must assert on *freshness of content*, from
outside hermes-agent's own cron. Two structural constraints bound how:

- Cron jobs run with the `cronjob`, `messaging`, and `clarify` toolsets
  **disabled** — the agent **cannot message you from inside a cron job**, and an
  approval escalation has nowhere to escalate to.
- Cron scripts get a **sanitized environment**: provider API keys and
  Hermes-managed secrets are *not* inherited, and scripts must resolve inside
  `$HERMES_HOME/scripts/`.

The engine's own troubleshooting guide documents six further silent-failure
paths (misformatted schedule "silently defaults to one-shot"; misconfigured
delivery target "silently drops the response"; unreadable `jobs.json` → "the
scheduler will fail silently"; lock contention → jobs "delayed or skipped"; any
response *containing* `[SILENT]`; and a `last_error` field upstream itself hedges
as *"(if available)"*). They are real but enumerable and mostly
configuration-time — which is why they inform `05` rather than sink the engine.

## Also corrected: the email half points at the wrong mechanism

There are **two** email paths, and the map's framing implies the wrong one. The
**Email gateway adapter** makes email a chat channel — it needs SMTP (broken on
Proton Bridge) and **at startup it marks every existing inbox message as
"seen"**. Aimed at the real personal inbox that silently marks the whole backlog
read. The triage path is the **bundled Himalaya skill** (installed by default,
explicitly *"separate from the Hermes Email gateway adapter"*), driving the
external `himalaya` CLI over IMAP — inspect/move/flag with no SMTP. Written into
`07`; the binary requirement is written into `03`.

## Graduated

`Model/provider choice under full egress` explicitly hung on this ticket and is
now specifiable — created as
[09 — Choose the inference provider under full egress](09-choose-inference-provider.md)
and cleared from the map's fog.

No ticket turned out to be mis-scoped; nothing ruled out of scope.
