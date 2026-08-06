# 026 — Alarms and the write audit: nothing fails quietly

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [025](025-email-triage.md)

## What to build

The trust half made real: **alarms that fire on absence**, an audit trail the agent cannot author,
and a cost tripwire. Everything here rides the **existing MQTT→Home-Assistant path** — no metrics
collector and no dashboard, because standing one up to watch the watchman is one more thing that can
fail silently.

**Three liveness alarms, none of which travels via the brief:**

- **The brief didn't arrive.** Silence is the alarm only if something other than the brief can say
  so. ⚠️ This alarm and the two-hour grace are a **matched pair** — grace covers a short outage, the
  alarm covers everything longer. Don't "fix" one without the other.
- **The Telegram transport is dead while the container lives.** 🔴 A rejected or revoked token leaves
  the gateway **up and running scheduled jobs** by upstream design, so cron-liveness reports healthy
  while pull mode is dead — and the dead channel **cannot report its own death over itself**. One
  assertion on the healthcheck, no new job.
- **The scheduler has never had a successful run** — `019`'s healthcheck fix, surfaced as an alarm.

⚠️ **Key the alarm on the container-**state** entity, not the health entity** — verified in the
existing metrics work: **the health entity does not clear when a container stops**.

**The write audit.** A script-generated **filesystem manifest diff of the writable directory**,
printed in the brief **beside** the agent's own prose, so a claim with no matching write is visibly
contradicted. 🔴 This replaced enumerating writes from the agent's logs, which `08` measured as
impossible: a successful write produces **zero** log mentions — only failures are logged, the
executor logs the tool name and never its arguments, and the sole path-level record is in-memory and
dies with the process. The manifest diff is strictly stronger: mechanism-agnostic, **deletion-aware**,
unfabricatable, and complete *because* the write surface is narrow. **Do not add a second
write-audit mechanism beside it.**

**The cost tripwire.** ⚠️ It cannot ride the footer as a same-run check — a pre-run script executes
**before the session id exists**, so a gathering script can only ever report the **previous** run. So:
a trailing footer line for routine visibility, and a **separate post-brief script job** as the
tripwire against the token ceiling recorded in `016`. Provider, model and cost come from the state
database's **per-session usage table** (the executions table has no provider column at all); resolve
the session **by recency, never by reconstruction**. ⚠️ A metric worth noting if a collector ever
arrives: each is emitted **only when non-null**, so "never succeeded" is an **absent** metric, not a
zero — alert on absence or not at all.

## Acceptance criteria

- [ ] A suppressed brief raises a Home Assistant alarm that **did not travel via the brief**.
- [ ] A revoked Telegram token raises an alarm **while the container is still running and healthy by
      cron-liveness alone**.
- [ ] A never-succeeded scheduler raises an alarm.
- [ ] Alarms key on the container **state** entity, demonstrated by stopping the container.
- [ ] A short outage inside the grace window does **not** alarm; a longer one does.
- [ ] The brief carries a script-generated write list for the run, and a deliberately false agent
      claim about a change is visibly contradicted by it.
- [ ] The write list catches a **deletion**, not just a creation.
- [ ] The footer shows the previous run's cost, and the ceiling breach fires the separate alarm job.
- [ ] The provider and model for a given run are recoverable from the usage table, resolved by
      recency.

## Blocked by

- [025 — Email triage](025-email-triage.md) — the last source lands first, so the alarms guard the
  finished brief rather than a moving target.
