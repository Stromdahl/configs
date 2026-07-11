---
title: Retire neon's old docker-host server role from the repo
status: in-progress
priority: medium
created: 2026-07-11
closed: null
labels: [epic:neon-gaming, wayfinder:task]
---

## Description

Remove the git-push deploy pipeline and docker-host framing that neon carried as a
homelab server, now that the workload (Jellyfin + *arr) retired to helium
(`issues/009`). neon is becoming a personal gaming desktop; its server identity does
not return.

Prune, after confirming helium has fully taken over the workload:
- neon's `servers/` service tree (docker-compose stack, `deploy.sh`, `config.env`,
  sops-encrypted `secrets.env`).
- neon's **git-push deploy pipeline** — the `deploy` user, the bare repo + its
  post-receive hook, and the sparse-checkout that landed `servers/neon/` on the box.
  neon is no longer a push remote target.
- neon's entry in `.sops.yaml` `creation_rules`. If removing the rule changes the
  recipient set of any still-encrypted file, run `sops updatekeys` on the affected
  files so they remain decryptable.

Touches `servers/` and `.sops.yaml` — a **distinct file set** from `issues/035`
(`hosts/neon/`), so the two can run in parallel. Depends on `issues/009` (workload
already migrated; done). Pure in-repo work.

## Acceptance criteria

- [ ] neon's `servers/` service directory is removed; nothing in the repo still deploys to a neon docker host.
- [ ] `.sops.yaml` carries no neon server creation-rule, and every remaining encrypted file still decrypts (verified — `sops updatekeys` run where the rule change touched a file).
- [ ] No deploy-pipeline reference to neon remains (no push remote, no post-receive path, no monorepo deploy doc pointing a git push at neon).
- [ ] `git grep` for neon's docker-host / Jellyfin framing surfaces only historical commits or the new gaming-desktop references — no live server config.
