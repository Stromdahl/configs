# The `forge sync` contract

Type: grilling
Status: closed
Blocked by: 01

## Question

A restore command is in scope: the half that makes "helium has my code" a tested
fact rather than a belief. It reads the forge's repo list and reconciles it with
`~/projects`.

Settle its contract with the owner (`/grilling`), using ticket 01's findings on
the Forgejo API and auth model:

1. **Directions.** Which of these does it do?
   - **Clone missing** — repos on the forge that are not on this machine (the
     fresh-laptop restore case).
   - **Fetch existing** — pull down what was pushed from elsewhere.
   - **Report drift** — local repos **not** on the forge. This is the one that
     catches the real failure mode: a repo created six months from now and never
     pushed. It is also the only direction that needs no network write.
   - **Push** — actually create and push the missing ones, or just name them?
2. **Read-only by default?** Recommendation: yes — report and clone, never push or
   delete without an explicit flag. A sync tool that force-pushes is a foot-gun,
   and this one runs on a machine holding the only other copy.
3. **Where it lives.** `~/.dotfiles/bin/` alongside the other wrappers, per
   `feedback_extend_wrapper_first`. Name, language (bash + `curl`/`jq` vs
   something typed), and whether it needs a config file or reads everything from
   the forge.
4. **Auth.** A Forgejo API token on krypton — where does it live? (sops-encrypted
   in the repo, `pass`, or a plain file in `~/.config`?) Note the house rule:
   `feedback_sops_no_stdout`.
5. **Name aliases (from [ticket 06](06-repo-curation.md)).** `sync` **cannot
   assume `dir name == repo name`**: 06 renamed two repos on the forge only —
   `dockerstats`→`docker-tools` and `diy-speekers`→`diy-speakers` — leaving the
   local directories untouched. So it needs a two-entry alias map alongside the
   ignore list, or it will report both as drift forever *and* clone them into
   new directories on a fresh machine.

6. **What it does about the exclusions.** Ticket 06 rules out **far more than the
   Marlin clones** — see its *Excluded, and why* table for the authoritative list:
   all 12 repos under `playground/`, 5 zero-commit `git init`s (incl. `keyerr`),
   7 upstream clones (Marlin pair + `vendor/*`), `rssfeed`, and
   `homelab-stack.archived`. Do **not** build the ignore list from this line.
   Does `sync` know about them, or does it
   report them as drift forever? An ignore list of some kind is probably needed.
7. **Archived repos.** A repo archived on the forge (ticket 06) — does `sync`
   clone it onto a fresh machine, or skip it?

Output: a precise enough contract that building it is execution, not design.

## Amendment (2026-08-23, from ticket 01)

**A hard coupling to put in this ticket's acceptance criteria:** if Forgejo's SSH is
published on a non-standard host port (helium keeps sshd on 22, so it will be), then
**`SSH_PORT` must be set to match** — otherwise Forgejo's API hands `forge sync` a
clone URL that does not work. `forge sync` is precisely the consumer that would trip
over this, since it reads clone URLs from the API rather than being told them.

Related, and **unverified**: the exact rendered form of that URL (scp-style
`git@host:owner/repo.git` vs `ssh://git@host:222/owner/repo.git`). It changes how
`forge sync` parses, so confirm it empirically on first deploy rather than assuming.

Also confirmed by 01: the API is **fully sufficient** for this command, and
**read-only token scoping exists** — which supports the read-only-by-default posture
recommended in question 2. See
[`../assets/01-forgejo-deployment-research.md`](../assets/01-forgejo-deployment-research.md) §5, §8.

## Amendment (2026-08-23, from ticket 03)

**The owner string is fixed, so question 3 is unblocked.** Ticket
[06](06-repo-curation.md) settled a **single organisation** holding all 20 repos
(name `projects` *recommended*, fixed at creation) — so `owner` is one knowable
constant for `forge sync` to hold, not something to parse per repo,
and every clone URL carries the same path segment. Ticket 03 §3 independently
*corroborates* that choice: the web dashboard's label picker is only populated in an
**org** context (`GetLabelsByOrgID`), so a user namespace would have shipped a
cross-project issue view with no working label filter.

**This wrapper may have a second job.** Ticket 03 §7 found Forgejo has **no
CLI** — no `gh`/`glab` analogue — so `issue-tracker-forgejo.md` is either a raw-HTTP
cookbook or a cookbook for exactly this wrapper. Decide here whether `forge` is
sync-only or becomes the single Forgejo transport (`forge issue list`, `forge issue
close`), because that changes its language, its auth handling, and its output
contract. If it grows issue verbs, the six API footguns in 03 §4 (`type=issues` on
every list; `PATCH {"state":"closed"}`; labels-by-ID on create; no `labels` on PATCH;
assignees replace; no `@me`) belong inside the wrapper, not repeated in prose in
every skill. The map's `feedback_extend_wrapper_first` note points the same way.

Useful, and free: 03 confirms **no rate limits** in any primary source, and
pagination caps at **50** items with `x-total-count` + RFC-5988 `link` headers — so
`forge sync` must paginate, but need not throttle.

## Rider (2026-08-23, from ticket 08) — restore has two sources, not one

Ticket 08 resolved as **GitHub untouched, with four GitHub-native carve-outs**. One of
them is **`configs` (= `~/.dotfiles`) itself**, because `bootstrap.sh` and the
`github.com/stromdahl.keys` fetch must work *before* a fresh machine has mesh
membership.

So `forge sync` is **not** "clone everything from the forge":

- **`~/.dotfiles` comes from GitHub** (`https://github.com/Stromdahl/configs.git`, per
  `bootstrap.sh:21`) — and it is the source that must work **first**, since it is what
  installs the mesh that makes the forge reachable at all.
- **The 20 curated repos come from Forgejo**, over the mesh, after provisioning.
- `settleup` and `lunchlund` are also GitHub-canonical carve-outs, so if `forge sync`
  restores them it must know to use their GitHub remotes.

Two consequences for this ticket's contract: `forge sync` **cannot be the first thing
that runs** on a fresh machine (it presupposes `bootstrap.sh` + the mesh), and its
per-repo record needs a notion of **which host is canonical** rather than assuming the
forge. Also note `Stromdahl.github.io` has **no local clone at all** — if `forge sync`
is meant to be "restore everything I own", that repo is currently outside its reach.

## Answer — SHELVED (out of scope), 2026-08-23

**Not resolved: ruled out of scope.** The owner, asked to settle the direction set:
*"we can shelf this until we need it."* So `forge sync` is not designed here and is
not built as part of this effort. This is a **scoping act, not a step on the route** —
it is recorded in the map's *Out of scope*, never in *Decisions so far*.

It narrows the destination. The map's destination line named `forge sync` explicitly
(*"plus the decisions needed to ... restore every repo onto a fresh machine (`forge
sync`)"*), and the charting premise *"organize = hosting/backup + curation + a
`forge sync` restore command"* named it too. Both are amended: this effort now
delivers hosting, curation, the tracker and CI — **not** a reconcile/restore command.

### Three consequences, so nobody re-derives them

1. **The migration is not stranded.** Standing the forge up still needs something that
   creates 20 repos and pushes them for the first time — but that is the one-shot
   migration script [ticket 07](07-tracker-cutover.md) already assumes, not `sync`.
   Different tool, different lifetime: one runs once, the other would run forever.
2. **`bin/forge` still gets built.** Ticket 07 settled that the whole toolchain moves
   and that `issue-tracker-forgejo.md` is a cookbook *against `bin/forge`*. Shelving
   `sync` shelves a **subcommand**, not the wrapper. The `forge` vs `forge sync`
   distinction matters: 03's amendment asked *this* ticket to decide sync-only vs
   single-transport, and 07 had already answered transport.
3. **The accepted cost.** "helium has my code" stays a belief rather than a checked
   fact, and nothing will notice a repo created later and never pushed — the exact
   state 29 repos in `~/projects` are in today. Knowingly accepted; recoverable at any
   time, and cheap to pick up because the facts below are banked.

### Facts measured before the shelving — banked, do not re-derive

All five were premises this ticket flagged as unverified. Measured against the ticket-05
prototype (Forgejo 15.0.7). Re-runnable:
[`../assets/10-forge-api-probes.sh`](../assets/10-forge-api-probes.sh).

- **Clone-URL rendering (this ticket's flagged unknown, now closed).** With SSH off
  port 22 — helium's case, since it keeps sshd on 22 — the API renders the **URL form**
  `ssh://git@host:2222/projects/repo.git`, **not** scp-style `git@host:owner/repo.git`.
  A port-22 deployment would render scp-style, so any future parser should accept both.
  The `SSH_PORT`-must-match coupling from 01's amendment survives and now belongs to
  whoever writes the deployment, not to a shelved tool.
- **Read-only token scoping is enforced server-side, not advisory.** A token scoped
  `read:repository,read:organization`: list `200`, create `403`, delete `403`. So
  read-only can be a property of the **credential** rather than of a `--dry-run` flag.
- **An API token works as an HTTP git credential.** Private repos clone with it;
  anonymous clones are refused. **Archived repos clone fine** (`oppen`, 22 commits) —
  Forgejo's archive flag is a **push-only** restriction, which pre-answers this
  ticket's question 7 whenever it returns.
- **The credential-leak trap.** git **persists an embedded HTTP credential verbatim
  into `.git/config`** as `remote.origin.url` (verified by grep). So "clone over HTTPS
  with the token in the URL" would write the forge token in plaintext into ~20
  `.git/config` files on a fresh machine. HTTPS-vs-SSH is therefore a **real trade**,
  not "HTTPS is obviously simpler": HTTPS needs no published SSH port and no host-key
  trust, but forces a credential-storage decision (`credential.helper`, `~/.netrc`, or
  `url.<base>.insteadOf` with clean remotes), whereas SSH keeps the credential in the
  one agent-backed place this repo already has a documented policy for.
- **Pagination**: `X-Total-Count` + RFC-5988 `Link` (`rel=next`/`last`); confirmed
  against 03's "cap 50, no rate limits".

### Two findings that shrank the ticket, from ground truth

- **The ignore list is 4 entries, not 26.** Surveyed `~/projects` (24 top-level git
  repos + 4 non-git dirs): **`playground` and `vendor` are not git repos at depth 1** —
  their 17 repos are nested one level down. So a **depth-1 scan** (`~/projects/*/.git`)
  never sees them, and `rssfeed`/`hermes` are skipped for free. The whole exclusion set
  collapses to **`keyerr`, `marlin-ender3`, `marlin-configs`,
  `homelab-stack.archived`** — and the other 20 top-level git dirs *are* exactly ticket
  06's twenty. This ticket's question 6 (*"do not build the ignore list from this
  line"*) was answering a harder problem than the filesystem poses.
- **`~/.dotfiles` is not under `~/projects`**, so the two-source restore in 08's rider
  is structurally clean: `bootstrap.sh` fetches `configs` from GitHub and nothing that
  walks `~/projects` can see it. `telltaled` *does* have a GitHub remote (it is one of
  the 6 local checkouts), which 06 recorded separately from its "already on GitHub (5)".

### One question this ticket was carrying that is now unowned

**Is the token read-only or writeable?** Ticket 07 made `forge` the tracker transport,
so `forge issue close` needs **write** scope — and the P2 measurement proves scope is
enforced, so a single read-only token cannot serve both legs. The choice (two tokens
vs one write token with read-only-ness as policy) now belongs to whoever builds
`bin/forge`, and there is a **house pattern to follow**: `bin/ha` and `bin/unifi` both
read a plain JSON token file from `$HOME` (`~/.ha-token.json`, `~/.unifi-token.json`;
`~/.ha-token.json` is mode 0644 today, which is worth tightening for a forge token).
Note **`pass` is not installed** on krypton and there is no `~/.password-store`, so the
ticket's `pass` option was never available; sops+age *is* present. Not a decision for
this map — recorded so the build issue does not rediscover it.
