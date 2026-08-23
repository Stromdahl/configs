# The GitHub exit: settleup's image, and public visibility

Type: grilling
Status: open
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
