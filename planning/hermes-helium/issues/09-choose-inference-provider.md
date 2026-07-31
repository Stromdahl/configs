# Choose the inference provider under full egress

Type: grilling
Status: open
Blocked by: 01

## Question

Egress is settled: **full egress, accepted deliberately** (map Notes). helium has
no GPU and a local LLM is an explicit PRD non-goal, so vault contents —
`finance/`, `health/`, `journal/`, `people/`, the live `tasks.md` board — and the
Proton inbox stream to a third-party inference endpoint continuously and
unattended. **The map's own Notes say provider choice "therefore carries the
weight."** This ticket carries it.

**Which provider, on what retention and no-training posture, reached how?**

### Why this is now answerable

It was fog until ticket `01` resolved, because a non-hermes-agent engine would
have changed the option set entirely. `01` settled that, and settled two things
that shape this ticket (see
[assets/01-engine-research.md](../assets/01-engine-research.md) §8):

- **Bring-your-own-key stayed first-class.** Nous Portal is *"the recommended
  way"* — recommended, not required. 30+ providers configure by plain env var in
  `~/.hermes/.env`, `OPENROUTER_API_KEY` among them, which is the exact titan
  setup. So this is a genuinely open choice, not a Portal-or-nothing one.
- **Unattended spend is separately routable.** `cron.model` routes cron jobs
  independently of the interactive default, and the drift guard fails a cron job
  *closed* rather than let it silently inherit a switch to a paid provider/model.
  So the push path and the pull path may legitimately use different providers.

### What makes this non-obvious

- **Data posture is the whole point, and it is per-provider, not per-key.**
  OpenRouter is a *router*: it forwards to upstream labs whose retention and
  training policies differ, and the effective policy is the *downstream* one, not
  OpenRouter's. Nous Portal is likewise documented as routing per-model to
  varying backends, and *"the routing for a given model can change over time."*
  A posture that depends on which backend served a request is not a posture.
  Going direct to one lab trades that away for a single, checkable policy.
- **The old setup was openrouter + BYO key.** Sunk knowledge argues for it, the
  routing opacity argues against it. This ticket has no incumbent-wins-ties rule
  — that rule was scoped to `01`.
- **Two modes, two cost shapes.** Pull is bursty and latency-sensitive; push is a
  predictable handful of scheduled runs per day, each potentially long. A
  subscription and a metered key price those very differently.
- **Failure behaviour matters more than price.** An unattended provider outage
  must be loud, not silent — this couples to `05`. What does hermes-agent's
  fallback-provider chain do to the *verification* story, and does a fallback
  hop silently change the retention posture the whole decision rested on?
- **Egress is accepted, not unbounded.** "Full egress" settled that we won't
  maintain a read include-list. It did not settle whether some things (the
  Kronofogden mail, `health/`) get a *different* provider than the rest, or
  whether that distinction is theatre for the same reason the read include-list
  was.

### What the answer must contain

1. **The provider (or providers) chosen**, and whether pull and push share one.
2. **The retention / no-training posture actually obtained**, and the mechanism —
   a published policy, an account setting, a contractual term. Name where it is
   checked, so it can be re-checked later.
3. **How routing opacity is handled** if a router or the Portal is chosen: either
   pinned single-backend models, or an explicit acceptance that the effective
   posture varies per request.
4. **Credential shape and placement** — BYO key vs OAuth vs subscription; and
   where the secret lives given the repo's sops+age convention and the fact that
   `~/.hermes/.env` is on the state volume, not in git.
5. **Fallback-provider policy**, and what a fallback hop does to (a) the
   retention posture and (b) `05`'s verification story.
6. **A cost sanity-check** at the expected push cadence, enough to notice if an
   unattended job starts running away.

`/grilling` + `/domain-modeling`. **HITL** — never answer the owner's side of it.
