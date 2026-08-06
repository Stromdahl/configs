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

## Blocked by

- [018 — Recover the prior-art config](018-recover-prior-art-config.md) — the identity file
  must exist before first boot, and the script shapes inform the volume layout.
