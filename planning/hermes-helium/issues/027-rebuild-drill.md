# 027 — The rebuild drill: working, and amnesiac

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [026](026-alarms-and-write-audit.md)

## What to build

Not code — **a rehearsal**, done once and written down. The argument is `03`'s: an unrestored backup
is not a backup.

**Rebuild is split by authorship** — human-authored configuration from git, agent-accumulated memory
from restic — and the falsifiable test that proves the split is honest:

> **A rebuild from git plus the age key must yield a working but *amnesiac* Hermes.**

Working, because everything a human authored is in version control and decrypts with the key.
Amnesiac, because the agent's accumulated memory is *not* in git — so if the rebuilt instance
remembers anything, some agent state was living somewhere it shouldn't, and if it *doesn't work*,
some human-authored config was never committed. Both failure directions are informative, which is
what makes this a test rather than a ceremony.

Then restore memory from restic and confirm it comes back. ⚠️ **The restore verb is the engine's
import command**, not the obvious name — `05` had to check.

⚠️ **One thing the drill will not cover, by design:** the BotFather join-groups setting is invisible
to ansible and therefore to this drill. That is exactly why `020` does not lean on it — the group
block is an environment variable that *does* travel. If the drill ever appears to prove group safety,
it is proving something it cannot see.

## Acceptance criteria

- [ ] A rebuild from git plus the age key produces a **working** Hermes: healthy container, a DM
      answered, a brief delivered.
- [ ] That rebuilt Hermes is **amnesiac** — it remembers nothing from before.
- [ ] Restoring from restic returns its memory, using the engine's import verb.
- [ ] Anything found missing from git during the drill is **committed**, and anything found in git
      that shouldn't be is removed — the drill's real output is that list.
- [ ] The drill's steps and result are recorded here so the next rebuild is a re-run, not a
      rediscovery.
- [ ] It is noted that the drill does not and cannot verify BotFather state.

## Blocked by

- [026 — Alarms and the write audit](026-alarms-and-write-audit.md) — drill the finished system, so
  the rebuild proves the whole thing rather than a subset.
