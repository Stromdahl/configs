# 018 — Recover the prior-art config, per the verdict table

Type: execution
Status: resolved
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: none — can start immediately

## What to build

The ~740 lines of already-debugged configuration from the last working Hermes, back in the
repo — **selectively**, and without importing the four defects that came with them. This is
the prefactor: make the change easy before making it.

⚠️ **Do not merge the old briefings branch.** Its tip is an **ancestor of `main`**, so the
merge is a **no-op** and will look like success. Recover with a checkout from the commit
**immediately before the deletion**, which is also one commit richer than the branch itself.

⚠️ **Read ticket `02`'s verdict table before recovering any file.** Of 21 files exactly
**one is a straight keep**, four adapt, and the rest are stale or **actively harmful**.
Recovering the set wholesale imports all four defects — the worst being *"send the briefing
to Telegram"* written into prompt text, which is unexecutable (scheduled jobs have messaging
disabled) **and** invites a silent non-delivery.

What comes back:

- **The agent identity file — the one straight keep.** Its 18 lines carry the **two
  anti-fabrication rules that no engine primitive enforces**, which makes it the only
  standing defence against the fake-weather class. Later tickets assert on its **content**,
  because the built-in doctor command reports it present against the image's own 513-byte
  default and **exits 0 with failures printed**.
- **Four files that adapt**, for their **shape, not their sections**: the per-source
  `STATUS=OK/ERROR` contract, verbatim passthrough, date arithmetic in the script rather than
  the prompt, and reading credentials from an environment file (accidentally correct, given
  the scheduler's sanitized environment).

What stays deleted: every emitter (calendar and news are out of scope; the dose emitter is
built fresh in `024` against ticket `13`'s machine-readable block), the three-tier memory
scaffolding (superseded by the engine's own persistent memory), and both old dotfiles
modules (helium is ansible-only).

Nothing deploys in this ticket. It ends with the material in the repo, ready for `019`.

## Acceptance criteria

- [x] The identity file is in the repo, its two anti-fabrication rules intact and readable.
- [x] The four adapt-verdict files are in the repo, with each one's carried-forward *shape*
      noted and its stale sections stripped.
- [x] No discard-verdict file was recovered.
- [x] No prompt text anywhere instructs the agent to send a message.
- [x] The recovery command used is recorded here, so the provenance of these files is
      re-derivable.
- [x] `git log` shows the recovery as a normal commit — no merge of the old branch.

## Blocked by

- None — can start immediately.

## Resolution

**Resolved 2026-08-07.** Five files recovered, all under
`ansible/roles/compose_stack/files/hermes-agent/`, plus a `README.md` there recording what
ships and what doesn't. Nothing was deployed and no ansible task references any of it —
`tasks/stack.yml` is untouched, so every recovered file is inert until `019`/`023` copies it.

### The recovery command

```sh
git show 4ed7e63^:configs/hermes-agent/SOUL.md \
  > ansible/roles/compose_stack/files/hermes-agent/SOUL.md
for f in morning_briefing.sh weekly_briefing.sh \
         morning-briefing.prompt.md weekly-briefing.prompt.txt; do
  git show "4ed7e63^:configs/hermes-agent/$f" \
    > "ansible/roles/compose_stack/files/hermes-agent/prior-art/$f"
done
```

`git show … >` rather than `git checkout 4ed7e63^ -- <path>`, because the files are being
**relocated** — a checkout would restore them to the dead `configs/hermes-agent/` path, which
is the dotfiles-module convention helium does not use. `4ed7e63^` is `02a04e6`, the commit
immediately before the deletion and one commit richer than `abb62a6`; the old
`hermes/briefings` branch was never touched, and `git log` shows one ordinary commit.

### Where it landed, and why there

`03` settled it: gathering scripts are `ansible.builtin.copy`'d **from the role's `files/`**
to `/data/ssd/appdata/hermes/scripts/`, and the build context goes to
`{{ compose_stack_dir }}/build/hermes-agent/` — the `protonmail-bridge` pattern verbatim
(`files/protonmail-bridge/` → `build/protonmail-bridge/`). So `files/hermes-agent/` is the
name `019` will already be reaching for. `019` adds `Dockerfile` and the healthcheck as
siblings of `SOUL.md`; `023` promotes a descendant of `prior-art/morning_briefing.sh` into a
`scripts/` sibling.

`prior-art/` is the marker for the four that do not ship. The "disabled-but-present" hazard
does not apply: helium has no opt-in list to comment out, so a file here is inert rather than
half-wired.

### What came back

| File | Verdict | Treatment |
|---|---|---|
| `SOUL.md` | KEEP AS-IS | **Byte-identical**, verified by `git show … \| diff -`. |
| `prior-art/morning_briefing.sh` | ADAPT | All five emitters stripped; header names the four carried-forward shapes; one sourceless emitter skeleton shows the contract. |
| `prior-art/weekly_briefing.sh` | ADAPT, low value | All three emitters stripped. Header states outright that `06` did not adopt a weekly cadence, so nobody schedules it. |
| `prior-art/morning-briefing.prompt.md` | ADAPT | Defect ① removed (see below); calendar/weather/news/labs/medication rules and the whole titan deployment checklist stripped. |
| `prior-art/weekly-briefing.prompt.txt` | ADAPT | Same. Carries the two rules the daily prompt lacks: summarise per commitment, and a range BLUF. |

`morning-briefing.prompt.txt` was **not** recovered — `02` #5, keep one of the pair, the pair
was itself a drift source.

### Defect ① is gone, and the grep is the evidence

`grep -rniE "send|deliver|telegram"` over the recovered tree returns no instruction to send
anything. Every hit is either prose *about* the deletion (which is the point — the annotation
is what stops it coming back) or the surviving `FORMAT (Telegram — it does NOT render
markdown headers)` line, a rendering constraint rather than a delivery instruction. Both
prompts carried the instruction **twice**, not once: an opening *"Deliver Mattias's … briefing
to Telegram"* as well as the closing *"Then send the finished briefing…"* that `02` named.
Both copies are gone from both files.

### Three things recorded rather than applied

1. **The `count=0` → OMIT rule is superseded, and it is still in the surviving prompt text**
   — annotated `[see correction above]` in both prompts rather than silently rewritten,
   because the text is prior art, not a draft. `023` owns the replacement: a section may
   collapse **iff** its source can distinguish *empty* from *exhausted*. Defect ② is that
   rule eating a health source, so passing it through unmarked would have re-imported the
   defect this ticket exists to keep out.
2. **The `preferences.md` register conflict, resolved for `019`.** `02` §12–16 flagged *"dry
   wit welcome"* against `SOUL.md`'s *no filler, no exclamation marks* as "a conflict to
   resolve when installing SOUL.md" — that install is `019`. **`SOUL.md` wins as written**:
   `preferences.md` was an unfilled template, never deployed, and discarded, so it carries no
   authority. Recorded in the role README so `019` inherits a position instead of
   rediscovering the question.
3. **The marker guard (`02` #7–9) was deliberately not recovered.** Its verdict is ADAPT, not
   discard, so a future reader diffing `4ed7e63^` against the repo will notice three
   adapt-verdict files missing: ownership sits with vault-serve `004`, which already names
   this prior art and its required changes, and `02` says explicitly not to open a
   hermes-helium ticket for it.

### One loose end for the owner — `02` row 10's surviving comment

`env.example` is DISCARD-values / **keep one comment**, and that comment is a decision already
made: *prepaid credits only, auto-recharge OFF — the worst case is "Hermes stops working", not
"I wake up to a $400 bill".* `02` assigned it to `09`, but `09` resolved with a token-ceiling
mechanism and no account-level policy, and `016` says only "billing configured". Since the
file stays deleted, the prose is preserved here — it belongs in `016`'s acceptance criteria,
which is a one-line edit to a `needs-human` ticket the owner is going to open anyway.

### Verification

`bash -n` passes on both scripts (this repo has no test runner, no linter and no shellcheck
on the box; `install.sh --dry-run` does not reach an ansible role, and the spec's test seams
belong to `023` onward). Both `.sh` files are mode 644, not 755, deliberately: they are shapes
with a sourceless emitter, not runnable scripts.
