# The GitHub exit: settleup's image, and public visibility

Type: grilling
Status: resolved
Blocked by: 01

## Question

Full migration off GitHub is decided (GitHub goes dark; push-mirroring is a
deferred follow-up). Two threads make that non-trivial, and both need the owner.

**1. `settleup` → GHCR → radon.** Per `~/.dotfiles/issues/023`, settleup's
`.github/workflows/ci.yml` gates on `cargo test`, then publishes
`ghcr.io/stromdahl/settleup` as a **public, anonymously pullable** image — and
**radon runs the service by pulling that image** (`issues/024`). radon is a
public-facing Hostinger VPS and is **standalone by design, not on the NetBird
mesh** (ADR-0002). So when GHCR goes away, radon has no path to a mesh-only
Forgejo registry. Options to put to the owner (ticket 01 reports whether
Forgejo's registry can even serve anonymous OCI pulls):
- radon **builds the image itself** from a git pull — but then radon needs read
  access to the forge, which is mesh-only, and
  `feedback_servers_no_github_key` shows the house style is servers pulling
  public repos read-only.
- the image is **pushed to radon** directly (`docker save` | ssh | `docker load`,
  or a registry on radon).
- **radon joins the mesh** — cleanest technically, contradicts its standalone ADR.
- settleup's repo/image **stays on GitHub** as a deliberate carve-out.

**2. Public visibility.** `issue-tracker` and `specs` are *deliberately public* —
`specs/README.md` names `github.com/Stromdahl/issue-tracker` as that spec's
canonical home, and other repos pin to it. A mesh-only Forgejo means **nobody
outside the mesh can read them**. Is that an acceptable loss (they become private
personal specs), or does something need to stay public? Note `telltaled`,
`lunchlund`, and `finance-track` are also currently on GitHub — establish which of
the six, if any, the owner actually wants readable by others.

**3. Sequencing and the point of no return.** Does the GitHub account get deleted,
emptied, or just abandoned? What is the rollback if Forgejo turns out to be a
mistake three months in? (Cheap insurance: leave the GitHub repos in place,
read-only and unmaintained, rather than deleting.)

Output: a per-repo exit plan plus a decision on radon's image path.

## Amendment (2026-08-23, from ticket 01) — thread 1 is a contradiction, not an open question

Ticket 01 established that **anonymous OCI pull works fine** — that was never the
blocker. The blocker is *where the registry lives*: Forgejo's registry is
**same-origin with the web UI**, and Forgejo offers **no way to expose only `/v2/`**.
So "helium is never public" and "radon anonymously pulls from helium's registry"
cannot both be true. This ticket must **pick an exit**, not explore the question:

1. **radon joins the mesh** — cleanest technically; breaks radon's standalone
   premise and its ADR-0002 edge-host posture.
2. **Images stay on GHCR** — a deliberate carve-out from "GitHub goes dark". Worth
   noting GHCR is a *registry*, not a repo host, so this may cost less against the
   motive than it first sounds.
3. **Push images to radon from krypton** (`docker save` / `skopeo copy` into radon's
   daemon) — no registry pull at all; radon stops needing to reach anything.
4. **A reverse proxy publicly scoping `/v2/` only** — your own work, not a Forgejo
   feature, and it still puts a Forgejo surface on the public internet.

**Two sub-facts that constrain any answer:**
- **Read access follows the *owner's* visibility, not the linked repo's.** A publicly
  pullable image forces a **public owner**, and everything under that owner becomes
  publicly readable. There is no per-repository OCI privacy
  (<https://codeberg.org/forgejo/forgejo/issues/2699>).
- **Prefer user-owned packages over org-owned** — org-owned public packages have had
  access-control bugs (<https://codeberg.org/forgejo/forgejo/issues/972>).

Also: `REQUIRE_SIGNIN_VIEW = true` kills anonymous pulls outright — relevant because
a privacy-motivated instance is exactly the kind that would want it on. Full detail
in [`../assets/01-forgejo-deployment-research.md`](../assets/01-forgejo-deployment-research.md) §6.

### A fifth exit (2026-08-23, from asset 04) — added by another session; see note below

Ticket 04's image-build finding surfaces a shape the four exits above do not cover,
because all four are framed around radon **pulling** from a registry.

**5. radon builds the image where it is consumed.** Ticket 04 recommends the *CI job
image* be built by an ansible task on the host that runs it — a `Containerfile` in
this repo, date/content-hash tagged, digest-pinned — specifically to avoid CI
depending on a registry which depends on the forge being up. The same reasoning
applies to settleup: if radon builds settleup's image from a git checkout during its
own ansible deploy, then **there is no registry pull, no registry to expose, and the
same-origin collision never arises.**

This is **not** exit 3 (`docker save` / `skopeo copy` from krypton — krypton must be
awake and is the only builder) and **not** exit 1 (which buys reachability by putting
radon on the mesh). It is exit 1's *mechanism* — radon fetching source — without the
mesh membership, and it needs only public read access to one repo's source, not to a
registry.

Costs to weigh against the others: radon needs a Rust toolchain and build capacity
it does not currently need (it is a small VPS, and settleup is a Rust build); build
failures move from CI to deploy time, losing the "CI gates the image" property that
`issues/023` deliberately established; and radon still needs *some* read path to the
source, so the public-visibility question in thread 2 stays live rather than being
dissolved.

> **Note for whoever owns this ticket:** this section was appended by a different
> session than the one that claimed 08, because the fact arrived from ticket 04's
> research after 08 was claimed. Nothing else in the ticket was touched.

## Comments

### Claim transferred 2026-08-23 (session `dotfiles-ff` → this session)

The previous claim was stale — the holding session no longer exists. Re-claimed
here; `Status: claimed` is unchanged in value but now means *this* session.

### Premise check 2026-08-23 — the account is far larger than the map says

Re-ran the inventory the dead session lost. Commands, so they can be re-run rather
than re-derived:

```bash
gh repo list Stromdahl --limit 300 --json name,visibility,isFork,pushedAt,isArchived \
  --jq '.[]|select(.isFork==false)|[.name,.visibility,(.pushedAt|split("T")[0])]|@tsv' | sort -k3 -r
# intersect against local checkouts:
for d in $(find ~/projects -maxdepth 3 -name .git -prune); do
  git -C "${d%/.git}" remote get-url origin 2>/dev/null; done \
  | sed 's/.*\///;s/\.git$//' | sort -u
```

Results:

- **78 non-fork repos** (92 including forks) — **not 49**. The map's corrected
  figure was itself low.
- **Only 6 have a local checkout** under `~/projects`: `settleup`, `lunchlund`,
  `telltaled`, `issue-tracker`, `specs`, `finance-track`. **71 exist only on
  GitHub** (72 minus `configs`, see below).
- Visibility: `Stromdahl.github.io`, `configs`, `settleup`, `telltaled`,
  `lunchlund` public; `finance-track`, `issue-tracker`, `specs`, `coinkeep`,
  `lumen` private — confirming the map's correction.
- **The tail is coursework and toy sketches.** ~55 of the 78 were last pushed
  **2023 or earlier** (`IOT20_*`, `Applio*`, `SnakeGame`, `Tetris`, `Fireworks`,
  `Boids`, …) — a KYH/IOT20 study archive plus teenage graphics demos. Nothing
  here is a live dependency; the question they raise is *keep or let go*, not
  *migrate*.
- Genuinely recent and local-less: `Stromdahl.github.io` (2026-08-21),
  `configs` (2026-07-12), `coinkeep` (2026-02-09), `lumen` (2026-02-01).

**`~/.dotfiles` IS a GitHub repo — `Stromdahl/configs`, PUBLIC.** Verified with
`git remote -v` and `gh repo view`. It is not under `~/projects`, so **ticket 06's
survey never scoped it and its 20-repo curation excludes it**. This is the single
most load-bearing repo on the account:

- `bootstrap.sh:21` clones `https://github.com/Stromdahl/configs.git`, and
  `README.md:8` / `install.sh:32` document the fresh-machine entry point as
  `wget -qO- https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap.sh | bash`.
- `modules/ssh/install.sh:5` and `modules/deploy-user/install.sh:9` fetch
  `https://github.com/stromdahl.keys`.
- Its public visibility is *already load-bearing on another decision* —
  `planning/hermes-helium/issues/10-telegram-authorization.md:209` reasons from
  "`Stromdahl/configs` is **PUBLIC**".

So a mesh-only forge cannot serve the bootstrap path: a fresh machine has no mesh
membership until it is provisioned, and it cannot be provisioned without reaching
the dotfiles repo and the keys. **That is a second chicken-and-egg beyond the keys,
and it is why "delete the account" is not currently a reachable option.**

## Answer

**GitHub is not touched. Left as is.** Decided by the owner 2026-08-23, directly and
without qualification. Everything below follows from that.

### 1. The account's fate: abandoned in place

Not deleted, not emptied, not swept read-only. No action is taken on GitHub at all.
Consequences, all of them favourable:

- The **71 repos with no local checkout** need no decision. ~55 of them were last
  pushed 2023 or earlier — the `IOT20_*` / `Applio*` coursework archive and a decade
  of graphics toys. They stay where they are, unmaintained, costing nothing.
- **Public visibility (this ticket's thread 2) evaporates.** `issue-tracker` and
  `specs` remain exactly as readable as today, so `specs/README.md` naming
  `github.com/Stromdahl/issue-tracker` as the canonical home stays true. There is no
  visibility loss to accept, and the map's out-of-scope note about push-mirroring
  "if the loss stings" is moot — nothing is lost.
- **Rollback (thread 3) is free.** If Forgejo proves wrong in three months, every
  GitHub copy is still sitting there. This was listed in the ticket as "cheap
  insurance"; it is now simply the state.

### 2. The carve-out set, and the principle behind it

Four repos stay **GitHub-native**, because GitHub does not merely *host* them — it
**runs** something for them that a mesh-only Forgejo cannot replace:

| Repo | What GitHub runs | Why Forgejo cannot take it |
|---|---|---|
| `configs` (= `~/.dotfiles`) | `bootstrap.sh` + `stromdahl.keys` fetch path | must work **before** the mesh exists — see the chicken-and-egg in Comments |
| `settleup` | Actions CI → `ghcr.io/stromdahl/settleup`, pulled by radon | radon is standalone by ADR-0002, cannot reach a mesh-only registry |
| `lunchlund` | scheduled Actions cron → Pages | needs a public scheduler + public publish target |
| `Stromdahl.github.io` | the live Pages site | needs public hosting |

**The migration boundary is "does GitHub execute something for me", not "is it
public".** That is the decision to carry forward.

This kills the four options this ticket listed for settleup: option 4 ("stays on
GitHub as a deliberate carve-out") wins, and it wins for free — no work, no ADR
violation, no public hosting stood up on radon. `lunchlund`'s hardcoded
`stromdahl.github.io` in 5 source files (including `scrape.ts`'s last-known-good
fallback) is likewise a non-problem: nothing moves, so nothing needs rewriting.

**Everything else that is live moves to Forgejo, and its GitHub copy is abandoned in
place** — stale, harmless, and the rollback.

### 3. Revisiting is explicitly out of scope

The owner: *"might revisit this in the future, but it's out of scope here."* Pulling
any of the four off GitHub — putting radon on the mesh, standing up public hosting,
rebuilding the bootstrap path without GitHub — is a **separate future effort**, not a
later phase of this map. Recorded in the map's Out of scope.

### 4. The destination is narrower than it was written

Stated plainly rather than buried: the map's *"GitHub goes dark — full migration, not
a mirror"* is **false as written**, and the ⚠️ block that qualified it is now
resolved in the *weaker* direction than even that block allowed. What this map
actually delivers is:

> **personal source hosting, ticket tracking, and lumin's deep CI tier move to
> Forgejo. GitHub retains four running services and an untouched archive.**

The honest cost against the stated motive (*"less dependent on bigtech"*): a
permanent, load-bearing GitHub dependency remains at the most critical moment in a
machine's life — first boot — plus a public image registry in the serving path of
the one public-facing host. The owner has seen this and accepted it.

### 5. Residual: `Stromdahl.github.io` is a single-copy artifact

It has **no local clone anywhere under `~/`** (verified). Staying GitHub-native means
GitHub is its *only* copy, which is a standing exception to the map's "two copies is
enough" premise — that premise assumed forge + working clone. Not a decision, and not
worth a ticket: the fix is one command (`gh repo clone Stromdahl/Stromdahl.github.io
~/projects/`) and it graduates as an execution item, not a question. Same applies to
`lunchlund` only in that its clone already exists.

### 6. Riders for other tickets

- **Ticket 06 needs no reopening.** Its 20-repo curation was built blind to 71
  GitHub-only repos, but "GitHub untouched" puts every one of them out of scope, so
  the *outcome* is unaffected. Recorded as an amendment on 06 rather than a
  re-decision. `configs`/`~/.dotfiles` is likewise correctly absent from the 20 — as
  a carve-out, not an oversight.
- **Ticket 07 gains an argument it did not have.** The 56-file homelab tracker in
  `~/.dotfiles/issues/` currently lives inside a **PUBLIC** GitHub repo
  (`Stromdahl/configs`). Moving those issues into a mesh-only Forgejo is a
  visibility *reduction* — a benefit under the stated motive, and the first
  affirmative reason for the migrate side of 07's question 1. Note the mirror-image
  hazard: if maps and issues **stay** markdown in this repo, they stay public, and
  `configs` is a carve-out so that will not change.
- **Ticket 10 (`forge sync`) inherits a hole.** `configs` is GitHub-canonical, so a
  fresh machine's restore is *not* "clone everything from the forge" — the dotfiles
  repo comes from GitHub and the other 20 come from Forgejo. Two sources, and the
  GitHub one is the one that must work first.
