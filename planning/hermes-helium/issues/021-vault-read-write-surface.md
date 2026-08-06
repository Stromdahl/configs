# 021 — The vault surface: read everything, write one directory

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [020](020-pull-mode-dm-only.md), and externally on `planning/vault-serve/issues/004`

## What to build

The thing that makes pull mode useful, and the boundary that makes the founding catastrophe
**structurally impossible** rather than merely forbidden: Hermes can read the whole vault and
write exactly one directory in it.

- **Whole vault mounted read-only; the inbox directory made writable by an overlapping
  read-write bind mount.** ⚠️ A read-only mount holds even against uid 0, but it enforces
  **location, not creation-only** — so it stops a reorganization, not clutter.
- ⚠️ **The service must verify its writable path exists and must never create it.** Docker
  root-creates a missing bind source, which silently yields a root-owned directory the agent
  cannot use.
- **Reading separates permission from cost**: mount everything read-only (free), but
  always-load only the measured ~16 300-token surface. 🔴 **Never hand the agent the raw board
  file** — its top section alone is ~16 700 characters of largely superseded reasoning.
- **Captured notes follow the vault's existing one-file-per-note convention**, tagged with
  Hermes as the source, so the same drain already handles them.
- **The agent's own memory stays on its state volume, never in the vault.** The vault is a data
  source it reads and files into — never its brain. That is what ended attempt four: the last
  Hermes reorganized the vault, deleted a sync marker, and stalled Syncthing with badly
  diverged sides.

⚠️ **External blocker: the Send-Receive vault replica** (`planning/vault-serve/issues/004`).
That ticket also owns the vault's **only undo** — staggered Syncthing versioning on krypton,
whose retention field is **in seconds**, so the human-friendly number yields six minutes of
history while looking configured. Do not build this ticket against a replica without it.
Note also that versioning fires on **replace and delete, never on create**, so the
creation-shaped write surface has no one-click undo — clutter, not loss.

## Acceptance criteria

- [ ] From the phone, a question about the board gets an answer drawn from the real vault.
- [ ] From the phone, "capture this" produces one new note file in the vault inbox, in the
      existing naming convention, tagged as Hermes-sourced, and it reaches krypton.
- [ ] A write attempt **anywhere else in the vault fails**, including as uid 0.
- [ ] The service refuses to start rather than creating a missing writable path.
- [ ] The always-loaded context is **measured** and recorded, and the raw board file is not
      part of it.
- [ ] The agent's memory lives on the state volume; nothing agent-authored appears outside the
      vault inbox.
- [ ] The replica's versioning is confirmed live by a round trip — edit on helium, prior version
      appears on krypton — with the retention value verified in **seconds**.

## Blocked by

- [020 — Pull mode](020-pull-mode-dm-only.md) — the demo for this ticket *is* a DM exchange.
- **External:** `planning/vault-serve/issues/004` — the Send-Receive replica and its versioning.
