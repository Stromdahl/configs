# The GitHub exit: settleup's image, and public visibility

Type: grilling
Status: claimed
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
