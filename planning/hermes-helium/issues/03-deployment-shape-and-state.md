# Decide the deployment shape and state placement on helium

Type: grilling
Status: open
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
