# Decide the concrete vault read/write surface

Type: grilling
Status: open
Blocked by: 03, 07

## Question

The posture is settled — **Send-Receive, narrow write surface, Hermes' memory out
of the vault** (map Notes). **Now make "narrow" concrete:** exactly which paths may
Hermes write, how are conflicts and git history used as the safety net, and how is
the boundary enforced rather than merely intended?

### Inherited from ticket `01` (verified 2026-07-31 — don't re-derive)

From [assets/01-engine-research.md](../assets/01-engine-research.md) §5. The engine
now ships a real write-confinement mechanism — and upstream is explicit that it is
**not** a boundary.

- **`HERMES_WRITE_SAFE_ROOT=/opt/data` is set in the official image.** So
  `write_file` and `patch` are *hard-blocked* outside the state volume — not routed
  through approval. **The vault is therefore not writable by default; opening it is
  an explicit act** (adding paths to a `:`-separated safe root). That inverts the
  v0.14 posture, where the vault *was* the working directory. Item 2's "capability,
  not motive" now starts from deny.
- An always-on protected-path denylist applies regardless: `~/.ssh/`, `~/.aws/`,
  `~/.netrc`, Hermes credential stores, and `.env` / `.envrc` **anywhere on disk**.
- **But the terminal tool escapes all of it.** Upstream: *"Write guards apply to
  `write_file` and `patch` only. The `terminal` tool runs as the same OS user and
  can still … overwrite denied paths via shell commands … it does not sandbox a
  hostile or compromised agent."* The managed-scope doc likewise lists *"a hard
  boundary that the agent itself cannot escape"* as out of scope for v1.
- **⇒ The container bind-mount is the only real boundary** — the same conclusion
  vault-serve `03` reached with per-folder `:ro` mounts. Treat
  `HERMES_WRITE_SAFE_ROOT` as defence-in-depth layered on top, and answer item 6's
  "enforced rather than intended" at the mount layer.
- **Two extra levers worth considering here:** `checkpoints` (filesystem snapshots
  before destructive file operations — opt-in, `enabled: false` by default, 20 per
  directory) composes with `~/vault` already being a git repo; and `approvals.deny`
  is a glob list that blocks matching terminal commands **unconditionally, even
  under `--yolo` or `approvals.mode: off`** — the only hard lever against the
  terminal escape hatch, and the only one that works unattended (a `smart`-mode
  escalation cannot reach a human from inside a cron job).
- Memory placement needs no work: memory is files under `~/.hermes/memories/` and
  sessions are SQLite at `~/.hermes/state.db`. Brain-out-of-vault is the default.

### Inherited from ticket `04` (verified 2026-07-31 — don't re-derive)

Send-Receive was applied to `vault-serve` 004, and checking the Syncthing docs
turned up the fact this ticket most needs: **local deletions propagate upstream.**
`Send-Receive` distributes local changes *including deletions* to every peer;
`Receive Only` did not. So a Hermes reorg or delete on helium's copy destroys the
same files on **krypton and the phone** — the blast radius of item 2's
"capability, not motive" is the whole cluster, not one replica. Two corollaries:

- The `:ro`-mount option in item 2 is not merely tidy — it is the only thing that
  makes deletion of non-`inbox/` paths *impossible* rather than *discouraged*.
- Item 5's git question is load-bearing for the same reason: an uncommitted write
  that Syncthing has already pushed is gone everywhere at once.

Also settled there: `.sync-conflict-*` files are **accepted** (item 4 is about
noticing them, not preventing them), and `Ignore Permissions` must stay on —
turning it off to tidy modes would break Perlite's read path.

One correction to item 4's framing: the folder has **three** read-write peers, not
two. krypton *and the phone* were already `Send & Receive` (vault-serve `02`), so
helium is the third — meaning a phone-vs-helium conflict can occur with krypton
uninvolved, and whatever notices conflicts cannot assume krypton is one side of them.

### Inherited from ticket `03` (verified on the box 2026-07-31 — don't re-derive)

This is the ticket `03` changed most, and one item makes "narrow" far cheaper to
express than either ticket assumed.

- **`HERMES_WRITE_SAFE_ROOT` is a `:`-separated list of path *prefixes*, not a single
  root** (`agent/file_safety.py:84`, plus `tips.py`: *"restricts write_file/patch to
  directory prefixes; multiple paths via os.pathsep"*). So "narrow" is expressible
  **natively** — `/opt/data:/vault/inbox:/vault/journal` — with no bespoke mechanism
  to build. `03` sets the baseline to `/opt/data:/vault`; **narrowing the `/vault`
  half is this ticket's job.** Ticket `01`'s caveat still stands and is the reason
  this is not the whole answer: it constrains `write_file`/`patch` but **does not bind
  the `terminal` tool**, and upstream says so — so it is a strong guardrail against
  the agent's *ordinary* file path, not a boundary.
- **The vault is mounted at `/vault`, outside `HERMES_HOME`.** That is deliberate:
  `stage2-hook.sh` chowns `$HERMES_HOME` non-recursively and then recurses over a
  fixed subdir list (`cron sessions logs hooks memories skills skins plans workspace
  home profiles pairing platforms/pairing lazy-packages`), and mounting the vault
  outside puts it beyond that mechanism entirely. **The bind mount remains the only
  real boundary** (ticket `01`), so what is mounted is the outermost control.
- **Hermes writes as `ms` (uid 1000:1000)**, via `HERMES_UID`/`HERMES_GID` — the
  image *rejects* `docker run --user`. So vault-serve `004`'s permission model is
  unchanged (root `700 ms`, contents `755`/`644`) and **file ownership carries no
  information** about whether the agent or the owner wrote a file. Do not design an
  enforcement or audit mechanism that leans on ownership.
- **The git-as-undo premise is gone — do not build on it.** `~/vault/.stignore`
  excludes `.git`, so helium's replica has **no repo**; `.gitignore` deliberately
  untracks finance *data*; and Syncthing versioning was **off on every krypton
  folder**. The owner declined a git audit repo on helium. The vault's undo is now
  **staggered Syncthing versioning on krypton** (ticket `11`) — path-agnostic, covers
  deletions and untracked files, and is author-agnostic. Ticket `04`'s note that
  `004` *"leans on `~/vault` being a git repo as the real undo"* is therefore
  narrowed: git covers only the 215 tracked files on **krypton**, and nothing on helium.
- **`--workdir <dir>` injects `AGENTS.md`/`CLAUDE.md` from that directory.** A job
  with `--workdir /vault` picks up the vault charter for free — which is a *soft*
  instruction channel worth considering alongside the hard prefix list, given the
  map's "Hermes replaces `/daily`" framing.
- **Traceability now lives in `$HERMES_HOME/logs`** (restic-covered), not in the
  vault. If this ticket wants a per-write record inside the vault, that is a new
  decision, not an inherited one.

### Why this needs its own ticket

"Narrow write surface" is currently a *principle*, and principles do not survive
contact with an autonomous agent. The last one **deleted `.stfolder` while
reorganizing** and silently halted sync for up to an hour, diverging both sides
badly. The redesign (memory in `~/.hermes`, vault as data source) removes the
*motive* for that, but not the *capability*.

### What the answer must settle

1. **The write allowlist.** Concretely which paths. Starting proposal, given board
   ownership is out of scope: **new files in `inbox/` only** — one file per note,
   `<YYYY-MM-DDThhmm>-<source>-<slug>.md`, matching the convention the `note` skill
   and the global cross-session rules already use (one file per note specifically to
   avoid clobbering and Syncthing conflicts — that rationale applies doubly here).
   Then decide what else, if anything, earns write access now vs. later.
2. **Enforcement vs. instruction.** Is the boundary a *prompt* (Hermes is told), a
   *mount* (only `inbox/` is writable, the rest `:ro` — the bind-mount pattern
   vault-serve chose as its actual boundary), or *both*? Note vault-serve ticket
   `03` concluded the mount surface **alone** was the real boundary and a
   configured denylist was explicitly *not* trusted. Same reasoning applies:
   prompt-level restraint is not a boundary.
3. **The read surface.** Full-egress is accepted, so this is about *utility and
   cost*, not secrecy: sending the entire vault on every turn is expensive and
   noisy. Decide how Hermes finds what it needs — full read + retrieval, or a
   curated set of always-loaded entry points. The vault's own `AGENTS.md` is
   deliberately structured for this ("a thin always-on core + routers", "load a
   topic's own doc only when the task needs it"), which is a ready-made answer worth
   reusing rather than reinventing.
4. **Conflict handling.** Two writers on `personal-vault` will produce
   `.sync-conflict-*` files. Who notices, and how? (Ticket `05` owns the alerting
   mechanism; this ticket owns *whether it's a condition worth alerting on*.) Also:
   does Hermes ever *resolve* conflicts, or only report them? Recommended: report
   only.
5. **git as the safety net — made real.** `~/vault` is a git repo, but an
   uncommitted agent write is not revertable, and Syncthing will happily sync
   `.git/` into a race between peers. Settle: who commits, when, and whether `.git/`
   is excluded from Syncthing via `.stignore`. This is the difference between "git
   is the safety net" and "there happens to be a git repo here".
6. **The `.stfolder` marker guard.** Carry the prior-art unit forward (ticket `02`),
   updated for `personal-vault` on helium. Cheap insurance; should never fire.
7. **`~/vault/AGENTS.md` must be rewritten.** It currently says the vault is synced
   to `titan` and "worked on by … Hermes agent (titan)" — stale on both counts, and
   other agent sessions read it as ground truth. This ticket produces the content;
   the map lists it as fog until then.
