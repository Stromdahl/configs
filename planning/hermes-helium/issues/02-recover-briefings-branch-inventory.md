# Inventory the hermes/briefings branch: what survives, what is superseded

Type: task
Status: resolved

## Question

Branch **`hermes/briefings`** (commit `abb62a6`, never merged) holds ~740 lines of
already-debugged Hermes config that `4ed7e63` deleted from `main`. Establish
**what is still valuable, what v0.19 supersedes, and what was always wrong** — so
later tickets *reuse* rather than rewrite, and so nothing carries a known bug
forward.

This is a task, not a decision: nothing to choose, but tickets `03`–`08` are all
cheaper once it's done, and at least one item on the branch is known-harmful.

### The inventory

Files deleted from `main` by `4ed7e63`, recoverable from the branch:

- `configs/hermes-agent/SOUL.md` — the exec-assistant persona. Note the *original*
  `~/.hermes/SOUL.md` on titan was **empty/default**; this file is the replacement
  that was written and deployed live.
- `configs/hermes-agent/morning_briefing.sh` (122 lines) + `morning-briefing.prompt.{md,txt}`
- `configs/hermes-agent/weekly_briefing.sh` (65 lines) + `weekly-briefing.prompt.txt`
- `configs/hermes-agent/env.example`
- `configs/hermes-agent/vault-skeleton/` — `System/Assistant/{context,environment,preferences}.md`,
  `logs/issues-fixes-log.md`, `People/MOC.md`
- `configs/hermes-agent/README.md`
- `modules/hermes-agent/install.sh`, `modules/hermes-vault/install.sh`
- `bin/hermes-vault-ensure-marker.sh` (39 lines) +
  `configs/hermes-vault/systemd/hermes-vault-marker.{path,service}`
- `hosts/titan-hermes-agent/{modules.conf,HARDWARE.md}`

### What the answer must judge, per item

- **Keep as-is / adapt / discard**, with the reason.
- **Superseded by v0.19 built-ins?** The briefing scripts in particular exist
  because v0.14 had no usable scheduling or memory. If Automation Blueprints and
  persistent memory now cover it, these scripts are *anti-value* — they'd
  reintroduce the scaffolding this map is trying to shed.
- **Does it encode a known defect?** Specifically: the *original* briefing stub had
  **hardcoded fake weather** and a static home-maintenance echo; the `abb62a6`
  rewrite fixed that (real HA weather via `HASS_*`, per-source `STATUS=OK/ERROR`).
  Confirm which behaviour each recovered file actually contains before reusing it —
  the per-source `STATUS=OK/ERROR` pattern is directly reusable by ticket `05`.
- **Vault-structure assumptions are stale.** The scripts target the *old* separate
  `~/hermes-vault` (`Areas/Health/Medication.md`, `~/Health/Medication.md`) — that
  folder is gone and `~/vault` has a different shape (`health/`, no `Areas/`). Any
  path in these files is suspect.
- **`hosts/titan-hermes-agent/` is dead** (titan is decommissioned) but its
  `modules.conf` documents the working module set — worth reading, not resurrecting.
- **The marker-guard unit** (`hermes-vault-ensure-marker.sh` + path/service) is
  cheap insurance worth keeping even if the memory-out-of-vault redesign means it
  should never fire. Note that it was **gated to hosts with `~/.hermes`** and is a
  *user* systemd unit — both facts constrain ticket `03`.

Record the verdict table in the resolution. Do not merge the branch; this is a
read-and-judge pass. Note also that the branch's dotfiles-module shape assumed a
`install.sh`-managed host — helium is **ansible-only**, so module code is
reference, not reusable as-is.

## Answer

**Resolved 2026-07-31.** Read-and-judge pass over all 21 files, no merge, nothing
restored to the working tree. Verdicts below; the three provenance corrections come
first because two of them change how the recovery is done at all.

### Provenance corrections (verified, not assumed)

1. **The branch is not unmerged — `abb62a6` is an ancestor of `main`.**
   `git merge-base --is-ancestor abb62a6 main` → true; `git branch --contains
   abb62a6` → `hermes/briefings` **and `main`**; `abb62a6` is also on `origin/main`.
   It landed on main **2026-05-29** and `4ed7e63` deleted the files from main
   **2026-06-21**, three weeks later. So merging `hermes/briefings` is a **no-op**
   and would recover nothing — the branch is a stale *local* bookmark at a commit
   already in main's history (it was never pushed: no `hermes/briefings` on
   `origin`). Delete the pointer once this inventory is trusted; it only misleads.
2. **Recover from `4ed7e63^`, not `abb62a6`** — one commit richer, and the correct
   recipe is `git checkout 4ed7e63^ -- <path>` (or `git show 4ed7e63^:<path>`).
   Specifically `hosts/titan-hermes-agent/HARDWARE.md` **does not exist at
   `abb62a6`** (added to main later), so this ticket's own inventory list
   mis-attributes it to the branch.
3. **The deletion also touched `hosts/krypton/modules.conf`** (−3 lines: the
   `hermes-vault` module enablement) — absent from this ticket's inventory. Nothing
   to recover; `~/hermes-vault` was discarded separately.

**Bonus correction, and it matters for `03`: the fake-weather script was never in
this repo at all.** `git log --all -S'11.3'` (no pathspec) hits **only** the
map-charting commit `5e74c59` — i.e. the string exists in history solely as this
map's *description* of the bug. No briefing-named file exists anywhere before
`abb62a6` (`--diff-filter=A --name-only` across all refs), and `--follow` on
`morning_briefing.sh` shows exactly two commits. **`abb62a6` is the fix, born
clean** — there is no fake-weather artifact to purge, and the buggy version lived
only in `~/.hermes/scripts/` on titan, which is gone. See "What `03` must
re-read" below: this narrows the versioning failure rather than confirming it.

### Verdict table

| # | File | Verdict | Why |
|---|---|---|---|
| 1 | `configs/hermes-agent/SOUL.md` | **KEEP AS-IS** | 18 lines, the highest-value artifact recovered. See below. |
| 2 | `configs/hermes-agent/morning_briefing.sh` | **ADAPT — keep the shape, drop most content** | The `STATUS=` contract, `<verbatim>`, date-math-in-script and credential-read-from-file all survive; all five emitters are out of scope or sourceless. See below. |
| 3 | `configs/hermes-agent/weekly_briefing.sh` | **ADAPT, low value** | Same contract, nothing new. All three emitters out of scope (calendar, inbox/board, duplicate weather). Keep only as a second worked example. Cadence is `06`'s call — the destination names an *end-of-day* brief, not a Sunday week-ahead. |
| 4 | `configs/hermes-agent/morning-briefing.prompt.md` | **ADAPT — carries defect ①** | 89 lines. Rendering rules + deployment checklist are good; the final delivery line is now unexecutable. |
| 5 | `configs/hermes-agent/morning-briefing.prompt.txt` | **ADAPT — carries defect ①** | The deployed form of #4 (same text, unwrapped). Keep one of the two, not both — the `.md`/`.txt` pair was itself a drift source. |
| 6 | `configs/hermes-agent/weekly-briefing.prompt.txt` | **ADAPT — carries defect ①** | Same treatment; only reuse if `06` keeps a weekly cadence. |
| 7 | `bin/hermes-vault-ensure-marker.sh` | **ADAPT — owned by vault-serve `004`** | Mechanism sound, every path stale, fails silent. See below. |
| 8 | `configs/hermes-vault/systemd/hermes-vault-marker.path` | **ADAPT — owned by vault-serve `004`** | `PathChanged=%h/hermes-vault` → the helium replica path. |
| 9 | `configs/hermes-vault/systemd/hermes-vault-marker.service` | **ADAPT — owned by vault-serve `004`** | `ExecStart=%h/.dotfiles/bin/…` assumes a dotfiles checkout; helium has none. |
| 10 | `configs/hermes-agent/env.example` | **DISCARD values, KEEP one comment** | `OPENROUTER_API_KEY` presupposes what ticket `09` owns; `OBSIDIAN_VAULT_PATH=/home/ms/hermes-vault` is a dead path. The **cost-cap policy prose is a decision already made** and `09` should inherit it verbatim rather than re-derive it: *prepaid credits only, auto-recharge OFF — the worst case is "Hermes stops working", not "I wake up to a $400 bill".* |
| 11 | `configs/hermes-agent/README.md` | **DISCARD** | Documents the discarded three-tier `~/hermes-vault` pattern and the `env.example → .env` module dance. Its one durable idea (hot memory is an *index* of pointers, not bulk storage) is a v0.19 built-in. |
| 12–16 | `configs/hermes-agent/vault-skeleton/**` (5 files) | **DISCARD** | Three independent reasons, any one sufficient. See below. |
| 17 | `modules/hermes-agent/install.sh` | **DISCARD as code; read once** | pipx/host install, superseded by Mode 1 containerization (`01`) and unusable on ansible-only helium. Carries defect ③. |
| 18 | `modules/hermes-vault/install.sh` | **DISCARD as code; two facts survive** | Scaffolds the discarded `~/hermes-vault`. Carry as notes for `03`: the marker guard was a **`--user`** systemd unit, and was **gated on `[[ -d "$HOME/.hermes" ]]`**. |
| 19 | `hosts/titan-hermes-agent/modules.conf` | **DO NOT RESURRECT; read once** | Two things worth reading off it — see "the module was bypassed" below. |
| 20 | `hosts/titan-hermes-agent/HARDWARE.md` | **DO NOT RESURRECT; one number survives** | The VM that ran v0.14 was **2 vCPU / 4 GB RAM / 32 GB disk** — a useful sizing floor for `03`. (Recover from `4ed7e63^`, not the branch.) |
| 21 | `hosts/krypton/modules.conf` | **NOTHING TO RECOVER** | The −3 lines only enabled `hermes-vault` on krypton; that folder is discarded. |

### #1 `SOUL.md` — keep as-is, and treat it as a control

It already contains, in prose, the two rules ticket `01` found **no engine primitive
enforces**:

> *"When data is missing or a source failed, say so plainly. Never paper over a gap
> or present a failed lookup as 'nothing to report'."*
> *"Only state what you can verify from the data in front of you. Do not invent
> events, news, or reminders from prior knowledge."*

Since `01` established that the drift guard, failed-jobs-always-deliver and mutation
verifier **all miss plausible-but-fabricated content**, this persona is currently
the *only* defence against the fake-weather class. **Ticket `05` must therefore treat
`SOUL.md` as a load-verified control, not decoration** — assert it is present and
loaded, don't assume. Installs to `~/.hermes/SOUL.md`; loads fresh per message, no
restart. Note the original on titan was the **empty default**, so this file replaced
nothing and was deployed by hand.

### #2 `morning_briefing.sh` — what survives is the shape, not the sections

**Survives, and `01` upgraded it from legacy to blessed** — `no_agent=True` makes the
script-only job a first-class mode that alerts on non-zero exit, so the
122-line-bash shape is the supported pattern, not scaffolding to shed:

- **The per-source `STATUS=OK count=<n>` / `STATUS=ERROR reason="…"` contract** —
  the single most reusable thing recovered, and directly what `05` needs.
- **`<verbatim>…</verbatim>`** for character-for-character passthrough of
  safety-critical text — reusable by `05` and `07`.
- **All date math in the script, never in the LLM** (`META: date=… weekday=…`).
- **Credentials read from the file, not inherited env** — `set -a; . "$HOME/.hermes/.env";
  set +a`. This is *accidentally correct and must be preserved*: `01` found cron
  subprocess env is **sanitized**, so a well-meaning cleanup to inherited env would
  break it silently. The file-read is the documented workaround.

**Content that does not survive:**

- `emit_calendar` — **calendar is out of scope** on this map, and it shells into
  `~/.hermes/skills/productivity/google-workspace/venv`, a titan-era skill venv.
- `emit_medication` — **its data source no longer exists.**
  `~/hermes-vault/Areas/Health/Medication.md` is gone and `~/vault/health/` has no
  replacement dosing note; standing medical facts now live in the Notes block of
  `~/vault/projects/strength-and-weight/map.md`, and `~/vault/health/README.md`
  routes anything dated to `tasks.md`. So keeping a 💊 section is not an adaptation
  — it requires *creating* a source first. That is a prerequisite for `06`.
- `emit_labs` — carries defect ②, and its `~/vault` source is likewise absent.
- `emit_news` — a Hacker News footer. Decorative and unrelated to the destination.

**Placement is wrong for helium:** the script was symlinked out of the dotfiles
checkout. `01` established cron scripts must resolve inside `$HERMES_HOME/scripts/`,
and helium has no dotfiles checkout — so it must be **baked into the derived image
or mounted onto the state volume**, which is a `03` decision.

### #12–16 `vault-skeleton/**` — discard, for three independent reasons

(a) It seeds `~/hermes-vault` as the "warm tier" of a three-tier memory pattern
lifted from a Reddit post — **superseded** by v0.19's first-class memory
(`~/.hermes/memories/` + `state.db`) *and* by this map's memory-out-of-the-vault
rule. (b) It is the **unfilled template** — "Describe your main work or business
here", `Last updated: YYYY-MM-DD` — so there is no captured knowledge to lose; its
own README says "fill in the placeholders before the first real session", and nobody
did. (c) `environment.md`'s content is titan facts (VMID 101, `~/hermes-vault`
paths) — stale.

One thing to lift, **not as a file**: `preferences.md`'s register ("Concise, direct.
Dry wit welcome. Never sycophantic.") overlaps `SOUL.md` and, where it differs (*dry
wit welcome* vs SOUL's *no filler, no exclamation marks*), it is a **conflict to
resolve when installing SOUL.md**, not two files to install.

### #7–9 the marker guard — adapt, and its owner is already assigned

**Ownership sits with vault-serve [`004`](../../vault-serve/issues/004-syncthing-role.md)**,
which already names this prior art and two required changes. Do not open a
hermes-helium ticket for it. The full change list:

- `VAULT="$HOME/hermes-vault"` → **`/data/ssd/vault`**; `FOLDER_ID="hermes-vault"`
  → the vault-serve folder id (`personal-vault`).
- The `[[ -d "$HOME/.hermes" ]]` gate is **meaningless when the agent is a
  container** — gate on the folder, not on the agent's home.
- Packaging becomes an **ansible-managed `ms`-user unit** (helium already runs
  Syncthing as an `ms` user service with lingering, so a `--user` path unit fits);
  `ExecStart=%h/.dotfiles/bin/…` must be repointed off the dotfiles checkout.
- It must **fail loudly** — see defect ④.

The mechanism is sound and worth keeping: read the API key and port straight out of
Syncthing's own `config.xml`, then `POST /rest/db/scan?folder=<id>`. And it is
**more** needed now, not less: `004` records `.stfolder` as **high-exposure** under
Send-Receive, because local deletions propagate upstream.

### #19 the module was bypassed — the actual v0.14 delivery failure

`hosts/titan-hermes-agent/modules.conf` has **`# hermes-agent` commented out**, and
`morning-briefing.prompt.md` step 1 says so explicitly: *"the `hermes-agent` module
is commented out … so do it manually after pulling dotfiles."* So on the live host
the scripts were **hand-symlinked**, and `SOUL.md` **hand-copied** (`cp`, step 2) —
a declarative path existed in the repo and was disabled. That, not "the script was
never in version control", is the failure to design out. Also worth reading: the
working module set was small — `base ssh sshd bash-server git qemu-guest-agent nvim
fzf syncthing hermes-vault docker unattended-upgrades`.

### Defects — do not carry these forward

1. **`Then send the finished briefing to Mattias on Telegram.`** — the last line of
   **all three** prompts. `01` established cron jobs run with the **`messaging`
   toolset disabled**; delivery is scheduler-only. The instruction is now
   unexecutable *and* asks the agent to do something it cannot, which is a plausible
   route to "the agent reports it sent the brief and nothing arrives." **Delete it
   from every recovered prompt — delivery is job configuration, not prompt text.**
   Highest-value single finding here.
2. **`emit_labs` expires silently.** The lab schedule is a hardcoded month list
   (`2026-05..2026-10`, `2027-01`, `2027-04`) whose `*)` fallthrough emits
   `labs: STATUS=OK count=0` — and the prompt **omits** `count=0` sections. So from
   **2027-05** a health source disappears from the brief forever while reporting
   "healthy and empty". Same mechanism drops the window mid-month via `dom -le 12`.
   This is the map's enemy class, *inside the file that fixed the previous
   instance*. Any reuse must make an expired schedule table `STATUS=ERROR`.
3. **`pipx install hermes-agent`** — unpinned, installs whatever is current.
   Directly contradicts `01`'s digest-pin decision. Do not resurrect.
4. **The marker guard no-ops silently when its path is wrong.**
   `[[ -d "$VAULT" ]] || exit 0` on a hardcoded `$HOME/hermes-vault`, plus `exit 0`
   on a missing Syncthing config and on an empty API key. Ported as-is against a
   path that no longer exists, it is a guard that reports success and does nothing.
5. **Fake weather: cleared, nothing to purge.** `emit_weather` genuinely queries HA
   (`/api/states` → first `weather.*` entity → `weather/get_forecasts` with
   `return_response`) and returns `STATUS=ERROR` on every failure path. See the
   bonus provenance correction above — the buggy version was never in this repo.

### What this hands to other tickets

- **`03`** — two claims in it are now falsified, plus a sizing floor and a
  placement constraint. Inherited block added.
- **`05`** — the `STATUS`/`<verbatim>` contract as exact reusable text; `SOUL.md` as
  the only anti-fabrication control; defect ② as a worked example of a *health*
  source failing silent. Inherited block added.
- **`06`** — a direct tension to resolve, not just prior art: empty-section
  suppression vs always-report. Inherited block added.
- **`07`** — `<verbatim>` passthrough is the pattern for anything safety-critical it
  decides to surface from mail.
- **`09`** — inherit the prepaid-credits / auto-recharge-OFF cost-cap policy from
  `env.example` (row 10) rather than re-deriving it.

**No new tickets, no fog graduated, no scope change.** This was a task ticket; every
open question it touched already has an owner.
