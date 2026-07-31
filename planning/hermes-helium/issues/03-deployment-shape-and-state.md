# Decide the deployment shape and state placement on helium

Type: grilling
Status: resolved
Blocked by: 01, 02

## Question

**How does Hermes run on helium such that it survives a host rebuild?** Settle the
process shape, where its state lives, how that state is backed up, and how it
reaches the vault as a writer.

This is the **"once and for all" ticket** — the direct answer to four previous
deaths by host churn. If this resolves well, attempt five outlives helium itself.

### Inherited from ticket `01` (verified 2026-07-31 — don't re-derive)

From [assets/01-engine-research.md](../assets/01-engine-research.md) §2, §7:

- **Mode 1 is the shape.** The official image runs the whole agent (gateway,
  dashboard, skills, memory) under s6-overlay as PID 1, non-root `hermes` UID
  10000, with **one** volume: `HERMES_HOME=/opt/data` ← host `~/.hermes`. Gateway
  API on `8642` (`API_SERVER_PORT`), dashboard on `9119`. **No privileged, no host
  network, no docker socket required.**
- **`terminal.backend: docker` is a different thing** — the agent's own *tool*
  sandbox, not a deployment mode. Keep `local` (the default); nesting it inside
  the container would need the socket.
- **There is no `HEALTHCHECK` in the image, and the gateway is supervised**
  (auto-restarts). A crash-looping gateway therefore presents as a healthy
  container, and cron only fires from the gateway's 60 s ticker — so "container
  up" ≠ "push mode alive". This ticket owns adding a probe; `05` owns what it asserts.
- **A derived image is required**: `himalaya` is not in the base image (ticket
  `07` needs it). That derived `FROM` line is where the digest pin belongs —
  `nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d6496d4763d5e4fb675b5f504cb23b0e35ec9b790481a56118602b10f`.
  **Never `:latest`** — CI tags `:latest` and `:main` on *every* main-branch
  commit and tags releases with the release tag only, so `:latest` is main HEAD.
  (Digest verified as the multi-arch OCI index, so it is arch-portable.)
  **Pin `himalaya` in that Dockerfile too** — its documented install is an unpinned
  `curl … /master/install.sh | sh`, so an unpinned layer makes a rebuild move two
  things while a rollback restores only one, and "pinned by digest" stops being true.
- **Cron scripts must resolve inside `$HERMES_HOME/scripts/`** (paths escaping it
  are rejected) **and do not inherit credentials** — the subprocess env is
  sanitized, so provider keys and Hermes-managed secrets are stripped. How a
  gathering script gets an HA or Paperless token is a decision for *this* ticket,
  and the scripts-live-on-the-volume-not-in-git tension is real given this repo's
  conventions.
- **`TZ` must be set in the container** — cron jobs use the local timezone, so a
  wrong `TZ` fires briefings at the wrong hour silently.
- Boot behaviour that helps: a reconciler reads `gateway_state.json` and restarts
  the gateway unless it was explicitly stopped, and non-interactive config-schema
  migrations run on boot (writing timestamped backups). Rollback therefore needs
  the previous digest **and** the pre-upgrade `~/.hermes` snapshot together.

### Inherited from ticket `02` (verified 2026-07-31 — don't re-derive)

From [ticket 02's verdict table](02-recover-briefings-branch-inventory.md#answer):

- **Two claims below are now falsified — read this before "Rebuild survivability".**
  The briefing scripts **were** in version control (on `main`, 2026-05-29 → deleted
  2026-06-21) and the module **did** symlink them (`link`, not `cp`). What actually
  failed is narrower and worse: **`hermes-agent` was commented out in
  `hosts/titan-hermes-agent/modules.conf`**, and the prompt's own deployment
  checklist says to *"do it manually after pulling dotfiles"* — so the declarative
  path existed in the repo and was **bypassed**, with the live host hand-symlinked
  and `SOUL.md` hand-copied. Also: the branch was **not** unmerged (`abb62a6` is an
  ancestor of `main`); it was only never *pushed*. So the thing to design out is a
  **disabled-but-present declarative path**, not missing version control.
- **The genuinely unversioned artifacts were the gateway's own**: `~/.hermes/cron/jobs.json`
  (gateway-owned, "do not patch directly"), the installed `~/.hermes/SOUL.md`, and
  the fake-weather script itself — which **never existed in this repo at any path**
  (`git log --all -S'11.3'` hits only the map-charting commit). That is why it ran
  for "an unknown span" unnoticed. This ticket owns how much of `jobs.json` becomes
  reproducible, and how a hand-installed `SOUL.md` is verified rather than assumed.
- **Sizing floor:** the VM that ran v0.14 was **2 vCPU / 4 GB RAM / 32 GB disk**
  (`hosts/titan-hermes-agent/HARDWARE.md`, recoverable from `4ed7e63^`). helium is
  i5-9400 6C/6T / 16 GB, so headroom is not a constraint — but it bounds what to
  reserve.
- **Script placement is a real decision, and the old answer doesn't port.** The
  gathering scripts were symlinked out of the dotfiles checkout into
  `~/.hermes/scripts/`; helium has **no dotfiles checkout**, and `01` established
  cron scripts must resolve inside `$HERMES_HOME/scripts/`. So: baked into the
  derived image, or mounted onto the state volume — pick one, and note that a baked
  script is versioned while a mounted one is only as versioned as ansible makes it.
- **The credential path is already solved, don't re-solve it.** The recovered script
  does `set -a; . "$HOME/.hermes/.env"; set +a` — reading the file rather than
  relying on inherited env. Given cron's sanitized subprocess env, that *is* the
  workaround; preserve it. It does mean any gathering script can read every key in
  `.env`, which is a mode/ownership question for this ticket.
- **The marker guard constrains this ticket in two ways** (from
  `modules/hermes-vault/install.sh`): it was a **`--user`** systemd unit, and it was
  **gated on `[[ -d "$HOME/.hermes" ]]`** — a gate that becomes meaningless once the
  agent is a container. Its ownership now sits with vault-serve
  [`004`](../../vault-serve/issues/004-syncthing-role.md), not here.

### The decisions bundled here

- **Process shape.** Compose service in helium's `compose_stack` (the house
  pattern — ansible-templated, restic-covered, homepage-visible) vs. a systemd
  **user** service. Real tension: the vault replica is owned by **`ms`** and the
  marker-guard prior art was a *user* unit, but every other service on helium is a
  container, and the engine's own Docker backend may want a socket. Note helium's
  `socket_proxy` exists and is **bridge-network-only with no published port** — a
  container consumer works, a host-side agent would need a raw socket, which
  `issues/010` (non-root containers) deliberately closed off.
- **State placement.** `~/.hermes` holds the agent's memory, credentials, and
  scheduled jobs — i.e. everything that makes it *itself*. Where does it live?
  `/data/ssd/appdata/hermes` follows house convention and lands inside restic's
  appdata backup (`issues/016`). Confirm ownership/mode: it will hold provider
  API keys and a Telegram token.
- **Backup + restore.** Being in restic is not enough — state that has never been
  *restored* is not backed up. What does recovery actually look like, and what is
  irreducibly needs-human on a rebuild (Telegram token? provider key? a login?).
- **uid alignment with the vault.** helium's replica is `ms`-owned at
  `/data/ssd/vault`; Hermes-in-a-container is some other uid. vault-serve ticket
  `03` already decided the folder uses Syncthing **Ignore Permissions** + `UMask=022`
  (deterministic `755`/`644`) for read access — check whether that suffices for a
  *writer*, or whether Hermes must run as `ms`'s uid.
- **Secrets.** Provider key + Telegram token via helium's sops path
  (`servers/…/secrets.env` is the dotfiles pattern; helium uses ansible + sops).
  Beware the `$`-escaping gotcha (`project_helium_traefik_dashboard_auth_dollar_escape`)
  if any secret can contain `$`.
- **Rebuild survivability.** What in this design is captured in ansible/git vs.
  what lives only on the box. The v0.14 setup failed this test explicitly: the
  briefing script was **never in version control**, and host files were direct
  copies rather than symlinks, with the dotfiles branch never merged or pushed.
  That is precisely the failure to design out.
- **Ansible-only host.** helium is provisioned by ansible, not `install.sh`, and
  skips the dotfiles module path — so `modules/hermes-agent/` from
  `hermes/briefings` is reference material, not the delivery mechanism. Decide
  whether a new ansible role or an addition to `compose_stack` is the home.

### Constraints to respect

- No public exposure (helium PRD); Telegram is outbound-only, so no Traefik router
  and no published port are needed — say so explicitly if that holds.
- Deploys are `ansible-playbook site.yml --limit helium --tags compose` (sidesteps
  the ufw/iptables-persistent collision in `issues/028`; see
  `project_ufw_breaks_iptables_persistent` and `project_helium_stack_deploy_and_pin_gotchas`).
- If it joins a shared netns or an internal bridge net, note the restart-coupling
  hazard — cf. `project_helium_gluetun_netns_restart`.

## Answer

Resolved 2026-07-31. **Everything below marked ✅ was executed against the pinned
image on helium**, not reasoned from docs — the image was pulled by digest and
booted four times. Three of the four tests overturned a design that had already
been agreed in this session, so treat the ✅ tags as load-bearing.

### The shape

A **compose service in helium's monolithic `/opt/helium/docker-compose.yml`**,
built from a derived `Dockerfile` that ansible copies into
`{{ compose_stack_dir }}/build/hermes-agent/` — the `protonmail-bridge` pattern
verbatim (copy build context → `docker compose build hermes-agent` → `up -d`).
The systemd-user-service alternative was dropped without much contest: it forfeits
restic coverage, the docker2mqtt state/health entities, and homepage visibility,
and every one of helium's 27 services is a container.

```yaml
hermes-agent:
  build:
    context: ./build/hermes-agent
  image: helium/hermes-agent:v2026.7.30-himalaya
  container_name: hermes-agent
  restart: unless-stopped
  command: ["gateway", "run"]          # ✅ see "the CMD trap" below
  environment:
    - HERMES_UID=1000                  # ✅ ms; upstream's documented mechanism
    - HERMES_GID=1000
    - TZ=Europe/Stockholm              # cron uses local time (ticket 01)
    - HERMES_WRITE_SAFE_ROOT=/opt/data:/vault
  cap_drop: [ALL]
  cap_add: *caps-privdrop              # existing anchor: CHOWN DAC_OVERRIDE FOWNER SETGID SETUID
  security_opt: ["no-new-privileges:true"]
  volumes:
    - ${HERMES_DATA:?missing HERMES_DATA}:/opt/data     # /data/ssd/appdata/hermes
    - /data/ssd/vault:/vault
  networks:
    - paperless        # ✅ internal=false: reaches protonmail-bridge:143 AND the internet
```

No published port, no Traefik router — Telegram is outbound-only, so the helium PRD's
no-ingress posture is satisfied by construction. `paperless` is a plain bridge, **not**
a shared netns, so the `project_helium_gluetun_netns_restart` restart-coupling hazard
does **not** apply; the only coupling is that a `protonmail-bridge` recreate is
invisible to Hermes (it reconnects on the next IMAP poll).

### uid: runs as `ms` (1000:1000) — and `--user` is not the way

- ✅ **The image rejects `docker run --user <uid>` outright.** Booting with
  `-u 1000:1000` exits 1 with an explicit error from `main-wrapper.sh`:
  *"container started with --user 1000 (an arbitrary, non-hermes UID) — not
  supported"*, because the bootstrap is skipped and the baked image dirs (owned by
  the build UID) are unwritable.
- ✅ **`HERMES_UID` / `HERMES_GID` is the supported path, and it works.**
  `stage2-hook.sh` does `usermod -u` / `groupmod -g` on the internal `hermes` user
  (10000:10000) then drops via `s6-setuidgid`. Verified boot log:
  `[stage2] Changing hermes UID to 1000`; every file in the state dir landed
  `1000:1000` (an 88 KB seeded `config.yaml`, plus `cron/ memories/ sessions/
  logs/ hooks/ skills/ profiles/ …`). Upstream's own `docker-compose.yml` header
  prescribes exactly this: `HERMES_UID=$(id -u) HERMES_GID=$(id -g)`.
- **So vault-serve `004`'s permission model needs no change** — no second re-spec.
  Writes land as `ms`, matching krypton, and the vault root stays `700 ms`.
- **Container is root at PID 1 by design** (s6 needs it for the remap), then drops.
  This is precisely what helium's existing `x-caps-privdrop` anchor was written for
  — no new pattern. (Ticket `01` described the image as "non-root `hermes` UID
  10000"; that is true of the *processes*, not of PID 1. `Config.User=root`.)
- ✅ **The boot chown will not eat the vault.** `stage2-hook.sh` chowns
  `$HERMES_HOME` **non-recursively**, then recurses only over a fixed list
  (`cron sessions logs hooks memories skills skins plans workspace home profiles
  pairing platforms/pairing lazy-packages`), with the upstream comment *"The full
  `$HERMES_HOME` may be a host-mounted bind containing unrelated user files;
  `chown -R` would silently destroy host ownership of those."* It also refuses to
  chown through a symlinked path. The vault is nonetheless mounted at **`/vault`**,
  outside `HERMES_HOME`, so it is out of that mechanism's reach entirely.

### Traceability and undo: not git

The owner's first call was "commit as its own git author"; that was **retracted
once the facts landed**, and the retraction is the decision.

- **`~/vault/.stignore` excludes `.git`** — *"keeps history on krypton only"*. So
  helium's replica arrives with no repo, and Hermes cannot commit into the synced
  tree. A separate `git init` audit repo on helium was offered (the exclusion
  actually *enables* it conflict-free) and **declined**: "dont think we need git
  for the vault".
- **`.gitignore` deliberately untracks finance *data*** (`finance/*` minus code,
  `finance.db`, `*.csv`, `*.xlsx`, reports) — `.stignore` states the reasoning
  outright: *"the sensitive-data boundary is git (finance data is gitignored, repo
  never pushed)"*. So git-as-undo never covered the area `tasks.md`'s `🔥 Now` is
  entirely made of.
- **Syncthing file versioning is off on every folder on krypton** (verified in
  `config.xml`: `versioning=''` for `personal-vault`, `Notes`, and the camera
  folder). The `.stversions` entries in the ignore files are precautionary, not
  active.
- **Therefore, before this ticket, a bad Hermes write or delete to an untracked
  path would propagate to krypton and the phone within seconds with no
  point-in-time copy anywhere** — `/data/ssd/vault` is also outside restic
  (`restic_backup_source` is `/data/ssd/appdata` only). Ticket `04` established
  that Send-Receive propagates deletions upstream; this is the live form of it.
- **Undo is therefore Syncthing staggered file versioning on krypton only**
  (`maxAge` 365 d). Owner delegated the choice; rationale: versioning fires when
  *Syncthing* replaces or deletes a file, i.e. on **incoming** changes — so
  versioning on helium would archive nothing about Hermes' own local writes (those
  are *sent*), would only protect helium from krypton's edits, and would grow a
  `.stversions` tree on the SSD outside restic. krypton is the receiving side for
  everything Hermes does and holds the authoritative copy. Staggered over Trash Can
  because the realistic case is an agent misfiring unnoticed for days, and Trash Can
  keeps only the newest version. **This is a rider to vault-serve `004`** — see
  ticket `11`.
- **Traceability moves into Hermes' own state**: the write record lives in
  `$HERMES_HOME/logs`, which *is* restic-covered. Recovery no longer needs to know
  who wrote, because versioning is author-agnostic.

### Secrets: one sops-fed `.env` inside the state volume

Ansible templates `/data/ssd/appdata/hermes/.env` from
`host_vars/helium/secrets.sops.yml`, mode `0600`, owner `1000:1000`. Hermes reads
it natively (`hermes backup --quick` lists `.env` as critical state), and cron
scripts read it via `set -a; . "$HOME/.hermes/.env"; set +a` — which ticket `02`
found was accidentally correct, and remains the workaround for cron's sanitized
subprocess env. Compose passes **only non-secrets** (`TZ`, `HERMES_UID`,
`HERMES_GID`).

Why not compose `environment:`: secrets there land in `Config.Env`, readable via
`docker inspect` — and helium runs **docker-socket-proxy with `CONTAINERS=1`** with
docker2mqtt consuming it and publishing to the Mosquitto broker on argon. That is a
live path from container metadata to a broker on another host. Keeping the provider
key and Telegram token out of `Config.Env` closes it by construction rather than by
trusting the proxy ACL.

Two gotcha notes: the `project_helium_traefik_dashboard_auth_dollar_escape`
`$`-escaping trap does **not** apply (ansible templates this file directly;
docker-compose never interpolates it), but its cousin does — the gathering scripts
`.`-source the file in bash, so **single-quote every value** in the template, which
is correct for both bash sourcing and Hermes' dotenv parsing.

Covers: Telegram bot token, inference provider key (ticket `09` picks *which*; this
ticket only settles the mechanism), and any HA/Paperless token a gathering script needs.

### Scripts: ansible-copied onto the volume — NOT baked into the image

This overturned the session's own earlier conclusion. ✅ `cron/scheduler.py:2241-2250`
does `(scripts_dir / raw).resolve()` then `relative_to(scripts_dir_resolved)`, where
`scripts_dir = $HERMES_HOME/scripts`. Two consequences:

1. Anything baked under `/opt/data` in the image is **masked by the bind mount**.
2. A symlink from the volume out to a baked location is **actively rejected**,
   because `.resolve()` follows it before the containment check.

So gathering scripts are `ansible.builtin.copy`'d from the role's `files/` to
`/data/ssd/appdata/hermes/scripts/`, owner `1000:1000`. Still fully versioned in
git, still replayed by the playbook — only the delivery mechanism changes. This also
closes ticket `02`'s open worry about porting the old placement: the v0.14 setup
**symlinked** scripts out of the dotfiles checkout, and that mechanism would now be
rejected outright, so there was never a version of it to port.

The derived image's job therefore shrinks to exactly three things: the digest pin,
`himalaya` (pinned — ticket `01`), and the healthcheck script.

### Rebuild survivability: split by authorship, with a falsifiable test

Chosen over both "fully declarative" and "restore a `hermes backup` zip", because
each of those repeats a specific past failure — a restore-only story *is* the v0.14
trap (state that exists only as a blob nobody has restored is not backed up), and a
declarative-only story discards the agent's memory, the one thing git cannot
regenerate and the reason v0.19 has `~/.hermes` memory at all.

| Authored by | Lives in | Replayed by |
|---|---|---|
| human | git (ansible role) | `ansible-playbook site.yml --limit helium --tags compose` |
| | → Dockerfile, gathering scripts, `config.yaml` overrides, `SOUL.md`, cron job definitions, `.env` template | |
| agent | restic (`/data/ssd/appdata/hermes`) | restore, as a separate step |
| | → `memories/ sessions/ logs/ state.db auth` | |

**Acceptance test (agreed, and handed to `05`): a rebuild from git *plus the age key*
must yield a working but amnesiac Hermes.** If it doesn't, something is hand-installed
and the v0.14 trap has been rebuilt. Restic then restores the memory as a second,
independently-verifiable step. Two mechanisms, each testable alone — versus one blob
testable only by disaster.

The "plus the age key" is not a weakening — it is the honest wording, and the sloppy
version would have mis-specified `05`'s work. `.env` sits on **both** sides of the
table: ansible templates it from sops (human-authored), *and* it is inside
`/data/ssd/appdata/hermes` so restic holds it and `hermes backup --quick` lists it as
critical state. Since the secrets are sops-encrypted in git, "git alone" yields a
Hermes that **boots and cannot talk to anything** — gateway up, no provider, no
Telegram. That is a *different* and much more confusing outcome than "amnesiac", and
it is exactly the sort of plausible-looking half-success this map exists to catch. So
the test's precondition is git **+ the age key**; the three needs-human items on a
rebuild reduce to *having the age key* plus the Proton 2FA login if `07` needs it.

Mechanics that make the human half real:

- ✅ **`hermes cron create` is a full CLI** (`--script`, `--no-agent`, `--deliver`,
  `--workdir`, `--model`/`--provider`, `--skill`). Ansible seeds jobs via
  `docker exec`, guarded by `hermes cron list`, and never touches the gateway-owned
  `jobs.json` that ticket `02` said not to patch. Idempotency follows the existing
  `paperless_gpt_llm_model` ollama-pull pattern (check-then-act, `changed_when` on
  the check).
- `SOUL.md` is ansible-copied, not hand-copied — ticket `02` found it was
  hand-installed on titan, and it is the *only* current defence against the
  fake-weather class. `05` must verify it loaded; this ticket guarantees it is
  placed declaratively.
- **What the map's diagnosis says to design out is a *disabled-but-present*
  declarative path** (`hermes-agent` was commented out in
  `hosts/titan-hermes-agent/modules.conf` while the live host was hand-wired). The
  structural fix here is that helium has **no opt-in list to comment out** — a
  service either is or isn't in the templated compose file, and `--tags compose`
  applies all of it.
- **Home is `compose_stack`, not a new role.** The service is a container in the one
  compose file; a separate role would need its own copy of the build/env/up
  machinery for no gain. `modules/hermes-agent/` from `hermes/briefings` stays
  reference material (ticket `02` already discarded both dotfiles modules).
- **Irreducibly needs-human on a rebuild:** the Telegram bot token and the provider
  key (both sops-decrypt, so really "have the age key"), and — if ticket `07` uses
  it — the Proton Bridge login with 2FA, which is already a known needs-human
  (`project_helium_protonmail_bridge_paperless`). Nothing else.
- ✅ **`hermes backup --quick`** exists and snapshots "config, state.db, .env, auth,
  cron" — a purpose-built pre-upgrade snapshot. Ticket `01` established rollback
  needs the previous digest **and** the pre-upgrade state together; this is the
  state half. `05` owns making the restore a *tested* path.

### The CMD trap, and the probe (the load-bearing part)

Two ✅ tests here, and both overturned an assumption.

**The default CMD kills the container, silently and successfully.** Booted with the
image's default command, s6 started `main-hermes` and `dashboard`, wrote the whole
state tree — and then the container **exited 0**. The default CMD is the
*interactive* `hermes` CLI; with no TTY it completes and returns 0, and s6-overlay
tears the container down when its main program ends. Under `restart:
unless-stopped` that is a **restart loop reporting success**. `main-hermes` is
explicitly a no-op (`exec sleep infinity`, with a comment saying so); the gateway is
not an s6 service by default. Upstream's `docker-compose.yml` uses
`command: ["gateway", "run"]`, and ✅ with that the container stays up
(`running=true`) with the gateway supervised.

**`hermes cron status` exits 0 even when the gateway is dead.** ✅ Booted with
`sleep infinity` (s6 up, no gateway), `hermes cron status` prints
`✗ Gateway is not running — cron jobs will NOT fire` and **exits 0**. So
`HEALTHCHECK CMD hermes cron status` would report *healthy* while push mode was
dead — the exact silent failure this map exists to kill, reintroduced by the probe
meant to prevent it. **The exit code must never be trusted; parse the output.**

Also ✅: **nothing listens on 9119 or 8642.** The dashboard s6 service starts but
only binds when `HERMES_DASHBOARD` is set, and the gateway API server is off unless
`API_SERVER_KEY` + `API_SERVER_HOST` are set (upstream: *"it stores API keys;
exposing it on LAN without auth is unsafe … do NOT pass `--insecure --host
0.0.0.0`"*). So **no Traefik router for 9119** — there is nothing listening to
route, and opting in would mean weakening it against explicit upstream advice.
Inspection is `docker exec` or an SSH tunnel. This corrects ticket `01`, which
recorded "Gateway API on `8642`" without the off-by-default caveat — an HTTP probe
would have been checking a closed port.

The probe, baked into the derived image:

```dockerfile
HEALTHCHECK --interval=60s --timeout=15s --start-period=120s --retries=3 \
  CMD /usr/local/bin/hermes-healthcheck
```

```sh
#!/bin/sh
# Assert push mode is ALIVE, not merely that the container is up.
# VERIFIED 2026-07-31 on v2026.7.30: `hermes cron status` exits 0 even when the
# gateway is DEAD. The exit code is unusable. Parse the output.
set -u
out=$(hermes cron status 2>&1) || true
echo "$out" | grep -q 'Gateway is running' \
  || { echo "UNHEALTHY: gateway not running"; echo "$out"; exit 1; }
age=$(echo "$out" | sed -n 's/.*Ticker heartbeat: \([0-9][0-9]*\)s ago.*/\1/p')
[ -n "$age" ] \
  || { echo "UNHEALTHY: no parsable ticker heartbeat"; echo "$out"; exit 1; }
[ "$age" -le 180 ] || { echo "UNHEALTHY: ticker heartbeat ${age}s old"; exit 1; }
```

Both assertions are deliberate: the grep catches a dead gateway, the heartbeat bound
catches a gateway process that lives while its 60 s ticker has wedged — cron's actual
failure surface, invisible to "is the process alive". `start-period=120s` because a
cold boot took ~40 s before the gateway reported ready.

**Chosen failure direction, explicitly.** Upstream's cadence is high (six named
releases in ~2 months), so an output-parsing probe is exposed to a reword. But a
reword makes the grep *fail* → unhealthy → a false alarm. Brittleness here produces
noise, never false confidence; the exit code is the opposite — stable, and stably
wrong. Given that choice this map picks noise. One caveat left for `05`: only the
`NNs ago` heartbeat format was observed. If it renders as `2m ago` at longer ages
the parse fails → false alarm, which is the accepted direction, but `05` should
confirm the format rather than inherit the assumption.

`HEALTHCHECK` → docker2mqtt's health entity → MQTT → HA is the existing alert path
(issue `046`). **`05` owns what gets alerted and how loudly; this ticket only
guarantees a probe that cannot report healthy while cron is dead.**

### Hands forward

- **`05`** — the acceptance test above; that `hermes cron status`' exit code is
  unusable; `hermes backup --quick` and `hermes doctor` both exist as building
  blocks; the heartbeat-format caveat; that `SOUL.md` is now placed declaratively so
  "verify it loaded" is a real check; and that there is **no HTTP endpoint** to
  probe unless deliberately enabled.
- **`06`** — `--deliver telegram` is the sanctioned delivery mechanism, which fixes
  ticket `02`'s worst carried-forward defect ("send the briefing to Telegram" as a
  *prompt instruction* is unexecutable because cron disables messaging tools).
  `--no-agent` makes a script's stdout the message verbatim.
- **`07`** — the container sits on the `paperless` network, so `protonmail-bridge:143`
  is reachable by container name; `himalaya` comes from the derived image.
- **`08`** — ✅ `HERMES_WRITE_SAFE_ROOT` is a **`:`-separated list of path prefixes**
  (`agent/file_safety.py:84`), so "narrow" is expressible natively — e.g.
  `/opt/data:/vault/inbox:/vault/journal` — with no bespoke mechanism. The vault
  mounts at `/vault`. Also: `--workdir` injects `AGENTS.md`/`CLAUDE.md` from that
  directory, so a job with `--workdir /vault` picks up the vault charter
  (`~/vault/AGENTS.md`) for free — relevant to the map's "Hermes replaces `/daily`"
  note.
- **New ticket `10`** — ✅ the gateway logs
  `WARNING gateway.run: No env user allowlists configured. Messaging platforms
  default to pairing/allowlist policies and will deny unknown senders unless you
  configure platform allowlists (e.g., TELEGRAM_ALLOWED_USERS=your_id)`. Deny-by-default
  is the shipped posture; the fog patch on Telegram identity is now sharp enough to ticket.
- **New ticket `11`** — the two vault-serve `004` riders (staggered versioning on
  krypton; `.git` in helium's ignore patterns as belt-and-braces).
