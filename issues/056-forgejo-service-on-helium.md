---
title: Stand up Forgejo on helium behind the internal Traefik
status: in-progress
priority: high
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

helium gains a private Forgejo instance, reachable over the mesh and LAN only at a
`*.home.stromdahl.tech` subdomain, serving both the web UI and git over SSH. This is
step 1 of the personal-forge migration ordering and everything else in the epic waits
on it: no repos, no tickets, no CI runner until the forge answers.

The persistence spec is settled by personal-forge ticket 11 and must be honoured
exactly, because two of its details fail silently rather than loudly:

- The image is the LTS rootless line, floating across minors and patches rather than
  exact-pinned. That is deliberately against the host-vars house style — patch
  releases on an LTS line are the security fixes you want arriving without a ticket,
  and the thing that needs human verification is the major, which the LTS tag can
  never cross. It wants a comment saying so. Revisit around May 2027.
- The container runs as the stack's existing service uid/gid rather than the image's
  baked-in 1000 (which collides with `ms`). The data directory must be pre-created and
  chowned to that uid/gid **before the compose service ever starts** — with the wrong
  owner the container dies immediately on first boot.
- The bind mount targets the rootless image's data dir, not `/data`. Getting this
  wrong means backups silently cover nothing.
- Configuration is entirely env-var driven. Forgejo needs **no config bind mount at
  all**; the prototype's `/etc/gitea` mount is vestigial and must not be copied.

Git over SSH uses the officially documented container shape: Forgejo's builtin SSH
server published on an alternate host port, with the advertised port set to match so
the clone URLs the UI and API hand out actually work. helium keeps sshd on 22. The
host-sshd `AuthorizedKeysCommand` shim is rejected — it is official for bare metal
only.

Deploys are scoped-tag only; a full play against helium is non-idempotent.

## Acceptance criteria

- [ ] The Forgejo web UI answers over the mesh and over the LAN at its
      `*.home.stromdahl.tech` name, with a valid certificate and no public exposure.
- [ ] The service runs from the floating LTS rootless tag, declared in host vars with
      a comment explaining why it is not exact-pinned.
- [ ] The container runs as the stack's service uid/gid, and the data directory was
      created and chowned before first start (verifiable by the container coming up
      clean on a from-scratch deploy, not just on a re-deploy).
- [ ] The data bind mount targets the rootless image's data dir, and there is no
      config bind mount.
- [ ] `git clone` over SSH succeeds against a test repo using exactly the SSH URL the
      API advertises, with helium's own sshd still serving port 22.
- [ ] The deploy ran with scoped compose tags only.

## Progress 2026-08-24 — code complete, deploy blocked

The service is defined, validated and committed (`0baa708`, `7d5f613`). It has **not
been deployed**: `ansible-playbook site.yml --limit helium --tags compose` was refused
by the session's permission gate, so the deploy needs the owner's hands. Nothing here
is a design question — the remaining work is running that one command.

**Verified without a deploy** (rehearsed locally on `codeberg.org/forgejo/forgejo:15-rootless`,
the exact pinned image, against a bind mount and uid 1001:1003 — the production shape):

- Clean first start in ~2 s; `/api/healthz` returns 200.
- The advertised clone URL is `ssh://git@<SSH_DOMAIN>:<SSH_PORT>/<owner>/<repo>.git`.
  This closes asset 01 §5's open question, which had verified the semantics but not the
  rendered string.
- The builtin SSH server binds 2222 at that uid and answers `SSH-2.0-Go` through the
  published host port, publickey-only. The apparent risk that a uid with no passwd entry
  breaks `SSH_ROOT_PATH`'s `~/.ssh` is **not real**: the image sets `HOME` as a
  Dockerfile ENV, so it resolves independently of `/etc/passwd`.
- `/etc/gitea` is empty in the running container and `app.ini` is at
  `/var/lib/gitea/custom/conf/app.ini` (0600, 1001:1003) — independently confirming that
  no config bind mount is needed.
- Runs clean with `cap_drop: [ALL]`, no `cap_add`, and `no-new-privileges` — verified
  with a genuinely empty capability set (`CapEff`/`CapPrm` all zeros): healthz 200 and
  the SSH server still answering. This matters because the compose header warns that a
  blanket cap drop *breaks* images that start as root and drop privileges; the rootless
  image starts directly as the target uid, so it is in the no-cap_add class.
- The chown is load-bearing, reproduced: with the data dir owned by 1000 the container
  dies with `/var/lib/gitea/git is not writable` → `docker setup failed` → Exited (1).
- `docker compose config` validates the whole rendered stack; ansible `--syntax-check` passes.
- On-LAN DNS is a **wildcard**, so `git.home.stromdahl.tech` needs no OPNsense entry.

**Acceptance criteria ledger:**

- Satisfied by the code: the floating LTS tag + its comment; the rootless data-dir mount
  target and the absence of a config bind mount.
- Code-complete, mechanism rehearsed, awaiting the deploy to confirm: the web UI over
  mesh + LAN with a valid cert; the from-scratch chown ordering; `git clone` over the
  API-advertised SSH URL.
- Genuinely unmet: "The deploy ran with scoped compose tags only" — no deploy has run.

**Capture this on the first run, because it is available exactly once:**
`/data/ssd/appdata/forgejo` does not exist on helium yet, so the first deploy *is* the
from-scratch case. Confirm the container comes up clean on that run — after it exists, the
condition cannot be re-created without deleting state.

**One post-deploy human step**, deliberately not automated (same posture as Jellyfin's and
Audiobookshelf's first-visit admin, and it keeps a single-use credential out of sops):

    docker exec forgejo forgejo admin user create \
      --admin --username <name> --email <addr> --random-password

No `-u` flag: the container already runs as 1001:1003, and `-u 1001` resolves the bare
uid against the container's `/etc/passwd`, which has no entry for it — measured, the gid
falls back to **0**, so files would land `1001:0` in a `0750 1001:1003` dir.

Then create a test repo and run the AC5 clone against the URL the API advertises.

**Expect a possible first-cert stall on AC1, and don't read it as a failure.**
`git.home.stromdahl.tech` is a brand-new router, which is exactly the case in
`project_helium_traefik_acme_restart`: a subdomain can come up serving
`TRAEFIK DEFAULT CERT` because the DNS-01 order is transient and Traefik does not retry
by itself. The fix is a Traefik restart. Worth confirming the existing restart handler
covers a *new router* and not only a `dynamic.yml` edit — if it does not, restart Traefik
by hand once and AC1's "valid certificate" should then hold.

**Sequencing note for whoever picks up `issues/057`:** until 057 deploys, `issues/016`'s
appdata walk still covers this new `forgejo/` dir, so it will file-walk a live WAL-mode
SQLite DB — the exact tearing ticket 11 named and that 057 exists to fix. Blast radius is
near zero today because `063`/`064` have not migrated anything in yet, so this is
sequencing information, not a defect in 056.

## Deploy 2026-08-24 — deployed; 4 of 6 ACs verified on the box

Deployed with `ansible-playbook site.yml --limit helium --tags compose` (scoped tags
only, no full play). The play ended `failed=1`, but the failure is **unrelated to this
issue** — see the note at the end. Forgejo's own two tasks both reported `changed`, and
the compose up completed before the failing task ran.

**Verified on helium:**

- **AC1 (LAN half) — PASS.** `https://git.home.stromdahl.tech/` returns 200 with a real
  Let's Encrypt certificate (`CN=git.home.stromdahl.tech`, issued 2026-08-24). The
  first-cert DNS-01 stall from `project_helium_traefik_acme_restart` **did not fire** —
  no Traefik restart was needed.
- **AC1 (mesh half) — NOT PROVEN, for a pre-existing reason.** helium's mesh IP
  `100.65.22.72` is not reachable from krypton (already recorded before this work). The
  same request forced to the LAN IP returns 200, so the router is correct and only the
  network path differs. Needs one check from an actual mesh peer (phone/roaming laptop).
- **AC3 — PASS, and this was the single-use from-scratch case.** The pre-create task
  reported `changed` (the dir did not exist), the dir is `1001:1003` mode `0750`, and the
  container is `Up (healthy)` with **`RestartCount=0`** — it never crash-looped, so the
  chown genuinely preceded first start.
- **AC4 — PASS.** Exactly one mount: `bind /data/ssd/appdata/forgejo -> /var/lib/gitea`.
  `/etc/gitea` is empty inside the container. `CapEff` is all zeros.
- **AC5 — HALF PROVEN.** helium's own sshd still answers `SSH-2.0-OpenSSH_10.0p2` on 22
  and Forgejo's builtin server answers `SSH-2.0-Go` on 222, both over the LAN. The clone
  itself is still pending: it needs the first admin, a test repo, and a registered key.
- **AC6 — PASS.** Scoped compose tags only.
- **Env-driven config confirmed end to end.** Every setting landed in
  `custom/conf/app.ini`: `SSH_PORT = 222`, `SSH_LISTEN_PORT = 2222`,
  `DB_TYPE = sqlite3`, `PATH = /var/lib/gitea/forgejo.db`, `INSTALL_LOCK = true`,
  `DISABLE_REGISTRATION = true`. The signup page returns 200 but renders "Registration
  is disabled", so the posture is real.

**Already relevant to `issues/057`:** after minutes of life the DB is 1.25 MB with a
**4.1 MB WAL sidecar** — more of its state in the WAL than in the main file. That is
precisely the condition under which `016`'s naked file walk produces a torn,
unrestorable copy, and `016` still covers this dir until 057 excludes it.

**The play's `failed=1` is not this issue's.** `Ensure the urgent-interrupt cron job
exists (hermes-helium 022)` failed `rc=127` with `--name: command not found`. Cause: its
`cmd: >-` folded block indents the `docker exec ... cron create` continuation lines
*more* than the surrounding lines, and YAML preserves newlines for more-indented lines in
a folded scalar — so the flags become separate shell commands. Pre-existing latent bug,
unrelated to Forgejo, triggered whenever the `else` branch runs. Filed separately rather
than fixed here.
