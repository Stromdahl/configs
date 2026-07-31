# Engine research: Nous hermes-agent v0.19.x on helium

Research asset for ticket [01 — Choose the engine and land a version-pinning
policy](../issues/01-choose-and-pin-engine.md). Read/research only — nothing
installed, nothing deployed, no remote access used.

**Verification scope.** Every claim below is tagged:

- **[DOC]** — read from the upstream repo's own docs under `website/docs/`
  (fetched via `gh api` against `NousResearch/hermes-agent@main`).
- **[SRC]** — read from upstream source: the `Dockerfile` or
  `.github/workflows/docker.yml`.
- **[REG]** — read from the Docker Hub registry API (tags + digests).
- **[INF]** — my inference from the above, not a stated fact.

Anything not tagged is my own reasoning about *this* homelab. The scope was
bounded by the ticket's ✅ scope-settled block: judged on **unattended-push
reliability alone**, incumbent wins ties.

---

## Verdict

**Nous hermes-agent v0.19.1 stays.** Pin the released image by digest, run it
as a single supervised container on helium, and derive a thin image layer to add
the `himalaya` binary.

```
nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d6496d4763d5e4fb675b5f504cb23b0e35ec9b790481a56118602b10f
```

No alternative is *clearly* better on unattended-push reliability, so the tie
rule resolves to the incumbent. But the verdict is **conditional on one thing
the engine cannot do for us**, and that condition is ticket `05`'s whole job:

> hermes-agent's fail-loud primitives catch **crashes, non-delivery, and failed
> writes**. They do not catch **plausible-but-fabricated content**. The v0.14
> fake weather was hardcoded constants inside the gathering script — it exited
> 0, wrote non-empty stdout, and delivered successfully. Every v0.19 primitive
> below would have shipped it too.

So the answer to "does v0.19 fix the thing that actually burned us" is **no, and
it structurally can't** — that failure lives above the engine. Which means the
engine choice is *not* the load-bearing decision on this map; the verification
story is.

---

## 1. Version and cadence — the ground truth

**Version naming is dual.** [DOC][REG] The release *name* is `v0.19.1`; the git
tag and image tag are the date form `v2026.7.30`. Every release follows this:

| Release name | Tag | Date |
|---|---|---|
| v0.19.1 | `v2026.7.30` | 2026-07-30 |
| v0.19.0 "The Quicksilver Release" | `v2026.7.20` | 2026-07-20 |
| v0.18.2 | `v2026.7.7.2` | 2026-07-08 |
| v0.18.1 | `v2026.7.7` | 2026-07-08 |
| v0.18.0 "The Judgment Release" | `v2026.7.1` | 2026-07-01 |
| v0.17.0 "The Reach Release" | `v2026.6.19` | 2026-06-19 |
| v0.16.0 "The Surface Release" | `v2026.6.5` | 2026-06-06 |

**The cadence is worse than the map assumed.** [DOC] v0.19.0 rolls up ~2,245
commits / ~1,065 merged PRs / ~3,300 issues closed since v0.18.0 — *nineteen
days* earlier. v0.19.1 then rolled up "approximately 1,000+ merged pull
requests" in the **ten days** after that. Six named releases in roughly two
months.

This is the single strongest durability argument in the ticket, and it argues
for **pinning hard and upgrading rarely**, not for rejecting the engine — the
velocity is what produced the fail-closed primitives in §4.

---

## 2. Requirement 3 — Docker fitness on helium

### The two senses of "Docker", disambiguated

The ticket was right that the docs list both, and they are independent. [DOC]

| Sense | What it is | Do we want it? |
|---|---|---|
| **Mode 1 — agent in a container** | The whole agent (gateway, dashboard, skills, memory) runs inside `nousresearch/hermes-agent`. State on one volume. | **Yes.** This is the map's premise and it is fully supported. |
| **Mode 2 — `terminal.backend: docker`** | Hermes runs on the host; every command *the agent executes* runs in a separate long-lived sandbox container. | **No.** Nesting it inside Mode 1 would need the docker socket. Keep `terminal.backend: local` (the default). |

Mode 2 exists alongside `local`/`ssh`/`singularity`/`modal`/`daytona`/`vercel_sandbox`. [DOC]
It is a *tool-sandboxing* choice, not a deployment choice — the map's Notes
conflated them, and they should stay separated in ticket `03`.

### Container facts (all [SRC] from the `Dockerfile` unless noted)

- `ENV HERMES_HOME=/opt/data` — the single persistent volume, host-mounted from
  `~/.hermes`. [DOC] The image itself (`/opt/hermes`) is immutable at runtime.
- `ENV HERMES_WRITE_SAFE_ROOT=/opt/data` — see §5, this is load-bearing.
- `useradd -u 10000 -m -d /opt/data hermes`; every supervised service and the
  main program drop to that user via `s6-setuidgid`. Running the gateway as root
  is **refused by default** (`HERMES_ALLOW_ROOT_GATEWAY=1` to override).
- `ENTRYPOINT` is `/init` (s6-overlay as PID 1). Do not override it.
- Runtime deps include `ripgrep`, `ffmpeg`, `git`, `openssh-client`,
  **`docker-cli`**, `python3`. **`himalaya` is not among them** — see §6.
- [REG] Multi-arch `amd64` + `arm64`, so helium's i5-9400 is covered.
- Ports [DOC]: gateway API `8642` (`API_SERVER_PORT`); dashboard `9119`
  (`HERMES_DASHBOARD_PORT`, enabled with `HERMES_DASHBOARD=1`).
- **No privileged mode, no host network, no docker socket required.** [DOC] The
  socket bind-mount is optional (only to let the agent run host docker commands);
  `--network host` is only for reaching a host inference server, which helium
  has none of.

### Two supervision behaviours that matter for ticket 05

1. **The gateway is supervised and auto-restarts.** [DOC] `--no-supervise` /
   `HERMES_GATEWAY_NO_SUPERVISE=1` restores the old "container exit = gateway
   exit" semantics; the docs call the supervised default "strictly better" for
   production. It is better for uptime — and worse for observability, because a
   crash-looping gateway presents as a healthy container.
2. **There is no `HEALTHCHECK` in the image.** [SRC] Verified absent (a
   case-insensitive grep of the `Dockerfile` returns nothing). Combined with (1),
   `docker ps` "Up" tells you nothing about whether cron is ticking. **Ticket 05
   must add its own probe**, and helium already has the plumbing for it (issue
   046's MQTT publishers, `docker2mqtt`).

Also [DOC]: a boot-time reconciler reads
`$HERMES_HOME/profiles/<name>/gateway_state.json` and brings the gateway back up
if its last recorded state was `running` — a restart, image upgrade, or
unexpected exit all preserve `running`. Only an explicit `hermes gateway stop`
keeps it down. Good: image upgrades don't silently leave the agent dead.

---

## 3. Requirement 2 — how each mode is actually served

**One container, one long-running process, both modes.** [DOC]

**Pull (Telegram).** The messaging gateway. `TELEGRAM_BOT_TOKEN` in
`~/.hermes/.env`. The gateway has a layered user-authorization system controlling
who may interact with the bot — directly relevant to the map's open
*Telegram identity/authorization* fog, which currently records only "old setup
pinned a single chat id".

**Push (scheduled/triggered).** The **gateway's background cron ticker, every 60
seconds**. Three facts follow, and all three are traps:

- **A CLI chat session does not fire cron jobs.** No gateway → no push mode.
- Jobs live in `~/.hermes/cron/jobs.json`. The docs say explicitly: *do not*
  `patch` that file directly; use the `cronjob` tool / `hermes cron` / `/cron`.
  (This vindicates the existing `project_hermes_agent_architecture` memory's
  "don't hand-edit jobs.json" — it is now an upstream-documented rule.)
- Delivery targets include `telegram` and `telegram:<chat_id>`, plus `local`
  (writes to `~/.hermes/cron/output/`) and `origin` (the chat that created the
  job). `email` delivery needs SMTP — **unavailable to us**, Proton Bridge's SMTP
  is broken.

**Scheduling grammar** [DOC]: cron expressions (`0 9 * * *`), intervals
(`every 2h`), one-shots (`30m`, ISO timestamps). Jobs use the **local
timezone** — so the container needs `TZ` set correctly or briefings fire at the
wrong hour, silently.

---

## 4. The unattended-push axis — what v0.19 gets right

These are the primitives that did not exist in the v0.14 era, and they are the
reason the incumbent survives the comparison. All [DOC].

1. **Model/provider drift guard, on by default.** A cron job that inherited the
   global default model, whose global default later changes, **fails closed**: it
   *skips the run, makes no inference call, and alerts you* to pin explicitly
   (upstream issue #44585). Rationale stated in the docs: "prevents an
   unattended job from silently inheriting a switch to a paid provider/model."
   Disableable via `cron.model_drift_guard: false` — **don't**.
2. **Failure always beats silence.** *"Failed jobs always deliver regardless of
   the `[SILENT]` marker — only successful runs can be silenced."*
3. **`no_agent=True` script-only jobs.** The scheduler runs a script and
   delivers its stdout verbatim, **skipping the agent entirely** — no tokens, no
   model, no provider fallback. Semantics: empty stdout → silent tick;
   **non-zero exit or timeout → an error alert is delivered, "so a broken
   watchdog can't fail silently."**
4. **Zero delivery targets** (`deliver: all` with nothing configured) is
   *"recorded as a delivery failure upstream"*, not a no-op.
5. **`display.file_mutation_verifier: true`** (default) appends an advisory when
   a `write_file`/`patch` failed during a turn and was never superseded —
   documented as catching *"the 'batch of parallel patches, half silently fail,
   model summarises success' class of over-claim."* This is a fail-loud
   mechanism aimed squarely at the map's enemy.
6. **`approvals.denial_breaker_threshold`** (default 3) hard-stops an agent
   retrying variations of a denied command instead of burning guardian LLM calls
   in a loop.

### Does v0.19 remove v0.14's scaffolding, or rename it?

**Neither — it blesses it.** The ticket framed this as the open question, and the
answer is that `no_agent=True` makes the 122-line-bash-script shape a
*first-class supported mode* and bolts loud failure onto it. The `cronjob` tool
even exposes `no_agent` to the agent, so Hermes can author a watchdog script into
`~/.hermes/scripts/` from a chat message and wire the job itself.

That is the *right* answer for reliability — determinate content should have no
LLM in its path — but it kills the hope behind requirement 5's framing. The
briefing stays script-driven. Plan for maintaining scripts, not for built-ins
replacing them.

### The silent-failure paths that remain

Read from the engine's **own troubleshooting guide** — i.e. these are documented
behaviours, not speculation. [DOC]

| Failure | Behaviour |
|---|---|
| Misformatted schedule | *"silently defaults to one-shot or is rejected entirely"* |
| Misconfigured delivery target | *"silently drops the response"* — the job still runs |
| `~/.hermes/cron/jobs.json` unreadable/unwritable | *"the scheduler will fail silently"* |
| Two gateway instances (lock contention) | jobs *"delayed or skipped"* |
| Response *contains* `[SILENT]` anywhere | delivery suppressed (successful runs only) |
| Per-job error surface | *"Check `hermes cron list` for updated `last_error` field **(if available)**"* — upstream hedges its own field |

Plus three structural constraints:

- **Cron jobs run with the `cronjob`, `messaging`, and `clarify` toolsets
  disabled.** The agent therefore **cannot message you from inside a cron job** —
  delivery is scheduler-only — and an approval escalation under
  `approvals.mode: smart` has nowhere to escalate *to*.
- **Cron scripts do not inherit credentials.** Subprocess env is sanitized
  (`_sanitize_subprocess_env`): provider API keys and Hermes-managed secrets are
  **not** passed to cron scripts. A briefing script needing an HA token or a
  Paperless key must get it by another path — a ticket-`03` deployment concern.
- **Scripts must resolve inside `$HERMES_HOME/scripts/`.** Paths escaping it are
  rejected. So gathering scripts live on the state volume, not in the repo — a
  real tension with this repo's "config in git" convention that `03` must settle.

Timeouts: agent jobs use an **inactivity**-based timeout (600s default,
`HERMES_CRON_TIMEOUT`, `0` = unlimited); pre-run scripts have a separate 3600s
cap (`cron.script_timeout_seconds` / `HERMES_CRON_SCRIPT_TIMEOUT`).

---

## 5. Requirement 5 — the v0.14 defects, one by one

### 5a. Where state lives — the map's premise, verified

[DOC] Memory is files under `~/.hermes/memories/`, injected into the system
prompt as a frozen snapshot at session start; the agent manages it via the
`memory` tool. Sessions are SQLite with FTS5 at `~/.hermes/state.db`. Cron jobs
at `~/.hermes/cron/jobs.json`; logs at `~/.hermes/logs/agent.log` and
`errors.log`.

So the map's "keep Hermes' memory in `~/.hermes` and treat `~/vault` as a data
source" is **achievable by default**, not something we have to engineer.

One correction to the map: **`/journey` is CLI-only.** [DOC] The slash-command
reference lists it among commands that work *"in the classic CLI, as a TUI
overlay, and in the desktop app… Not available on messaging platforms."* You
cannot inspect memory from Telegram — that needs a shell into the container.

### 5b. Does it restructure its own working directory?

There is now a real mechanism, and it is on by default in the container.

**`HERMES_WRITE_SAFE_ROOT`** [DOC]: when set, `write_file` and `patch` may only
target paths inside the listed prefixes; anything outside is **hard-blocked —
not routed through approval**. And critically: *"Set automatically in the
official Docker image (`HERMES_WRITE_SAFE_ROOT=/opt/data`)"* — confirmed [SRC] in
the `Dockerfile`.

**Consequence for ticket 08: in the official image, `~/vault` is not writable by
Hermes' file tools by default.** Making it writable is an explicit act — adding
the vault path to a `:`-separated safe root. That inverts the v0.14 posture,
where the vault *was* the working directory.

A protected-path denylist applies even with the safe root unset: OS credential
stores (`~/.ssh/`, `~/.aws/`, `~/.kube/`, `/etc/sudoers`, `~/.netrc`), Hermes
credential stores (`auth.json`, `.env`, `mcp-tokens/`, `pairing/`), and `.env` /
`.env.local` / `.env.production` / `.envrc` **anywhere on disk**.

**But the docs are explicit that this is not a boundary:**

> *"Write guards apply to `write_file` and `patch` only. The `terminal` tool runs
> as the same OS user and can still `cat` or overwrite denied paths via shell
> commands. The denylist reduces accidental damage and gives models a clear stop
> signal; it does not sandbox a hostile or compromised agent."*

The managed-scope doc says the same from another angle: *"a hard boundary that
the agent itself cannot escape"* is listed as **intentionally out of scope for
v1**.

**⇒ The only real write boundary is the container bind-mount.** This is the same
conclusion vault-serve `03` reached with its per-folder `:ro` mounts, and it is
the finding tickets `03` and `08` should inherit rather than re-derive: mount
read-only what Hermes may only read; mount read-write only the narrow surface it
must file into; treat `HERMES_WRITE_SAFE_ROOT` as defence-in-depth on top.

Two further mitigations, both relevant to `08`:

- **Checkpoints** — *"automatic filesystem snapshots before destructive file
  operations."* Opt-in (`checkpoints.enabled: false` by default), `max_snapshots:
  20` per directory. A direct mitigation for the reorg catastrophe, and it
  composes with `~/vault` already being a git repo.
- **`approvals.deny`** — a glob list that blocks matching terminal commands
  **unconditionally, even under `--yolo` / `/yolo` / `approvals.mode: off`**.
  The one hard lever available against the terminal-tool escape hatch.

Approvals default to `approvals.mode: smart` (an auxiliary LLM judges flagged
commands; low-risk auto-approved, risky denied, uncertain **escalated to the
user**). Note the interaction with §4: in a cron job the `clarify` toolset is
disabled, so an escalation has no route to a human. `approvals.deny` is
therefore the only reliable guard on the unattended path.

### 5c. Self-internals confabulation — not answerable from docs

**Stating this plainly rather than inferring a fix.** Searching the upstream
issue tracker for `confabulat` returns **0 results**; `hallucinat+own+internals`
returns 0. There is no upstream record of the v0.14 behaviour, so there is
nothing to verify as fixed. Inferring "v0.18's 3,300 closed issues probably
covered it" would be exactly the looks-verified failure this map names as the
enemy.

**Route it as a working rule rather than a resolved defect:** never ask the agent
about its own state. v0.19 provides ground-truth surfaces that don't involve
sampling the model — `hermes cron list`, `hermes doctor` (reports the resolved
managed dir and pinned key counts), `hermes logs`, `hermes skills list`, and the
raw files under `~/.hermes/`. Ticket `05` should build its verification on those,
not on asking Hermes whether it ran.

---

## 6. The email half — a correction the map needs

[DOC] There are **two different email mechanisms**, and the map's framing points
at the wrong one.

**The Email gateway adapter** makes email a *chat channel*: people email the
agent's address, it replies in-thread via SMTP. Two disqualifiers for us:

1. It requires SMTP for replies. Proton Bridge's SMTP is broken
   (`454 4.7.0 unknown error`).
2. **At startup it "marks all existing inbox messages as 'seen'"** so it only
   processes new mail. Pointed at the real personal inbox, that silently marks
   the entire backlog read. This is a destructive first-run behaviour and it
   should be written into ticket `07` as a hazard, not discovered live.

**The Himalaya skill** is the triage path: *"lets the agent inspect, compose,
move, and manage mailbox messages from terminal tools."* [DOC]
`skills/email/himalaya`, v1.1.0, **bundled — installed by default**, and
explicitly documented as *"separate from the Hermes Email gateway adapter."* It
drives the external `himalaya` CLI over IMAP with a config at
`~/.config/himalaya/config.toml`, so it can read/move/flag **without SMTP**.

**The binary is not in the image** [SRC] — the runtime-deps layer lists
`ripgrep ffmpeg gcc g++ make cmake python3-dev python3-venv libffi-dev libolm-dev
procps git openssh-client docker-cli xz-utils` and no `himalaya`. The docs cover
extending the image via a downstream `FROM nousresearch/hermes-agent:…`
Dockerfile, inheriting the entrypoint and `/opt/data` semantics unchanged.

**⇒ Two consequences.** Ticket `03` owns a derived image (which is also where a
digest-pinned base belongs — see §7). Ticket `07` owns the Himalaya-vs-adapter
choice and the "no SMTP, so filing means IMAP flags/moves" contract.

---

## 7. Requirement 4 — the pin, and why `:latest` is a trap

### The trap

[SRC] `.github/workflows/docker.yml`, the `merge` job:

```bash
if [ "${{ github.event_name }}" = "release" ]; then
  tags=(-t "${IMAGE_NAME}:${RELEASE_TAG}")
else
  tags=(-t "${IMAGE_NAME}:main" -t "${IMAGE_NAME}:latest")
fi
```

The job triggers on `push` to `main` **or** on `release`. So:

- **`:latest` and `:main` are pushed on every commit to `main`.** `:latest` is
  main HEAD, **not** the newest release.
- Releases get **only** `:<release_tag_name>`.

[REG] Confirmed in the registry: `latest` and `main` share digest
`sha256:f59eb17c…` (both pushed 2026-07-31, two seconds apart), while
`v2026.7.30` is `sha256:b869e64d…`.

**And the docs' own compose examples use `image: nousresearch/hermes-agent:latest`
throughout** — as do the third-party install guides. Following the quickstart
verbatim puts helium on an unreviewed main-branch build that changes under you.
This is the single most actionable finding in the ticket.

### The pin

Released version tags are immutable and digest-addressable, so a real pin is
available:

```
nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d6496d4763d5e4fb675b5f504cb23b0e35ec9b790481a56118602b10f
```

Pin by **digest** (verified as the multi-arch OCI *index* —
`application/vnd.oci.image.index.v1+json` — not a per-arch child, so the pin stays
portable), with the version tag retained for human readability. Because `03` needs
a derived image for `himalaya` anyway, the digest belongs in our `FROM` line, and
our own build tag becomes what compose references.

**Caveat the derived image introduces: "pinned by digest" is only half true unless
the added layer is pinned too.** Himalaya's documented install is
`curl -sSL .../pimalaya/himalaya/master/install.sh | PREFIX=~/.local sh` [DOC] — an
unpinned pipe-to-shell off `master`. So a rebuild moves *two* things: the base
digest and whatever `himalaya` happens to be current. And a rollback restores only
the base. **Pin the `himalaya` version explicitly in the derived Dockerfile** (a
release tag or checksum, not `master`), or the upgrade/rollback recipe below
doesn't actually bound what changed. Ticket `03` owns this.

### Upgrade policy

| | |
|---|---|
| **Cadence** | Quarterly, or on a *named* need (a fix we want, a feature a ticket depends on). Never on a schedule tighter than that — at ~1,000 PRs per patch release, reading the delta is not feasible, so time-in-the-wild is the only proxy for stability we have. |
| **Never** | `:latest`, `:main`, Watchtower, or unattended-upgrades touching this container. |
| **Before** | Read the release notes for breaking changes. Take a restic backup of `~/.hermes` (helium's three restic units already cover it — the pre-upgrade snapshot *is* the rollback plan). |
| **How** | Bump the digest in our Dockerfile, rebuild, `docker compose up -d`. State is preserved; the boot reconciler restarts the gateway. |
| **Verify** | `hermes doctor`; `hermes cron list` (every job `[active]`, `next_run` sane); force one `hermes cron run <id>` per critical job and confirm it *arrives on Telegram*. "Container is up" is not verification — there is no healthcheck. |
| **Roll back** | Restore the previous digest **and** the pre-upgrade `~/.hermes` snapshot together. |

### State-format migration risk — moderate, and handled in-container

[DOC] The container's cont-init hook (`docker/stage2-hook.sh`) runs
**non-interactive config-schema migrations** on boot unless
`HERMES_SKIP_CONFIG_MIGRATION=1`, writing timestamped backups next to the
migrated files. This matters because the *host* `hermes update` path is
interactive (`hermes config migrate` prompts) — the container sidesteps that.

The residual risk is that migration is effectively one-way: rolling the image
back does not roll the config back, which is exactly why the rollback recipe
pairs the digest with the volume snapshot. The `updates.pre_update_backup` knob
(`quick` / `full` / `off`) is a source-install feature; for us the equivalent is
restic.

---

## 8. Requirement 6 — BYO key vs Nous Portal

**Bring-your-own-key remains unambiguously first-class.** [DOC] The Nous Portal
page calls itself *"the recommended way to run Hermes Agent"* — recommended, not
required. The providers page documents **30+** inference providers configured by
plain env var in `~/.hermes/.env`, including:

```
OPENROUTER_API_KEY   # provider: openrouter — the exact titan setup
ANTHROPIC_API_KEY / OAuth
OPENAI_API_KEY, GOOGLE_API_KEY, DEEPSEEK_API_KEY, GLM_API_KEY, …
```

plus AWS Bedrock, Azure AI Foundry, Google Vertex, and self-hosted
Ollama/vLLM endpoints.

**Durability finding:** the v0.14 → v0.19 monetization shift did **not** narrow
the self-host path. There is no drift toward hosted-only, and the old
openrouter-key setup is a supported configuration today. This removes the
durability worry the ticket raised about monetization.

Two knobs bear specifically on unattended spend [DOC]: `cron.model` routes cron
jobs to a chosen provider/model independently of the interactive default, and
the drift guard (§4.1) exists precisely to stop an unattended job silently
inheriting a switch to a paid one.

**This makes the provider decision specifiable** — it was the leading fog patch
on the map, held open pending this ticket. Graduated as a new ticket.

---

## 9. Alternatives — bounded, one axis

Judged only on **reliability under unattended operation**. Incumbent wins ties.

| Candidate | Push (unattended) | Pull (Telegram) | Verdict |
|---|---|---|---|
| **hermes-agent v0.19.x** | Built-in cron ticker; fail-closed drift guard; failed jobs always deliver; `no_agent` scripts alert on non-zero exit. Documented silent-failure paths (§4) are real but enumerable and mostly configuration-time. | First-class Telegram adapter, same process. | **Winner.** |
| **Claude Code headless / Claude Agent SDK** | The SDK is a **harness only — you host and deploy it**; it ships no scheduler, no messaging channel, and no failure alerting. Every primitive in §4 becomes homework: systemd timers, a Telegram sender, a dead-man's-switch. *Anthropic's Managed Agents* does offer cron-scheduled deployments with per-firing run records and webhooks — but Anthropic hosts the loop *and* the tool sandbox, so it is not a helium workload and would put vault contents in a hosted container. | Would have to be built. | Loses. Directly contradicts *"get it working reliably once and for all."* |
| **n8n (or similar) + an LLM step** | Genuinely strong: a real scheduler, per-execution history, error workflows. Arguably better than hermes-agent on *this* axis alone. | Not conversational. A Telegram agent loop with memory would be hand-built on top. | Loses on the two-modes requirement, and adds a second stateful service to helium. |
| **OpenWebUI-class** | No unattended scheduler. Pull-only by design. | Good. | Fails the axis outright. |

The pattern the ticket predicted held: the strongest push candidate (n8n) is the
weakest on pull, and the strongest pull candidates have no push story. Only
hermes-agent covers both in one supervised process. Nothing is *clearly* better
on the stated axis, so the tie rule decides it.

---

## 10. What this hands to other tickets

**→ `03` (deployment shape and state)**

- Mode 1 container; `terminal.backend: local`; do not mount the docker socket.
- No `HEALTHCHECK` in the image + a supervised gateway ⇒ compose must add its own.
- **A derived image is required** for `himalaya`; pin the base by digest there.
- Cron scripts must live under `$HERMES_HOME/scripts/` (not the repo) and **do
  not inherit credentials** — how a gathering script gets an HA/Paperless token
  is a `03` decision.
- `TZ` must be set or schedules fire at the wrong local hour, silently.

**→ `05` (loud failure / verification)**

- The engine catches crashes, non-delivery, and failed writes. It does **not**
  catch fabricated content. The verification story must assert on *freshness of
  content*, from outside hermes-agent's own cron.
- Cron jobs cannot message you (`messaging` toolset disabled) — the heartbeat
  must be a `no_agent` script or fully external.
- Never interrogate the agent about itself; read `hermes cron list` /
  `hermes doctor` / `~/.hermes/logs/`.
- Keep `cron.model_drift_guard` on. Keep `display.file_mutation_verifier` on.

**→ `07` (email triage contract)**

- **Do not** use the Email gateway adapter: it needs SMTP (broken) and marks the
  whole inbox seen on first start.
- Use the bundled Himalaya skill over IMAP; filing = flags/moves, not sends.
- `himalaya` must be added to the image.

**→ `08` (vault read/write surface)**

- `HERMES_WRITE_SAFE_ROOT=/opt/data` in the official image means the vault is
  **not** writable by default — opening it is an explicit act.
- Write guards do not bind the `terminal` tool. **The bind-mount is the
  boundary**; `approvals.deny` globs are the only unconditional command-level guard.
- Consider enabling `checkpoints` for pre-write snapshots (opt-in, 20/dir).

**→ new ticket (provider choice)** — unblocked by §8; see the map.

---

## Sources

Upstream repo `NousResearch/hermes-agent` @ `main`, read via `gh api`:

- `website/docs/user-guide/docker.md`, `configuration.md`, `security.md`,
  `managed-scope.md`
- `website/docs/user-guide/features/cron.md`, `memory.md`, `tools.md`
- `website/docs/guides/cron-troubleshooting.md`, `automate-with-cron.md`
- `website/docs/user-guide/messaging/email.md`
- `website/docs/user-guide/skills/bundled/email/email-himalaya.md`
- `website/docs/integrations/providers.md`, `nous-portal.md`
- `website/docs/reference/slash-commands.md`
- `website/docs/getting-started/updating.md`
- `Dockerfile`, `.github/workflows/docker.yml`

Registry: `hub.docker.com/v2/repositories/nousresearch/hermes-agent/tags`

Releases: <https://github.com/NousResearch/hermes-agent/releases>
