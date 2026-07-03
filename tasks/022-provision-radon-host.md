# Task 022 — Provision radon via Ansible — the first edge host (base + docker)

**Source issue:** `issues/022-provision-radon-host.md` — bring an existing
Hostinger VPS (Debian 13) under the fleet's Ansible control layer as the first
member of the `edge` group: hardened `base` role + Docker, pushed from krypton
over SSH as the cloud-init `debian` user. Deliberately standalone — **no** NetBird
mesh, **no** storage roles, minimal at-rest secrets.

> **Depends on `issues/027` (DONE ✓)** — the `edge` group, the `edge` play in
> `site.yml`, and the host-agnostic `base` role already exist. Nothing structural
> to build here; this task just *adds the host* and runs the existing play. Can run
> in parallel with `issues/021` (zone/cert) and `issues/023` (done).

## Pickup protocol

Repo convention is `tasks/README.md` + `issues/README.md` — follow them.
1. **Claim:** set `issues/022` `status: in-progress`, commit on `main` immediately.
2. Do the work per this brief (grep the anchors).
3. **Verify** before committing — run the Verify block; a **second** `--limit radon`
   run must report `changed=0`. Only then commit (atomic).
4. **Close:** set `status: done` + `closed: <date>`, commit on `main`.
5. Blocked on the user's hands? Flag the **issue** and stop.

Carries **`needs-human`** — see blockers below (the VPS must exist and be
key-reachable; SSH is hardened over the public internet, so key access is
load-bearing).

## Suggested agent

**Sonnet** — mechanical: one inventory entry, one sops file, a scoped playbook run
against roles that already exist. No hard reasoning. The one care-point is not
locking yourself out while hardening SSH over the public internet (mitigated by the
pre-flight key check + Hostinger console break-glass below).

## Human steps / blockers (`needs-human`)

- **The VPS must exist and be reachable.** Confirm the Hostinger VPS is up on Debian
  13 and note its **public IP**.
- **Pre-flight the SSH key — BEFORE any run.** `ssh debian@<ip> true` must succeed
  key-only from krypton. The `base` role disables password auth *and* root login; if
  krypton's key isn't in `debian`'s `authorized_keys` first, the run locks you out.
  The `base` role does **not** manage `authorized_keys` — it relies on the existing
  cloud-init key. Keep **Hostinger's web console / VNC** open as break-glass during
  the first run.
- **Sudo mode → the become secret.** On the box run `sudo -n true`:
  - **passwordless sudo** (per the PRD) → there is **no** become password to store;
    skip the sops file. Note on the issue that AC5's "become password from sops"
    demonstrator is **deferred to `issues/024`** (the origin-cert key becomes radon's
    real first sops secret). Do not fabricate a password.
  - **sudo needs a password** → mint `host_vars/radon/secrets.sops.yml` holding
    `ansible_become_password` (see Entry points). This satisfies AC5 directly.
- **Do NOT join NetBird / add any mesh config.** Isolation is the whole point.

## Decisions baked in (read before coding)

- radon inherits, with **zero per-host vars**: `base_hostname` = `inventory_hostname`
  = `radon` (the `base` role renames the box on the run), `base_timezone` =
  `Europe/Stockholm` (`group_vars/all.yml`), and `docker_users` = `["{{ ansible_user }}"]`
  = `debian` (`group_vars/all.yml`). So `host_vars/radon/vars.yml` is essentially
  empty — you mainly add the **inventory entry** and (maybe) the **secret**.
- **radon is genuinely idempotent, unlike helium.** The edge play runs base + docker
  only — **no `compose_stack`**, so the `ufw` ⊕ `iptables-persistent` conflict from
  `issues/028` does **not** apply here. ufw installs and *stays*. A clean second run
  really should report `changed=0`.
- **No new sops rule.** The rule `^ansible/(host_vars|group_vars)/.*\.sops\.ya?ml$`
  (admin key only) already matches `host_vars/radon/secrets.sops.yml`. AC6 holds.

## Entry points (edit — grep-stable)

- `ansible/inventory/hosts.yml` — grep the **`edge:`** block (currently `hosts: {}`).
  Replace `{}` with a `radon:` host: `ansible_host: <public IP>`, `ansible_user: debian`.
  Mirror the `helium:` entry under `nas:` for shape.
- `ansible/host_vars/radon/secrets.sops.yml` — **NEW** (only if sudo needs a
  password). Mirror `ansible/host_vars/helium/secrets.sops.yml` (leads with
  `ansible_become_password:`). Create it **without printing the secret to the
  terminal** — use the sops editor or stdin redirect per the snippet in
  `ansible/README.md` (§ Secrets). Encrypts with the admin age key already on krypton.
- `ansible/host_vars/radon/vars.yml` — create **only** if a real radon-specific plain
  var emerges; for base+docker there should be none.

## Prior art to mirror

- `ansible/host_vars/helium/` — the `vars.yml` + `secrets.sops.yml` pairing and the
  become-password secret shape.
- `ansible/site.yml` — grep **`Bring edge hosts`**: the `edge` play (roles `base` +
  `geerlingguy.docker`) already exists from `issues/027`. **Nothing to add there.**
- `ansible/README.md` § Secrets — the exact sops create-without-echo commands.

## Steps

1. Claim `issues/022` (status in-progress; commit on `main`).
2. Confirm `ssh debian@<ip> true` works; check `sudo -n true` to pick the become path.
3. Add `radon` to the `edge` group in the inventory (`ansible_host`, `ansible_user: debian`).
4. If sudo needs a password: mint `host_vars/radon/secrets.sops.yml` (`ansible_become_password`) via sops.
5. Run: `cd ansible && ansible-playbook site.yml --limit radon`.
6. Re-run the same command; confirm `changed=0` (idempotent).
7. Run the Verify block, tick every AC, commit the change, then close the issue.

## Verify (exact commands, run from `ansible/`)

- **Idempotent:** second `ansible-playbook site.yml --limit radon` → PLAY RECAP `changed=0`.
- **Membership:** `ansible-inventory --graph edge` shows `radon`.
- **Hostname:** `ansible radon -a "hostnamectl --static"` → `radon`.
- **SSH hardened:** `ansible radon -b -m shell -a "sshd -T | grep -iE 'permitrootlogin|passwordauthentication'"`
  → `permitrootlogin no`, `passwordauthentication no`.
- **ufw:** `ansible radon -b -a "ufw status verbose"` → default deny incoming; only 22/80/443 allowed.
- **fail2ban:** `ansible radon -b -a "fail2ban-client status sshd"` → jail active.
- **unattended-upgrades:** `ansible radon -b -a "systemctl is-enabled unattended-upgrades"` → enabled.
- **Docker + compose:** `ansible radon -b -a "docker run --rm hello-world"` succeeds;
  `ansible radon -a "docker compose version"` prints v2.
- **become via sops (if applicable):** the run escalated using the sops-decrypted
  password with no age key copied to the box.
- **Minimal footprint / no mesh:** `ansible radon -b -m shell -a "ls ~/.config/sops/age/keys.txt 2>/dev/null; ls -d ~/.dotfiles 2>/dev/null; ls /etc/netbird 2>/dev/null; ip -o link show wt0 2>/dev/null; echo ok"`
  → none of the age key / repo clone / netbird config / `wt0` present.

## Acceptance criteria (from issue 022, verbatim)

- [ ] radon (an existing Hostinger VPS, Debian 13) is a member of the `edge` inventory group; a playbook run from krypton over SSH applies cleanly and is idempotent on a second run.
- [ ] The host's hostname is `radon`; SSH is key-only; root login and password auth are disabled.
- [ ] ufw is default-deny allowing only 22/80/443; a fail2ban sshd jail is active; unattended security upgrades run.
- [ ] Docker engine + compose v2 are installed from the official repo (`docker run hello-world` succeeds; the compose plugin is present).
- [ ] radon's become password is decrypted from sops at run-time by the admin key and consumed without any age key landing on the box.
- [ ] radon holds no per-host age key, deploy key, GitHub key, or repo clone; no new sops creation-rule was added.
- [ ] radon is not a NetBird peer and carries no mesh or storage roles.

## Out of scope / don't touch

- **NetBird / mesh join** — explicitly excluded; isolation is radon's reason to exist.
- **Storage roles** (`storage_hdd`/`storage_ssd`), **`compose_stack`**, **`restic_backup`** — nas-only; radon gets none.
- **`edge_stack` / Traefik / Cloudflare Origin cert / settleup** — that's `issues/024`.
- **The `issues/028` ufw fix** — nas-only; do **not** add `iptables-persistent` to radon.
- **Cloudflare zone / DNS / Origin cert** — `issues/021`.
- **`authorized_keys` management** — the `base` role doesn't touch it; radon uses the existing cloud-init key.
