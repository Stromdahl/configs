# Do the personal wayfinder maps in `~/vault` move to Forgejo?

Type: grilling
Status: open
Blocked by: 07, 11

## Question

Graduated from the fog 2026-08-24, on its own stated trigger — *"sharpen into a ticket
once the migration's shape is concrete"* — which [ticket 07](07-tracker-cutover.md)
made concrete (everything moves; assets to a private `projects/planning` git repo;
vocabulary open/claimed/done/dropped; `bin/wf` gains a Forgejo dialect).

[Ticket 07](07-tracker-cutover.md) decided **"everything moves, maps included"** on the
evidence of `~/.dotfiles/planning/` plus the eight repo `issues/` dirs. It never saw
these. They are **personal**, so the work carve-out does not cover them, and
`diy-speakers` is one of [ticket 06](06-repo-curation.md)'s twenty curated repos — so
07's argument reaches them by its own logic, which is exactly why this needs deciding
rather than assuming.

**Measured 2026-08-24 — and two of the fog entry's premises were wrong:**

```
$ for d in ~/vault/projects/*/; do echo "$(basename $d): $(ls $d/tickets/*.md 2>/dev/null | wc -l)"; done
diy-speakers: 6        finance-rebuild: 10        not-so-smart-smartwatch: 17
strength-and-weight: 11    vardepapperskredit: 6      (+ 6 dirs with no tickets/)
$ ls ~/vault/projects/*/tickets/*.md | wc -l
50
$ git -C ~/vault rev-parse --is-inside-work-tree   -> true
$ git -C ~/vault remote -v                         -> (empty)
```

1. **`~/vault` IS a git repo** — the fog entry asserted these maps "live in the
   Syncthing-replicated vault, **not** in a git repo". False. It is a real git repo
   with real history (`29bc559 recipes: …`), just with **no remote at all**. That
   removes one of the two reasons this looked hard, and it opens a third option the fog
   could not see (below).
2. **The ticket dir is `tickets/`, not `issues/`**, and there are **11 project dirs but
   only 5 with tickets** — the other six (`3d-printing`, `homelab`, `msbrain`,
   `next-daily-car`, `vault-split`, `vault-tools`) have no `tickets/` and no `map.md`,
   so `bin/wf`'s dialect and any migration script must not assume the layout.

The count itself (50 tickets across 5 maps) was right.

### The three options

- **A. They move to Forgejo**, like everything else 07 decided. Consistent, one tracker,
  the dashboard's cross-project view actually spans everything. Cost: they leave the
  vault, so they stop being readable/editable offline in the vault's own tooling and
  stop riding Syncthing to other devices — and one of them (`finance-rebuild`) is
  financial, which is an argument about where it lives, not just how it is tracked.
- **B. They stay markdown in the vault.** The exact hybrid 07 was offered and declined
  — but declined for `~/.dotfiles`, where the repo was already git-with-a-remote. The
  argument may not transfer.
- **C. The vault gets a Forgejo remote** — a private repo it pushes to, which it
  currently lacks entirely. The maps stay markdown and stay in the vault; the forge
  becomes the vault's backup/remote rather than its tracker. This is **new**, only
  visible once premise 1 was checked, and it addresses a real gap (a git repo with no
  remote) rather than only the tracking question.

### What to establish before/while deciding

1. **Does pushing a Syncthing-replicated git repo to a remote create a hazard?** The
   `project_hermes_vault_sync` memory records that an agent deleting `.stfolder` during
   a reorg silently halted sync, and that krypton↔titan needed a marker-guard. A `.git`
   replicated by Syncthing across two machines that both commit is a known-bad shape
   (index/lock races). This bears on **C** specifically, and it is a fact, not a
   preference — check it before the conversation, not during.
2. **Is `finance-rebuild` different in kind?** Forgejo is mesh-only and private, so
   "private" is not the discriminator. The real question is whether its content should
   sit in a service at all versus a vault file.
3. **What does `bin/wf` do today** across the two layouts (`issues/` vs `tickets/`), and
   what would each option cost it — since 07 already committed it to gaining a Forgejo
   dialect.

Output: a decision per option, and — if anything stays markdown — an explicit statement
that 07's "everything moves" is scoped to `~/.dotfiles`, so the next session does not
read the two decisions as contradicting each other.
