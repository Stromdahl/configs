# lumin's definition of done, once the deep tier is remote

Type: grilling
Status: open
Blocked by: 02, 04

## Question

The CI split is decided: **fast tier local (`just check`), deep tier on CI, on
push, asynchronously.** That decision has a consequence the owner flagged but has
not yet resolved — it **breaks lumin's own spec**.

`lumin/.scratch/qa-pipeline/spec.md` states two principles that now conflict with
the plan:

- **"One entry point."** *"`just qa` runs every gate and is the definition of done.
  No git hooks, no Claude Code hooks — enforcement is the entry point plus
  `AGENTS.md` rules."* Under the new split, done means "`just check` green locally
  **and** the CI verdict green" — two places to look, and an agent that runs
  `just qa` locally is now doing work it was meant to offload.
- **"Blessing is human."** Goldens and perf Ceilings regenerate only on explicit
  human request, and a bless run never reports green. Blessing on a remote runner
  is a different act than blessing on the laptop.

Decide, with ticket 02's measurements in hand (especially whether callgrind
Ceilings survive the move to an i5-9400, and whether the smoke gate can run
headless at all):

1. **What is the new definition of done**, stated as precisely as the current spec
   states its own? Does `just qa` remain runnable locally as an escape hatch, and
   if so what is it *for*?
2. **Which gates actually move?** All six deep gates, or does anything stay local
   because CI cannot host it (candidate: the smoke gate) or because its results are
   host-dependent (candidate: the perf gate)?
3. **Where do Ceilings and Goldens get anchored** — laptop or runner? If both must
   agree and they cannot, one of them stops being authoritative; say which.
4. **How does an agent know?** `lumin/AGENTS.md` currently encodes the rule that
   `just qa` green is the gate. What replaces that instruction, and how does an
   agent working on lumin wait for or read a remote verdict?
5. **Does the spec get amended, and by whom?** This is a change to lumin's locked
   QA spec — it needs a version bump / amendment note, not a silent drift.

Output: the amended definition of done, precise enough to edit into lumin's spec
and `AGENTS.md` as a follow-on execution issue.
