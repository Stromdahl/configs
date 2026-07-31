# Choose the engine and land a version-pinning policy

Type: research
Status: open

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
