# 018 — Recover the prior-art config, per the verdict table

Type: execution
Status: open
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

- [ ] The identity file is in the repo, its two anti-fabrication rules intact and readable.
- [ ] The four adapt-verdict files are in the repo, with each one's carried-forward *shape*
      noted and its stale sections stripped.
- [ ] No discard-verdict file was recovered.
- [ ] No prompt text anywhere instructs the agent to send a message.
- [ ] The recovery command used is recorded here, so the provenance of these files is
      re-derivable.
- [ ] `git log` shows the recovery as a normal commit — no merge of the old branch.

## Blocked by

- None — can start immediately.
