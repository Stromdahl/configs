# 019 — Hermes boots healthy on helium, provisioned by ansible

Type: execution
Status: open
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: [018](018-recover-prior-art-config.md)

## What to build

A Hermes container that runs on helium, comes back after a reboot, and **reports its own
health honestly** — the foundation every later ticket stands on. No vault, no Telegram, no
scheduled work yet: just a service that is either genuinely up or visibly not.

Shape, all settled in ticket `03`:

- **A compose service in helium's existing single stack**, from a **derived image** built on
  the pinned upstream digest — the same pattern the Proton bridge service already uses. The
  derived image is also where extra binaries absent upstream get pinned.
- **Pinned by digest, never by a floating tag.** ⚠️ The convenience tag is **main HEAD**, not
  the newest release — CI tags it on every commit to main — and the project shipped six named
  releases in about two months.
- ⚠️ **Set the gateway command explicitly.** The image's default command is the interactive
  CLI, which **exits 0**; under a restart policy that is a restart loop that reports success.
- **Runs as uid/gid 1000 via the image's own environment variables.** ⚠️ Passing a user flag
  is rejected by the image outright.
- **State on the SSD app-data path**, so the existing restic backup already covers it.
- **One sops-fed environment file inside the state volume** carries every secret. ⚠️ It is
  load-bearing that it lands there: `010` verified the gateway reads its allowlist with a bare
  environment lookup, so a missing file means defaults, not an error.
- **Helper scripts are copied onto the state volume by ansible, never baked into the image** —
  a bind mount masks baked-in paths, and the loader rejects a symlink resolving outside its
  root.
- **No published ports, no reverse-proxy router, no HTTP probe** — the API server and
  dashboard are both opt-in and nothing listens by default.
- **The identity file recovered in `018` is in place at first boot**, and asserted on by
  **content** rather than existence.

**The healthcheck is the real deliverable here.** It must **parse output, never exit codes** —
`03`, `05` and `10` each measured a different command that **exits 0 while printing
failure**: the scheduler status command with a dead gateway, the doctor command with failures,
and the gateway status command with the gateway down. 🔴 It must also bound the **last
successful** scheduled tick, not merely the heartbeat: as first specced it reported healthy
when no scheduled run had **ever** succeeded. False alarms during an upgrade are the correct
failure direction.

⚠️ **What "healthy" means in this ticket, since the credentials arrive in `020`.** `03`
established the state directly: without secrets you get *"gateway up, no provider, no
Telegram"* — a Hermes that **boots and cannot talk to anything**. So this ticket's blockers are
`018` alone, and its demo is legitimate without `016`/`017`. But `03` also names that state as
*"exactly the sort of plausible-looking half-success this map exists to catch"* — so **health
here is defined as the scheduler ticking successfully, never as "the container is up"**. Do not
let this ticket close on a container that runs and does nothing; that is the shape of the
restart loop that reports success.

## Acceptance criteria

- [ ] An ansible run provisions the service from scratch; a **second run reports no changes**.
- [ ] The running container's image resolves to the **intended digest**.
- [ ] The container is healthy, and stays healthy across a host reboot.
- [ ] The healthcheck reports **unhealthy** when the scheduler has never had a successful run.
- [ ] The healthcheck reports **unhealthy** for each of the three measured exit-0-with-failure
      command outputs, fed as recorded fixtures.
- [ ] Secrets decrypt into the environment file inside the container and are readable by the
      service; none are in plaintext in git.
- [ ] The identity file's anti-fabrication rules are present **by content** — asserting on
      existence alone is explicitly not sufficient.
- [ ] Nothing listens on a published port.
- [ ] Helper scripts are present on the state volume and were placed there by ansible.

## Progress (2026-08-11)

Code written and verified against the pinned digest on krypton (Docker present locally); **not
yet deployed to helium** — that step is ask-first (see map Notes on risky/production actions).
Ansible role changes: `hermes_data` in `host_vars/helium/vars.yml`, the compose service block
+ build tasks in `tasks/stack.yml`/`docker-compose.yml.j2`/`stack.env.j2`, and
`files/hermes-agent/{Dockerfile,hermes-healthcheck}`.

🔴 **The healthcheck design in this ticket's own body is superseded — don't build the script as
first drafted above.** [Ticket 05](05-loud-failure-verification.md)'s D3 item 2 replaces the
`cron status`-parsing probe entirely: `cron/jobs.py` (read from the pinned image, not assumed)
shows `ticker_last_success` is a **separate file**, bumped only when a tick completes without
raising, independent of whether any job was due. Verified empirically on a throwaway boot with
**zero cron jobs configured**: the file appears on the first tick regardless. So the shipped
healthcheck reads that file directly (age-bounded, 180s) and never shells out to `hermes cron
status`, `hermes doctor`, or `hermes gateway status` at all — a single file-age check subsumes
all three of this ticket's "exit-0-with-failure" cases (dead gateway, wedged-but-ticking, and
never-succeeded all show up as a stale-or-missing file), so there is nothing left for those
three commands' exit codes to fool. Four fixture cases tested directly against the built image:
healthy, missing file, stale file (200s), corrupt content — all four resolve correctly, and
`docker inspect` on the built image's own `HEALTHCHECK` reports `healthy`.

Two acceptance boxes above are **not applicable at this ticket's scope**, not overlooked:

- *"Secrets decrypt into the environment file... none are in plaintext in git"* — vacuously
  true. No secret exists yet ([016](016-acquire-anthropic-api-key.md)/
  [017](017-acquire-telegram-identity.md) are needs-human and still open), so there is nothing
  to decrypt. `020` is where this becomes a real check.
- *"Helper scripts are present on the state volume and were placed there by ansible"* — no
  gathering script exists until `022`. Per [ticket 03](03-deployment-shape-and-state.md), "the
  derived image's job shrinks to exactly three things: the digest pin, himalaya, and the
  healthcheck script" — the healthcheck is baked into the **image**, not placed on the
  **volume**, which is the mechanism this bullet describes. `SOUL.md` is on the volume and IS
  placed by ansible, if that's what this was meant to cover.

Also: `networks:` deliberately **omitted** from the compose block (no `paperless` membership) —
this ticket needs no container-to-container reachability, and joining that bridge now would
couple hermes-agent's recreate lifecycle to every paperless-family container change for no
current benefit. `025` adds `networks: [paperless]` when `himalaya` needs
`protonmail-bridge:143`.

**Still owed, and untestable from krypton:** the actual `ansible-playbook site.yml --limit
helium --tags compose` run, a second run reporting no changes, survival across a host reboot,
and confirming nothing new is listening (`ss -tlnp`) on the real box.

## Blocked by

- [018 — Recover the prior-art config](018-recover-prior-art-config.md) — the identity file
  must exist before first boot, and the script shapes inform the volume layout.
