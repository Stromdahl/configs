# hermes-agent — role material

Source material for the Hermes container on helium
([spec 015](../../../../../planning/hermes-helium/issues/015-spec-hermes-on-helium.md)).
Recovered here by [ticket 018](../../../../../planning/hermes-helium/issues/018-recover-prior-art-config.md);
[ticket 019](../../../../../planning/hermes-helium/issues/019-service-boots-healthy.md) is
what first copies any of it onto helium.

| Path | Ships? | What it is |
|---|---|---|
| `SOUL.md` | **yes**, → `~/.hermes/SOUL.md` on the state volume | The agent identity file. |
| `prior-art/` | **no** | Recovered v0.14 shapes, stripped. Reference for `022`–`024`. |

Nothing in this directory is wired into `tasks/stack.yml` yet — `018` deployed nothing. A
file here is inert until a task copies it, which is why the unshipped material can sit
beside the shipped material safely.

⚠️ **That safety rests on copying named files, never the directory.** This is the first
`files/` subdir in this role to hold anything that must not ship; the existing tasks all
name a single file (`src: protonmail-bridge/Dockerfile`), so the pattern `019` inherits is
already the right one — but nothing enforces it. A recursive copy of this directory would
put this README and `prior-art/` on helium.

## `SOUL.md` — do not edit casually

18 lines, recovered **byte-identical** and deliberately so. It carries the **two
anti-fabrication rules that no engine primitive enforces** ("say so plainly when a source
failed"; "only state what you can verify"), which makes it the only standing defence against
the fake-weather class — ticket `01` measured the drift guard, failed-jobs-always-deliver and
the mutation verifier all missing plausible-but-fabricated content.

So `019` asserts on its **content**, not its existence: the built-in doctor command reports
the file present against the image's own 513-byte default, and **exits 0 with failures
printed**. Reflowing or rewording this file breaks the assertion that is doing the work.

**One conflict, resolved here so `019` inherits a position rather than rediscovering the
question.** The discarded `vault-skeleton/System/Assistant/preferences.md` carried a register
of its own — *"Concise, direct. Dry wit welcome. Never sycophantic"* — which contradicts
`SOUL.md`'s *no filler, no exclamation marks*. **`SOUL.md` wins as written.** `preferences.md`
was an unfilled template that was never deployed, and it is discarded, so it carries no
authority; there is nothing to merge and no second file to install.

## `prior-art/`

Four files, each stripped to the shape it carries forward and annotated with what was
removed and why. Read `prior-art/morning_briefing.sh` first — the other three are variations
on its contract. The four things worth having are the per-source `STATUS=OK/ERROR` contract,
`<verbatim>` passthrough, all date math in the script rather than the model, and reading
credentials from the env file rather than inheriting them.

⚠️ **No prompt in this deployment may instruct the agent to send a message.** Scheduled jobs
run with the messaging toolset disabled, so such an instruction is unexecutable *and* invites
"the agent reports it sent the brief and nothing arrives". Delivery is job configuration. The
recovered prompts each carried that line twice; both copies are gone and the annotations say
so, because the deletion is the point.
