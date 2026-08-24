# Do the personal wayfinder maps in `~/vault` move to Forgejo?

Type: grilling
Status: resolved
Blocked by: 07, 11
Assignee: claude (session 2026-08-24a)

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

---

## Answer (resolved 2026-08-24)

**B for all five. C skipped for now.** The owner's decision, unqualified:
*"B for all five, and skip C for now."*

### The decision, per option

- **A — move to Forgejo: rejected.** Not on taste, on measurement. The vault's
  tickets are woven into live vault content that is not moving: **16 `[[tasks]]`
  wikilinks** into `~/vault/tasks.md` (the daily task board), **12 into `health/`**
  (training log, program, npf), and **~25 relative links** into sibling
  `../research/`, `../design/`, `../food-log.md`. Forgejo resolves none of these.
  Moving `tickets/` alone would split all five efforts across two systems while
  `research/`, `design/`, `food-log.md`, `photos/` and the health log stayed behind.
  [Ticket 07](07-tracker-cutover.md) accepted relative-link breakage as *"the one
  regression with no workaround"* — but there it hit **assets**; here it hits the
  **tickets** and points at content that cannot follow.
- **B — stay markdown in the vault: adopted, for all five** (`diy-speakers`,
  `finance-rebuild`, `not-so-smart-smartwatch`, `strength-and-weight`,
  `vardepapperskredit`), including `vardepapperskredit` despite its real mortgage
  and debt-collection figures — B **is** the status quo for those, so it introduces
  no new exposure. B is also **free**: `bin/wf` already spans `~/.dotfiles/planning`
  and `~/vault/projects` in one view, so the cross-project reach that A was supposed
  to buy is already delivered today (see P3).
- **C — give the vault a Forgejo remote: declined for now.** A real gap, but a
  different question from tracking, and it overturns a **recorded** decision
  (`projects/vault-tools/decisions.md` **D7**) rather than merely adding a remote.
  Not ruled wrong — ruled *not now*, and out of this map's scope. Premises banked
  below so it is cheap to reopen.

### Scoping statement (the ticket's required output)

[Ticket 07](07-tracker-cutover.md)'s **"everything moves, maps included" is scoped
to `~/.dotfiles`** — the repo it surveyed. It does **not** reach `~/vault`. The two
decisions do not contradict: 07 moved a tracker that lived in a git repo whose
sibling content was moving with it; 13 kept a tracker whose sibling content is a
personal knowledge base that is staying put. The discriminator is **whether the
tickets' outbound links have anywhere to land**, not public-vs-private and not
markdown-vs-service.

So after the migration there are **two** personal ticket homes by design:
Forgejo Issues for the 20 curated repos and `~/.dotfiles`, markdown-in-vault for
the five vault maps. `bin/wf` remains the thing that spans them, and its planned
**Forgejo dialect is a third dialect, not a replacement** — the frontmatter dialect
must be kept, because the vault is still its user.

### Premise checks — all three moved

Full evidence and commands:
[`../assets/13-vault-premise-checks.md`](../assets/13-vault-premise-checks.md).

1. **The Syncthing/git hazard is VOID, not mitigated.** `~/vault/.stignore`
   excludes `.git` outright — *"keeps history on krypton only"* — so the replicated
   `.git` the ticket feared has never existed. Peer list also corrected: **titan is
   gone, helium is the third peer** (krypton ↔ helium ↔ phone), holding a working
   tree at `/data/ssd/vault`. The vault additionally runs three live git worktrees
   under the (also Syncthing-excluded) `.claude/`.
2. **The sensitivity question was mis-aimed and is largely moot.** `finance-rebuild`
   is *not* the sharp one — `.gitignore` fences `finance/` (engine + DB + reports),
   not `projects/finance-rebuild/`. The sharp content is **`vardepapperskredit`**
   (1 045 250 kr debt / 1 690 000 kr valuation / 62% LTV; `debt_collection`
   19 614 kr across 14 events) and **`strength-and-weight`** (~106 kg plus
   long-term steroid **treatment history** — special-category health data). Both are
   **already tracked in git**. And "should it sit in a service at all" is spent:
   `planning/vault-serve/` already decided the **whole vault physically sits on
   helium**, finance and health included, *"not a new sensitivity class"*. What is
   genuinely new under any Forgejo option is **history + a remote**, which is
   precisely what D7 forbids.
3. **`bin/wf` is owed nothing.** It already supports both layouts (`issues/` and
   `tickets/`) and both dialects (prose and YAML frontmatter), auto-detected per
   file, with `~/vault/projects` already a first-class root — plus a fourth root
   `~/notes/.scratch` (the **work** vault, out of scope) that also uses the prose
   dialect, so retiring a dialect was never a clean win either.

### Banked for whoever reopens C

C's cost was **measured down**, so reopening is cheap:

- The single-copy gap is real and is about **history, not files**: the working tree
  has 3 copies, the git history has **exactly one** — 313 commits / 14 MB on
  krypton. helium's restic does **not** cover it: `restic-backup.service` walks
  `/data/ssd/appdata`, the vault replica is a *different* subvolume, and only
  `restic-backup`, `restic-immich` and `restic-paperless` units exist.
- The secret audit the `.gitignore` header demands is **small**: across all 313
  commits, **12 files** ever mention anything credential-shaped, and **no `.env`,
  key, DB, CSV or XLSX ever entered history** at all (342 distinct paths ever
  added). It is an eyeball pass, not a forensic project.
- A **bare mirror over the mesh** is the plainer competitor to a Forgejo remote and
  should be weighed against it — both still require reopening D7.
- Layout caveat for any future tooling: **11 project dirs, only 5 with `tickets/` +
  `map.md`**; the other six (`3d-printing`, `homelab`, `msbrain`, `next-daily-car`,
  `vault-split`, `vault-tools`) have neither, and `projects/` also holds loose
  single-file notes (`retirement.md`, `laptop-search.md`, `smoothie-test.md`, …).
  Nothing may assume the layout.

### Named cost

The vault's 313 commits of LLM-edit audit trail stay **single-copy on krypton** —
knowingly. A disk failure loses the history (not the notes, which Syncthing
replicates three ways). That was true before this ticket and is unchanged by it;
what is new is that it is now a **recorded acceptance** rather than an oversight.
