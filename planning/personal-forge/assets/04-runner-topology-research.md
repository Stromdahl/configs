# Runner topology for lumin's deep tier — findings

Research asset for [`issues/04-runner-topology.md`](../issues/04-runner-topology.md).
Written 2026-08-23. Reading and reasoning only — **nothing was deployed, and
helium was not touched**. Every claim is either a verbatim quote from a primary
source (Forgejo docs, the `forgejo/runner` repo at code.forgejo.org, Forgejo
source on codeberg) with its URL, or an explicitly-labelled inference.

Builds on, and does not re-derive, two findings from
[ticket 02](02-lumin-deep-tier-feasibility.md):

- the smoke gate runs **genuinely headless** (`WLR_BACKENDS=headless` +
  `WLR_RENDERER=pixman` creates no session and opens no DRM node), so the runner
  needs **no `/dev/dri`, no libseat/seatd, and no privileged container** for it;
- the perf gate is **single-threaded** (Valgrind serialises guest threads) and
  the mutants gate is **serial and build-bound** (85% `cargo build`). Deep tier
  is **~25–40 min warm, 60–90 min cold**. **Caching matters more than
  parallelism.**

> **Version pinning for the quotes below.** Runner quotes are from `main` at
> `code.forgejo.org/forgejo/runner` (binary self-reports `v13.0.0`); docs quotes
> are from `forgejo.org/docs/latest/`, which currently serves **v16.0**. The map
> pins Forgejo **`:15-rootless`** (ticket 01), so where a doc statement is
> version-sensitive it is flagged. **The runner↔Forgejo version compatibility
> matrix is not published anywhere I could find — unverified.**

## Verdicts at a glance

| # | Question | Verdict |
|---|---|---|
| 1 | Runner basics; GitHub Actions compatibility | **Works.** Compatibility is worse than "no guarantee" — non-compatibility is a stated *design goal*. Workflows live in `.forgejo/workflows/`; `.github/workflows/` is a **fallback, not a union**. |
| 2 | Docker vs host runner, given ticket 02 | **All four backends can run every gate.** Ticket 02 removed every hard requirement, so this is a pure confinement/provenance choice, not a capability one — see §2 and §5. |
| 3 | Pinned toolchain + cargo/target caching | **Bake the toolchain into a purpose-built Debian 13 image; do NOT use `actions/cache` for `target/`.** A built-in cache server exists and works, but tarballing a multi-GB `target/` is worse than a bind-mounted `CARGO_HOME` + `CARGO_TARGET_DIR` via `container.valid_volumes`. |
| 4 | How the verdict comes back | **Better than expected.** Actions tab, per-job commit statuses on push/PR, a real badge endpoint, **and a first-party opt-in failure email** (`enable-email-notifications: true`). This closes the map's "CI failure notification" fog item. |
| 5 | **Where the runner lives and how it is confined** | **Privileged DinD is the documented *default*, not a requirement.** Recommended: **host runner as an unprivileged systemd unit + rootless Podman + `docker://`-scheme labels**. Six options costed in §5. |

**The single most load-bearing finding:** the runner's label grammar has a
`host` scheme and an `lxc` scheme alongside `docker`, and the runner supports
**rootless Podman as a first-party documented configuration on Debian 13
trixie**. Ticket 01's "the documented default runner shape is a privileged
docker-in-docker daemon" is accurate about the *default* and misleading about the
*requirement*. That is what unblocks this ticket.

---

## 1. Forgejo Actions runner basics

### 1.1 Registration — the `register` subcommand is deprecated

`register` still exists but the runner logs a deprecation warning
(`internal/app/cmd/register.go`, verbatim):

```
log.Warn("`register` has been deprecated; declare connections in the runner configuration instead")
```

and `internal/app/cmd/cmd.go` declares it `Short: "Register a runner to the server (deprecated)"`.
<https://code.forgejo.org/forgejo/runner/src/branch/main/internal/app/cmd/cmd.go>

**The current path** (<https://forgejo.org/docs/latest/admin/actions/registration/>),
verbatim:

> "Forgejo Runner requires a `uuid` and `token` to connect to Forgejo. These
> values act as a username and password for identifying and authenticating the
> connection."
> "The `Create new runner` button opens a dialog to enter a name and description
> for the runner"
> "The displayed configuration should be copied into the Forgejo Runner
> configuration file, in the `server` section."

```yaml
server:
  connections:
    forgejo:
      url: https://git.home.stromdahl.tech/
      uuid: 33834eef-e758-48c4-a676-1745426747aa
      token: d4fe2db46a4c6bdc434a9ce3378d9a1489c1b30e
```

The config file also carries `runner.file: .runner` — "Where to store the
registration result."

**Practical consequence for an ansible-provisioned runner:** the uuid/token are
minted by the *running Forgejo* and pasted into config. That is a
**needs-human first-deploy step**, exactly like the Immich/Paperless/Cleanuparr
admin identities already in `secrets.sops.yml`. There is an offline alternative
that avoids the web UI:

> "The `forgejo forgejo-cli actions register --secret <secret>` subcommand can be
> used to register the runner with the Forgejo instance. First, generate a
> 40-character long string of hexadecimal numbers."
> "The 40-character secret is a combination of an identifier and a secret value:
> the first 16 characters will be used as an identifier for the runner, while the
> rest is the actual secret."

**That is the one to prefer here**, because it makes the token a *machine-minted
sops secret* rather than a copy-paste from a web page — the same shape as
`restic_repository_password`. **Two unverified caveats before relying on it:**
the only example given is `--scope myorganization`, and **whether `--scope`
accepts an `owner/repo` value is unverified** — if it takes an owner only, then
offline registration and the repository-scope recommendation in §7 item 8
**conflict**, and one must give (web-UI registration at repo scope, or org scope
offline; prefer keeping repo scope). Also, `forgejo forgejo-cli actions register`
is documented on the **v16** docs while the map pins **`:15-rootless`** — confirm
the subcommand exists on 15 before designing around it. Note the runner config supports
`token_url: file:$CREDENTIALS_DIRECTORY/token.txt`, which pairs with a systemd
`LoadCredential=` and keeps the token out of the config file and out of
`docker inspect`.

**Registration scope — four levels** (<https://forgejo.org/docs/latest/admin/actions/security/>), verbatim:

> "Forgejo Runner instances can be registered with Forgejo at four different
> levels, which will impact the jobs that they will run. By ensuring that the
> tightest registration is used, the scope of risk from Mallory is reduced:"
> "Repository - A runner registered with a repository will only run actions
> defined in that repository."
> "Organization & User - A runner registered with an organization or user will
> only run actions defined in a repository owned by that organization or user."
> "Global - A runner registered in Forgejo's site administration can run a job in
> any repository."

**Decision that follows directly:** the map's premise is "**CI runs the deep tier
only, on push; lumin only.**" So register the runner at **repository scope on
`projects/lumin`** — not org, not global. That is free, documented, and it is the
single cheapest confinement measure available: no other repo in the forge can
ever hand this runner a job. Take it.

**Ephemeral mode** also exists and is Forgejo-enforced:

> "Ephemeral mode is enforced by Forgejo and cannot be disabled or ignored."
> "With ephemeral runners, only `forgejo-runner one-job` can be used.
> `forgejo-runner daemon` will exit immediately when it is told by Forgejo to
> switch to ephemeral mode."

Code carries the version floor verbatim: `"This Forgejo instance does not support
ephemeral runners; requires Forgejo 15 or newer."` — **the map's `:15-rootless`
pin is exactly the floor.** Ephemeral is aimed at on-demand runners
(*"Administrators of environments where Forgejo Runner instances are created on
demand"*) and is a poor fit for a persistent-cache design, so **do not use it
here** — but note it is the documented mitigation for the `host`-mode token leak
(§5), which is one reason `host` mode is not the recommendation.

### 1.2 Labels — the grammar is the whole answer to questions 2 and 5

Docs (<https://forgejo.org/docs/latest/admin/actions/configuration/>), verbatim:

> "A label has the following structure:"
> `<label-name>:<label-type>://<default-image>`
> "The label type determines what containerization system will be used to run the
> workflow. There are three options:"
> "docker for Docker or Podman containerization,"
> "lxc for LXC containerization,"
> "host for no containerization."

Examples, verbatim from the same page:

> "`node20:docker://node:20-bookworm` defines `node20` to be the
> `node:20-bookworm` image from hub.docker.com."
> "It is generally recommended to pin image versions instead of relying on tags,
> for example, `debian:docker://node@sha256:9144…` instead of
> `debian:docker://node:lts`. **That is a prerequisite for reproducible jobs.**"
> "`self-hosted:host` defines jobs that have `runs-on: self-hosted` to run
> without any container isolation."

and the warning on `host`, verbatim: **"There is no isolation at all and a single
job can permanently destroy the host."**

The parser confirms the mechanical grammar
(<https://code.forgejo.org/forgejo/runner/src/branch/main/internal/pkg/labels/labels.go>), verbatim:

```go
const (
	SchemeHost = "host"

	SchemeDocker = "docker"
	ArgDocker    = "//node:22-bookworm"

	SchemeLXC = "lxc"
	ArgLXC    = "//debian:bookworm"
	...
)
```

`strings.SplitN(str, ":", 3)`; schema defaults to `docker` when omitted; `host`
rejects an argument (`"schema: %s does not have arguments"`); an omitted argument
falls back to the scheme default. There is also a `?platform=` query option
(docker-scheme only) and an explicit mapping form with `backend:` /
`backend-options:`.

Multi-label selection, docs verbatim: *"Only a Forgejo Runner with both the
`docker` and `gpu` labels will be able to run the job. The job will be run on the
containerization platform that is listed in the first label in the `runs-on`
array."*

**So the label is where the confinement decision is expressed** — one line of
runner config decides whether a job runs in a container, in an LXC container, or
naked on helium's rootfs. It is not a rebuild, it is a config edit.

### 1.3 There is no single "default image" — and every candidate is wrong for the perf gate

The ticket says "its default runner image is a bare Debian bookworm + node".
That is right in spirit and imprecise in fact; the image always comes from the
**matched label**, and three different values circulate:

| Layer | Value | Source |
|---|---|---|
| docker-scheme default arg (label written with no image) | **`node:22-bookworm`** | `labels.go` `ArgDocker = "//node:22-bookworm"` |
| interactive-registration default label | **`data.forgejo.org/oci/node:lts`** | `internal/app/cmd/register.go` `defaultLabels` |
| docs / config example / prompts | **`node:20-bookworm`** | `config.example.yaml` `# Like: [..."ubuntu-latest:docker://node:20-bookworm"...]` |

Docs on what an image must contain, verbatim:

> "Many common actions (for example, `uses: actions/checkout@v6`) require Node.js in the image."
> "This image is quite capable of running many of the workflows that are designed
> for the GitHub runners, but not all the same tools will be available as GitHub
> provides."
> "When starting a container, Forgejo Runner does the equivalent of
> `docker run <image>`. That means that container images, once downloaded, are
> **never updated**."

**The finding that matters, and it falls straight out of ticket 02:** every
default candidate is **bookworm** (Debian 12, glibc **2.36**) or `node:lts`
(bookworm-based). helium and krypton are **Debian 13 trixie, glibc 2.41**.
Ticket 02 §1.3 lists **glibc version as a live `Ir` channel** — real glibc code
runs inside the measured region and is counted — and §4 requires *"a Debian 13
base with glibc 2.41 (matching krypton's `2.41-12+deb13u3`)"*.

**Therefore the default image is not merely inconvenient, it is disqualifying for
the perf gate.** This is a stronger statement than "you will want a custom
image": a bookworm job image would produce `Ir` numbers that cannot be compared
to `docs/perf-calibration.md` at all, and with only 10% uniform headroom
(ticket 02 §1.5) that is a coin-flip between a false red and a silent false
green. **(Inference, clearly labelled: that bookworm ships glibc 2.36 and trixie
2.41 is a Debian fact, not one I re-verified against a running image — fold it
into measurement M2 below.)**

### 1.4 GitHub Actions compatibility — stronger than "no guarantee"

<https://forgejo.org/docs/latest/user/actions/github-actions/>, verbatim, and the
section heading is **"Familiarity instead of compatibility"**:

> "Forgejo Actions is designed to be familiar to users of GitHub Actions, but it
> is **not designed to be compatible**."
> "Overall, many features from GitHub Actions translate one-to-one to Forgejo
> Actions. It is mostly the small differences that mean we can't claim to be 100%
> compatible. These small things are also usually the most difficult and least
> useful for our users to implement. And, since GitHub continues development on
> GitHub Actions, keeping up with all the changes would be impractical."

The enumerated **"Known list of differences"**, verbatim:

> - "The default environment is very different. Most Forgejo Runners use a Debian
>   bookworm image with just node.js by default, while GitHub uses a larger
>   `ubuntu` image."
> - "Some keys in the `github` context are missing."
> - "Certain subkeys on the `job` key in workflow files are ignored, like
>   `permissions`, and `continue-on-error`."
> - "Enabling OIDC ID token generation uses the `enable-openid-connect` key in the
>   workflow file instead of `permissions: id-token: write`"

**For lumin's workflow this is a non-issue.** The workflow needed here is
`on: push` + one or two jobs of `runs-on:` + `uses: checkout` + `run:` steps
calling `just`. None of the divergences above touch it. `continue-on-error` being
silently ignored is the only one worth a note — do not design a "advisory gate"
around it.

### 1.5 Workflow location — a fallback, not a union

<https://forgejo.org/docs/latest/user/actions/>, verbatim:

> "Forgejo Actions workflows are defined using `.yaml` files in the
> `.forgejo/workflows` directory of the repository."
> "In the absence of a `.forgejo/workflows` directory, workflows will be looked up
> in the `.github/workflows` directory, if it exists."

**Read that precisely: it is a fallback, not a union.** The moment
`.forgejo/workflows/` exists, anything in `.github/workflows/` **stops being
read**. lumin has no GitHub remote (map: it is one of the 17 homeless repos), so
there is nothing to collide — but this is a live trap for the six repos migrating
off GitHub, and it belongs in ticket 08's or 10's notes.

### 1.6 `DEFAULT_ACTIONS_URL` — the `uses:` gotcha

<https://forgejo.org/docs/latest/admin/config-cheat-sheet/>, `[actions]`, verbatim:

> "`DEFAULT_ACTIONS_URL`: **https://data.forgejo.org**: Default address to get
> action plugins, e.g., the default value means downloading from
> "https://code.forgejo.org/actions/checkout" for "uses: actions/checkout@v3"."

(The line is internally inconsistent about host — flagged, both hosts serve the
same content.) And <https://forgejo.org/docs/latest/user/actions/actions/>:

> "The `DEFAULT_ACTIONS_URL` is `https://data.forgejo.org/` by default, but it
> can be changed by the instance administrator. For this reason **it is strongly
> recommended to use fully qualified URLs**."

So a bare `uses: actions/checkout@v6` resolves to **data.forgejo.org, not
GitHub** — which is *good news* for a "less dependent on bigtech" motive, and it
is one more egress the box makes. Take the docs' advice and write
`uses: https://data.forgejo.org/actions/checkout@v6` fully qualified.

**Full `[actions]` section** (same page — note there are **no cache keys here at
all**; the cache is entirely runner-side):

> `ENABLED`: **true** · `DEFAULT_ACTIONS_URL`: **https://data.forgejo.org** ·
> `ARTIFACT_RETENTION_DAYS`: **90** · `ZOMBIE_TASK_TIMEOUT`: **10m** ·
> `ENDLESS_TASK_TIMEOUT`: **3h** · `ABANDONED_JOB_TIMEOUT`: **24h** ·
> `SKIP_WORKFLOW_STRINGS`: **[skip ci],[ci skip],[no ci],[skip actions],[actions skip]** ·
> `LOG_COMPRESSION`: **zstd** · `LIMIT_DISPATCH_INPUTS`: **10** ·
> `LOG_RETENTION_DAYS`: **365** · `ID_TOKEN_SIGNING_ALGORITHM`: **RS256** …

Actions is **enabled by default** (`ENABLED`: **true**; docs: *"As of
`Forgejo v1.21`, Actions is enabled by default"*), and must additionally be
ticked per-repo: *"Visit your repository settings, and go to Units > Overview.
Make sure the Actions checkbox is ticked."*

**Two retention numbers to set deliberately**, because ticket 01 §4 flagged SSD
capacity on the 480 GB btrfs raid1 mirror shared with Immich and Paperless:
`LOG_RETENTION_DAYS` defaults to **365** and `ARTIFACT_RETENTION_DAYS` to **90**.
A deep-tier run's logs are large (1109 mutant lines, zstd-compressed). lumin's
gates produce no artifacts worth keeping, so **upload nothing and shorten
`LOG_RETENTION_DAYS`** — one line in `stack.env.j2`
(`FORGEJO__actions__LOG_RETENTION_DAYS`). Cheap, and it is the kind of thing
nobody notices until the precious tier is full.

### 1.7 Concurrency and timeouts

From `config.example.yaml`, verbatim:

```yaml
  # Execute how many tasks concurrently at the same time.
  capacity: 1
  # The timeout for a job to be finished.
  # Please note that the Forgejo instance also has a timeout (3h by default) for the job.
  # So the job could be stopped by the Forgejo instance if its timeout is shorter than this.
  timeout: 3h
```

`capacity: 1` is the default and is the right value: ticket 02 established the
tier is serial and build-bound, so concurrency buys nothing and costs a second
2 GB+ `target/`. The 3h job timeout comfortably covers a 60–90 min cold run —
but note **`ENDLESS_TASK_TIMEOUT` is also 3h** server-side, so the two agree and
a genuinely stuck run does get reaped.

Security docs name the DoS honestly: *"the default 3 hour job timeout and
`runner.capacity` of 1 would allow a simple bash loop to prevent other jobs from
running for 3 hours."* Irrelevant in a single-user forge; noted for completeness.

---

## 2. Docker vs host vs LXC vs VM — capability first, then cost

**Ticket 02 collapsed the capability question.** Every gate runs in an
unprivileged container:

- **smoke gate:** verified in ticket 02 §2.5 — `docker run --rm
  --shm-size=256m debian:trixie`, **no `/dev/dri`, no `--privileged`, no
  `--cap-add`, no `--device`, default seccomp/AppArmor, non-root uid 1000**.
  Cage started, a client rendered, grim wrote a real 1280×720 PNG.
- **perf gate:** Valgrind needs no privileges and no devices. Single-threaded.
- **mutants / coverage / proptest / deny:** plain `cargo`.

So the four backends are **all capable**, and the choice is about confinement and
provenance, not about what the job can do. The one container-specific
requirement ticket 02 found is **`/dev/shm` sizing** — measured: *"1 MiB → cage
dies SIGBUS (exit 135); 4 MiB → grim dies SIGBUS; 8/12/16/64 MiB fine at
720p"*, and the failure mode is **SIGBUS with no error message at all**. That is
expressible in runner config:

```yaml
container:
  options: --shm-size=256m --memory=8g --cpus=5
```

verbatim from `config.example.yaml`: *"And other options to be used when the
container is started (e.g., --volume /etc/ssl/certs:/etc/ssl/certs:ro)."* and
from the security docs: *"The `container.options` value can be used to define
docker container resource limitations such as `--memory=1g` … or `--cpus=2`"* —
with the honest caveat *"there is no limit in the Forgejo Runner on the number of
simultaneous service containers that a single workflow job can start. There are
also no mechanisms available to limit disk or network I/O for any container."*

`--cpus` and `--memory` are worth setting anyway: they are the documented answer
to "coexist with a Jellyfin transcode", complementing ticket 02 §3.4's
`nice`/`ionice` recommendation rather than replacing it (cgroup CPU weight is not
what `nice` does).

**Caveat, and it matters for the recommendation in §5.3: under *rootless* Podman
these limits may be inert.** Rootless cgroup limits require cgroup-v2 controller
delegation to the user slice, and the `cpu` controller is historically not
delegated by default. If it is not delegated, `--cpus`/`--memory` are silently
ignored and **ticket 02's `nice`/`ionice` wrapper becomes the *only* contention
lever, not a complement.** One command settles it — folded into **M9**.

**And that promotes a ticket-09 spec question from "inherited" to "on the
critical path" — say so rather than assuming the runner can absorb it.**
Ticket 02 §3.4 already flags that `mutants: cargo mutants` sits in lumin's
justfile and **spec §2 makes the justfile *the* entry point**, so where
`nice`/`ionice`/`--in-place` live is a ticket-09 decision, not a runner knob. The
recommendation here makes that sharper in two ways:

- If cgroup delegation is absent (M9), `nice`/`ionice` is the **only** contention
  lever — so it stops being a nice-to-have and becomes the mechanism that makes
  "coexist with a Jellyfin transcode" true at all.
- A containerised job cannot apply it from outside: `container.options` has no
  niceness knob, so the only places it can live are **a workflow step wrapping the
  justfile entry point** (`run: nice -n19 ionice -c3 just qa`) or **the justfile
  itself**. The first bypasses spec §2's entry point for CI only; the second
  changes lumin's contract and goes through the §8 rule-6 flagging ritual.
  **Either way this touches lumin's spec — the runner cannot decide it.**

Honest caveat on the lever itself: `nice -n19` needs no privilege (lowering
priority is always permitted) and `ionice -c3` is likewise unprivileged, but
`ionice` classes only bite under an I/O scheduler that honours them (BFQ/CFQ) —
on a `none`/`mq-deadline` queue it is a no-op. Worth checking alongside M11 so it
is not silently relied upon.

### 2.1 What each backend actually costs

| Backend | Job isolation | Runner's own privilege | Toolchain provenance | Verdict here |
|---|---|---|---|---|
| `docker://` via **DinD sidecar** (documented default) | container | **privileged container** | image digest ✔ | Capable; §5 rejects it |
| `docker://` via **host Docker socket** | container | runner in `docker` group ≈ **root on helium** | image digest ✔ | Capable; §5 rejects it |
| `docker://` via **rootless Podman** | container, user-namespaced | **unprivileged user** | image digest ✔ | **Recommended** |
| `lxc://` | LXC container, steps run **as root** inside | needs **passwordless sudo for all `lxc-*`** | LXC template | Over-engineered; §5 |
| `host` | **none** | unprivileged user, but jobs == that user | helium's apt state ✘ | Cheapest; real costs in §5 and §7 |
| dedicated VM / separate box | strong | contained by construction | VM image ✔ | Out of scope / no hardware |

On LXC the docs are unusually candid, verbatim:

> "The runner will execute all the steps, **as root**, within a LXC container
> created from that template and release."
> "LXC containers do not provide a level of security that makes them safe for
> potentially malicious users to run jobs. They provide an excellent isolation
> for jobs that may accidentally damage the system they run on."
> "When using `lxc` labels in Forgejo Runner, there are no mechanisms available
> to restrict resource utilization (memory, CPU, disk & network I/O)"

and yet, comparatively: *"Relative to the Docker-in-Docker and automount options,
the LXC configuration provides superior isolation; accessing any Docker resource
hosted within the job container is isolated from the runner host and from other
job containers."* Note the comparison is specifically against *Docker-access*
configurations — and lumin needs no Docker access inside the job at all, which
removes the thing LXC is being praised for. Also: the docs' LXC default release
(`bullseye`, per the docs) disagrees with the code
(`ArgLXC = "//debian:bookworm"`), and **neither is trixie** — so LXC would need
its own trixie template work to satisfy §1.3's glibc constraint. **LXC is a
worse fit than rootless Podman on every axis that matters here.**

### 2.2 Reconciling with helium's `issues/010` posture

`issues/010-non-root-containers.md` establishes `cap_drop: [ALL]` +
`no-new-privileges:true` as the house style for **compose services**, and
explicitly states **"`userns-remap` stays OFF"** — *"it breaks Jellyfin's
`/dev/dri` and gluetun's net caps"*. Two consequences:

1. **Rootless Docker cannot be reached by flipping host-wide `userns-remap`** —
   that switch is deliberately off and would break two load-bearing services. A
   rootless container runtime for CI therefore has to be a *second, separate*
   runtime owned by an unprivileged user. Rootless **Podman** is exactly that,
   and it is documented (§5.3).
2. **A host-level systemd unit is not alien to helium's posture** — it is an
   established, documented carve-out. `ansible/roles/mqtt_metrics/tasks/main.yml`
   opens with, verbatim from the repo:

   > "Why this is a host unit and not a container, given the compose stack's
   > non-root / cap_drop:[ALL] posture (issues/010): reading SMART off the SAS
   > drives means issuing SCSI commands to the raw block devices as root, which
   > is a wider grant than `pid: host` plus /proc and /sys and cannot be
   > reconciled with cap_drop:[ALL] at all."

   The pattern is "containerise services; use a host unit where containerising
   would require *more* privilege than the host unit needs." The runner fits that
   pattern **better than the existing precedent does**: `mqtt_metrics` runs as
   **root**; a `forgejo-runner` host unit runs as an **unprivileged user**. And
   `restic_backup`, `syncthing`, `sensors`, and `storage_hdd` are all host-level
   roles that apt-install packages and install systemd units. So there is nothing
   novel about the shape.

   **The honest cost is elsewhere:** it puts a `forgejo-runner` binary (no Debian
   package exists — see §5.3) and a Podman socket on the NAS host.

---

## 3. Getting the pinned toolchain in, and caching

### 3.1 The toolchain: bake it into a purpose-built trixie image

Ticket 02 §4 already settled the *what*: `cage`, `grim`, `valgrind` (Debian
`1:3.24.0-3`) plus xwayland/xkeyboard-config pulled in as cage deps, the rustup
toolchain at exactly **1.94.1** (`rust-toolchain.toml`), and five
`cargo install` builds — `cargo-machete`, `cargo-mutants`, `cargo-deny`,
`cargo-llvm-cov`, and **`gungraun-runner` at exactly `0.19.4`** (preflight
string-matches `"gungraun-runner 0.19.4"`). Its verdict, verbatim: *"That is five
compile-from-source installs plus the rustup toolchain on first provision; bake
them into the job image rather than paying for them per run."*

Nothing in the runner changes that. Three additions:

- **Base must be `debian:trixie`** (glibc 2.41), per §1.3. A musl/alpine image is
  disqualifying outright (ticket 02 §4).
- **Add `zstd`.** Docs, verbatim: *"`actions/cache` will use `zstd` if present
  when compressing files to be sent to the cache. It is faster than the default
  compression. A container which does not have `zstd` installed **will not** be
  able to decompress the cache and will continue without."* Silent no-op restores
  are the worst kind of cache bug.
- **Add `nodejs` and `git`.** `actions/checkout` needs Node
  (*"Many actions require node to run. Using a custom container image that does
  not contain node may cause these actions to break."*) and the binary-install
  page states: *"Forgejo Runner requires that Git is installed, and has been
  tested with a minimum version of Git 2.24.3."*

**Where is the image built?** Recommend: a `Containerfile` in the dotfiles repo,
built **on helium** by an ansible task, tagged with a date/content hash. Reasons:
it avoids a chicken-and-egg where CI depends on the forge's own registry (which
depends on the forge being up), it sidesteps ticket 08's registry-exposure
collision entirely, and `container.force_pull: false` (the default) means a
locally-tagged image is used as-is. The docs' caution cuts the same way:
*"container images, once downloaded, are never updated"* — so an immutable
locally-built tag is the honest model. **Digest-pin it in the label** as the docs
recommend (*"a prerequisite for reproducible jobs"*) and record that digest in
`docs/perf-calibration.md` alongside rustc/valgrind/glibc, per ticket 02 §4.

Pushing the image to the forge's own registry later is a fine refinement, not a
prerequisite.

### 3.2 There IS a real cache server — and you should mostly not use it for `target/`

**It exists, it is runner-side, and it is on by default.** From
`config.example.yaml`, verbatim:

```yaml
cache:
  #
  # When enabled, workflows will be given the ACTIONS_CACHE_URL environment variable
  # used by the https://code.forgejo.org/actions/cache action. The server at this
  # URL must implement a compliant REST API, and it must also be reachable from
  # the container or host running the workflows.
  #
  # It works as follows:
  #
  # - the workflow is given a one-time use ACTIONS_CACHE_URL
  # - a cache proxy listens to ACTIONS_CACHE_URL
  # - the cache proxy securely communicates with the cache server using
  #   a shared secret
  #
  enabled: true
  ...
  port: 0        # 0 means to use a random available port.
  dir: ""        # If empty, the cache data will be stored in $HOME/.cache/actcache.
```

Docs confirm the server never touches Forgejo: *"The logs and artifacts are
stored in Forgejo. **The cache is stored by the runner itself and never sent to
Forgejo.**"* (<https://forgejo.org/docs/latest/admin/actions/>) and there are
**no cache keys in `[actions]`** at all. The action itself is mirrored at
`data.forgejo.org/actions/cache`, `v4` through `v6` tags exist, and — unlike
`upload-artifact`/`download-artifact`, whose mirror descriptions carry
*"Warning: @v4 will not work from this mirror"* — **`cache` carries no such
warning**. Failure mode if the runner has no cache configured, verbatim: *"`Cache
action is only supported on GHES version >= 3.5`"*.

**But it is the wrong tool for lumin's `target/`.** ticket 02 §3.4 quotes
cargo-mutants: *"Rust `target` directories can commonly be 2GB or more"*, and
`cargo llvm-cov` maintains a **second** tree at `target/llvm-cov-target`. Every
`actions/cache` round-trip is a tar + zstd + HTTP upload of that, and a
restore-then-recompress on the next run — on a 6-core box whose whole problem is
being build-bound, next to a Jellyfin transcode, writing to a 480 GB SSD mirror
that also holds Immich and Paperless. Tarball round-trips are strictly worse than
never moving the bytes at all.

**The real answer is persistence via `container.valid_volumes`.** Verbatim:

```yaml
  # Volumes (including bind mounts) can be mounted to containers. Glob syntax is supported…
  # If you want to allow any volume, please use the following configuration:
  # valid_volumes:
  #   - '**'
  valid_volumes: []
```

Security docs on the same key, verbatim: *"The default value of `valid_volumes`
is an empty array `[]`."* / *"Data on the mounted volumes can be accessed freely
by the Forgejo Actions, in both read and read/write mode."* / *"If a volume is
listed in `valid_volumes`, the data within it **cannot be considered
confidential**"*. For a build cache that is an acceptable statement — it holds
crates.io tarballs and object files, nothing secret. **Allow-list exactly two
paths; never `'**'`.**

Concretely:

```yaml
container:
  valid_volumes:
    - /data/ssd/ci/cargo-home
    - /data/ssd/ci/target
  options: --shm-size=256m --memory=8g --cpus=5
```

**Which lever actually performs the mount is not settled from the docs, and there
are two — pick deliberately:**

- **`valid_volumes` + a workflow-side `container: volumes:` block.** This is what
  the key is described for: security docs, verbatim, *"If an administrator changes
  this, they will allow a job container or service container to mount the listed
  volumes when the container is started."* i.e. `valid_volumes` is an
  **allow-list gating what the workflow may ask for**, not itself a mount
  instruction. **Cost: lumin's workflow file would hardcode helium's host paths**
  (`/data/ssd/ci/target`), leaking host layout into the repo — and a
  workflow-level `container:` block also has to re-specify the image.
- **`container.options: --volume /data/ssd/ci/target:/cache/target`.** Admin-side,
  keeps host paths out of lumin's git history, and the config's own comment names
  exactly this form: *"And other options to be used when the container is started
  (e.g., `--volume /etc/ssl/certs:/etc/ssl/certs:ro`)."* **Unverified: whether
  `options`-supplied volumes are themselves subject to the `valid_volumes`
  allow-list.**

**Recommend the `options` form** (host layout stays in ansible where it belongs),
keep `valid_volumes` populated with the same two paths as belt-and-braces, and
settle the gating question in **M12** — because *"every run is cold"* is the
shared failure symptom of getting either lever wrong, and it reads as slowness
rather than misconfiguration.

Either way the job sets `CARGO_HOME=/cache/cargo-home` and
`CARGO_TARGET_DIR=/cache/target`. Then:

- `actions/checkout` still gets a **fresh throwaway tree each run** — which is
  what makes `cargo mutants --in-place` safe (ticket 02 §3.4's first
  recommendation, and the one mode where *"the Rust toolchain … will reuse [build
  products]"*);
- the registry and the object files survive, so "warm" is the normal case and the
  60–90 min cold path happens once;
- `capacity: 1` means no two jobs ever share the cache concurrently — this design
  **depends** on that default, so do not raise it.

**Where those two dirs live matters, and helium already has the right place.**
`ansible/host_vars/helium/vars.yml` splits the SSD pool into
`ssd_subvolumes_precious: [appdata, immich, paperless, vault]` and
`ssd_subvolumes_scratch: [downloads, transcode]`, where scratch subvolumes are
**`nodatacow` (mount opt + `chattr +C`) "to avoid CoW fragmentation and pointless
checksumming."** A cargo `target/` is the textbook case for that. And
`restic_backup_source` is `{{ ssd_pool_mount }}/appdata` — **appdata only** — so a
new **`ci` scratch subvolume is automatically outside restic's scope**, which is
correct: nobody wants 2 GB of churning object files in the backup repo. So:
**add `ci` to `ssd_subvolumes_scratch`**, and do *not* put the cache under
`appdata`.

**Two cache-server gotchas worth pre-empting**, both documented:

- **Rootless Podman breaks `ACTIONS_CACHE_URL` reachability.** Docs, verbatim:
  *"`::warning::Failed to restore: getCacheEntry failed: connect ECONNREFUSED
  192.168.124.60:41275`"*, fixed with
  `cache.actions_cache_url_override: 'http://host.containers.internal:4000'`.
  Since §5 recommends rootless Podman, **expect to need this**. It is one config
  line, and it is a known-answer problem rather than a discovery.
- Also documented under rootless Podman: *"only Podman version 5.3 and later have
  been observed to have proper IPv6 support in rootless bridge networks"* — check
  trixie's podman version (M2).

Given the bind-mount design, the cache server matters much less; keep it enabled
for the small stuff and do not route `target/` through it.

### 3.3 Three build-hygiene rules the workflow must carry

From ticket 02 §1.3, restated here because they are **workflow-file** decisions,
not lumin decisions:

- **No `RUSTFLAGS`, no `-C target-cpu`** — *"it makes a different binary per host,
  and on Zen 5 it emits AVX-512 that SIGILLs under valgrind 3.24"*.
- **No `CARGO_INCREMENTAL=1`** — changes `codegen-units` and therefore `Ir`.
- **`GLIBC_TUNABLES` unset** — measured to move `Ir` by −43.4% (`-ERMS`) / +3.0%
  (`-AVX2`).

Add one of my own: **`--locked`**. lumin's `Cargo.lock` is committed; a CI run
that silently resolves a newer transitive crate changes both `Ir` and the code
that executes at build time (§5.6). Note that `container.envs`/`env_file` in the
runner config is a blunt instrument for this — prefer setting them in the
workflow file so they live in lumin's git history.

---

## 4. How the verdict comes back

**Better than the map's fog item assumed. Four surfaces, three of them free.**

**1. The Actions tab.** Docs, verbatim: *"Go to the `Actions` tab of the
repository. You should see your `demo.yml` workflow listed on the left… If you
click on the run you'll get a more detailed view with the output from the
runner."* Log verbosity is split in the runner config between what the operator
sees and what the web UI sees, verbatim:

```yaml
log:
  level: info        # "What is displayed in the output of the runner process but not sent to the Forgejo instance."
  job_level: info    # "What is sent to the Forgejo instance and therefore visible in the web UI for a given job."
```

**2. Per-job commit statuses.** Not in the user docs (grepped — zero hits), but
implemented: `services/actions/commit_status.go`
(<https://codeberg.org/forgejo/forgejo/src/branch/forgejo/services/actions/commit_status.go>),
verbatim:

```go
ctxname := fmt.Sprintf("%s / %s (%s)", runName, job.Name, event)
```
```go
	case actions_model.StatusSuccess:
		description = fmt.Sprintf("Successful in %s", job.Duration())
	case actions_model.StatusFailure:
		description = fmt.Sprintf("Failing after %s", job.Duration())
```

`TargetURL` is `fmt.Sprintf("%s/jobs/%d", run.Link(), index)`.

**The load-bearing negative:** the event switch ends `default: return nil`.
Statuses are created **only** for push, the pull-request family, and release.
**Scheduled runs and `workflow_dispatch` get no commit status at all.** The map's
premise is "deep tier only, **on push**", so push is covered — but if a nightly
schedule is ever added, its verdict is invisible in the commit list and *only*
the email/Actions-tab paths carry it.

**3. Badges — the endpoint is real, and it leaks by default.** Two routes are
registered in `routers/web/web.go`:

```go
		if setting.Badges.Enabled {
			m.Group("/badges", func() {
				m.Get("/workflows/{workflow_name}/badge.svg", badges.GetWorkflowBadge)
```
```go
			m.Group("/workflows/{workflow_name}", func() {
				m.Get("/badge.svg", badges.GetWorkflowBadge)
				m.Get("/runs/latest", actions.ViewLatestWorkflowRun)
```

So `/{owner}/{repo}/badges/workflows/{file}/badge.svg`,
`/{owner}/{repo}/actions/workflows/{file}/badge.svg`, and — useful — a
**`…/runs/latest` permalink** to the newest run. Confirmed live against
code.forgejo.org: `curl …/badges/workflows/test.yml/badge.svg` → HTTP 303 → SVG
containing `aria-label="test.yml: success"`.

**Read that 303.** Cheat sheet, `[badges]`, verbatim:

> - `ENABLED`: **true**: Enable repository badges (via a generator like `shields.io`).
> - `GENERATOR_URL_TEMPLATE`: **https://img.shields.io/badge/{{.label}}-{{.text}}-{{.color}}**: The URL template used for the badge generator service.

**Badge rendering is delegated to img.shields.io by default.** On a forge whose
whole motive is *"I want it to be private. I want to be less dependent on
bigtech"*, a badge that round-trips the workflow name and status through a
third-party CDN is exactly the wrong default. It only fires if a badge URL is
actually requested — but the honest options are: leave badges alone, set
`FORGEJO__badges__ENABLED=false`, or point `GENERATOR_URL_TEMPLATE` at something
self-hosted. **One line in `stack.env.j2`, and worth a spec sentence.**

**4. A first-party failure email exists — this is the surprise.**
<https://forgejo.org/docs/latest/user/actions/reference/#enable-email-notifications>,
a **top-level workflow-file key**, verbatim:

> ### `enable-email-notifications`
> "Send an email notification when a workflow run fails."
> ```yaml
> enable-email-notifications: true
> ```
> "The email notification is sent to the user who triggered the workflow run (for
> example, the author of a pull request, the user who pushed a commit), unless
> they disabled email notifications in their settings."
> "If a workflow run is not associated with a user like a scheduled workflow run,
> the notification will be sent to: The user who owns the repository … The
> organization that owns the repository unless there is no contact email in its
> settings."

Implemented in `services/mailer/mail_actions.go` + `templates/mail/actions/now_done.tmpl`,
gated verbatim by `if !run.NotifyEmail { return nil }` — i.e. **opt-in**, per
commit `b2c4fc9f94` *"bug: Forgejo Actions email notifications are opt-in
(#8242)"*. Present in the `v15.0`, `v16.0`, and `next` doc branches, so it is
available on the map's LTS pin. It needs `[mailer]` configured
(`if setting.MailService == nil { return nil }`), which helium's Forgejo does not
have yet.

**Recommendation, and it closes the map's fog item rather than deferring to it.**
Two layers, both one line:

1. **`enable-email-notifications: true`** if `[mailer]` gets configured anyway —
   it is free and it is the only path that also covers a future scheduled run.
2. **Otherwise (and probably instead), an `if: failure()` step** posting to
   **ntfy or HA's MQTT**, both of which the fleet already runs
   (`project_helium_metrics_mqtt_ha`: Mosquitto add-on on argon at
   `192.168.1.99:1883`). That is a single workflow step, needs no `[mailer]`, and
   lands the verdict where the owner already looks. Adding `if: success()` too
   turns it into a heartbeat, which matters because **a silent runner and a green
   run look identical** — `ABANDONED_JOB_TIMEOUT` (24h) is the only thing that
   ever notices a job nobody picked up.

Programmatic polling, for an agent or a `forge` CLI: `GET
/repos/{owner}/{repo}/actions/runs` (plus `…/runs/{id}`, `…/runs/{id}/jobs`,
`…/jobs/{id}/logs`, `…/runs/{id}/cancel`, and
`…/actions/workflows/{file}/dispatches` POST). Enumerated from a live Forgejo's
own `swagger.v1.json`.

**Secrets, for completeness** (map fog item "Secrets in CI"): repo/org/user
scoped, `${{ secrets.KEY }}`, *"stored encrypted in the Forgejo database"*,
*"Once the secret is added, its value cannot be changed or displayed."* API:
repo and org have list+PUT+DELETE; **`/user/actions/secrets` has no list
endpoint**; no scope has a GET on an individual secret. An auto-minted
`FORGEJO_TOKEN` (aliased `GITHUB_TOKEN`) is present in every job. **lumin needs
none of this today** — its gates are offline except `cargo deny`'s advisory-DB
fetch. Confirms the fog item's own guess.

---

## 5. CONFINEMENT — where the runner lives (the important question)

### 5.1 First, separate two things ticket 01 fused

The privileged-DinD warning is about **how the runner creates job containers**,
not about **what jobs need**. Ticket 02 emptied the second bucket entirely — but
that does **not** shrink the first by itself. Conflating them is the trap, and it
cuts both ways: "the smoke gate needs nothing special" is not an argument for
privileged DinD being fine, and it is not an argument against containers either.

The right frame is a ladder of **the runner's own access to helium**:

| Shape | Runner's own privilege | Job isolation | Toolchain lands in |
|---|---|---|---|
| DinD sidecar (documented default) | **privileged container** | container | job image |
| host Docker socket | **`docker` group ≈ root on helium** | container | job image |
| **rootless Podman** | **unprivileged user** | container (userns) | job image |
| `lxc://` | **passwordless sudo `lxc-*`** | LXC (steps as root) | LXC template |
| `host` label | unprivileged user | **none** | **helium's rootfs** |
| dedicated VM / box | n/a (contained) | strong | VM image |

### 5.2 The documented default, and why it is the worst option here

<https://forgejo.org/docs/latest/admin/actions/installation/docker/>, verbatim:

```yaml
services:
  docker-in-docker:
    image: docker:dind
    container_name: 'docker_dind'
    privileged: 'true'
    command: ['dockerd', '-H', 'tcp://0.0.0.0:2375', '--tls=false']
    restart: 'unless-stopped'

  runner:
    image: 'data.forgejo.org/forgejo/runner:13'
    environment:
      DOCKER_HOST: tcp://docker-in-docker:2375
    # User without root privileges, but with access to `./data`.
    user: 1001:1001
    volumes:
      - ./data:/data
    command: 'forgejo-runner daemon --config runner-config.yml'
```

Note the comment "*User without root privileges*" on the **runner** while the
**sidecar** next to it is `privileged: 'true'` running a **plain-HTTP, TLS-off
dockerd on a container port**. The runner being non-root is cosmetic when it has
unauthenticated network access to a privileged Docker daemon. And the security
docs are explicit about the consequence of the related knob, verbatim:

> "If `container.privileged` is configured to `true` and our attacker Mallory is
> able to mutate actions workflows that are executed, Mallory will be able to
> operate as root on the Forgejo Runner machine; all confidential data can be
> compromised, all data integrity can be compromised, and availability of the
> service can be disrupted."

**Cost on helium specifically:** a `privileged: true` container in the same
compose stack whose entire `issues/010` premise is `cap_drop: [ALL]` +
`no-new-privileges:true` on **every** service, with three narrowly-documented
exceptions each justified in writing. A privileged DinD would be the **fourth
exception and by far the widest** — wider than gluetun's `NET_ADMIN`, wider than
Jellyfin's `/dev/dri` — and the only one whose justification would be "it is the
copy-paste from the docs." **Reject.**

**Host Docker socket (`docker_host: automount`, or just letting the runner use
`/var/run/docker.sock`) is not the escape.** Docs, verbatim: *"This configuration
is the simplest in order to access Docker from a job container, but **provides no
security isolation**."* / *"All storage on the host can be compromised by an
Action performing volume mounts to newly created containers. For example, an
action step such as `docker run -v /:/host-mount ubuntu` would make the entire
host's storage available to the container, including any on-disk secrets."* It
also puts CI job containers on the **same daemon** that runs Immich, Paperless,
Jellyfin and gluetun. **Reject.**

### 5.2b `docker_host` — a trap in the Podman instructions, and the exact escape

**This is the one place where following the Podman doc literally would undo the
whole recommendation, so it needs stating precisely.**

The Podman page says, verbatim: *"When using Podman, you **must** configure the
`docker_host` parameter in the `container` section of the configuration file with
the path to the Podman socket created above."* But
<https://forgejo.org/docs/latest/admin/actions/docker-access/> says of
`docker_host: "unix://..."`, verbatim: *"Forgejo Runner will **share the socket
with the containers** as long as it's a UNIX socket or a named pipe."*

**So `docker_host: unix:///run/user/1004/podman/podman.sock` bind-mounts the
Podman socket into every job container** — handing every `build.rs` in lumin's
dependency graph the ability to spawn containers as the runner user. That would
detonate §5.6's closing argument.

**The escape is in the same doc** — *"You can also set this with the `DOCKER_HOST`
environment variable"* — and the source confirms it works
(`internal/app/cmd/daemon.go`, verbatim):

```go
func getDockerSocketPath(configDockerHost string) (string, error) {
	// a `-` means don't mount the docker socket to job containers
	if configDockerHost != "automount" && configDockerHost != "-" {
		return configDockerHost, nil
	}

	socket, found := os.LookupEnv("DOCKER_HOST")
	if found {
		return socket, nil
	}
	...
```

and in `configCheck`:

```go
		os.Setenv("DOCKER_HOST", dockerSocketPath)
		if cfg.Container.DockerHost == "automount" {
			cfg.Container.DockerHost = dockerSocketPath
		}
```

Trace both branches:

- **`docker_host: unix://…`** → returns at the early `return configDockerHost`;
  `cfg.Container.DockerHost` keeps the URL; the scheme is `unix`, so the
  "can't be mounted" reset to `"-"` does **not** fire. **Socket IS mounted into
  job containers.**
- **`docker_host: "-"`** → falls through to `os.LookupEnv("DOCKER_HOST")` and
  returns the env value, which is used for `CheckIfDockerRunning` and re-`Setenv`.
  `cfg.Container.DockerHost` is reassigned **only** in the `"automount"` branch,
  so it stays `"-"`. **Runner connects; socket is NOT mounted.**

**Therefore the required configuration is exactly two lines, and they must both
be present:**

```yaml
# runner-config.yml
container:
  docker_host: "-"        # do NOT put the podman socket URL here
```
```ini
# forgejo-runner.service
Environment=DOCKER_HOST=unix:///run/user/<runner-uid>/podman/podman.sock
```

This is the difference between "jobs are confined" and "jobs can start
containers", it is one character wide, and the Podman doc points the wrong way.
**Confirm it empirically as part of M9b** — the check is that a job step running
`ls -l /var/run/docker.sock` finds nothing.

(Also worth knowing: `configCheck` only resolves a socket at all `if requireDocker`,
i.e. when some label uses the docker scheme — a `host`-only runner never touches
this code path.)

### 5.3 The recommendation: host runner (unprivileged systemd unit) + rootless Podman + `docker://` labels

**This is first-party documented, on exactly helium's OS.**
<https://forgejo.org/docs/latest/admin/actions/installation/binary/>, verbatim:

> "If the runner will be using Podman, no particular permissions are needed, but
> you will need to configure your system to run the Podman service."
> "On most recent Linux distributions, the `podman` package alone should give you
> a working version of Podman which can run as the unprivileged `runner` user.
> You do not need to install any supplemental packages for Docker compatibility
> or "rootless" operation."
> "**These instructions are for Debian 13 (trixie)** but should also apply to
> Ubuntu, and likely to other systemd based distributions."
> `sudo systemctl --user -M runner@ enable --now podman.socket`
> "Listen: /run/user/1004/podman/podman.sock (Stream)"
> "Finally, you must set the `runner` user to "linger" so that the socket will be
> created at boot:" → `sudo loginctl enable-linger runner`
> "When using Podman, you must configure the `docker_host` parameter in the
> `container` section of the configuration file with the path to the Podman
> socket created above."

Contrast the Docker path on the same page: *"`usermod -aG docker runner`"* —
i.e. root-equivalent. **Podman needs none of it.**

Runner installation: **no Debian package exists.** The packaging page documents
**only NixOS** (*"A `forgejo-runner` package is available for Nix"*) — checked
specifically, and the absence is the finding. So it is a pinned binary download
with GPG verification, matching the dotfiles' existing external-installer
pattern (`modules/node/install.sh`'s nvm shape, and helium's other host roles):

```
FORGEJO_URL="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-${ARCH}"
```
installed to `/usr/local/bin/forgejo-runner`, `.asc` signature verified against
key `EB114F5E6C0DC2BCDD183550A4B61A2DC5923710` ("Good signature from Forgejo").
**Pin `RUNNER_VERSION` explicitly** — the doc's snippet resolves `latest` via the
API, which is exactly the unpinned pattern this repo avoids everywhere else.

Also note the config file has **no default location**: *"Forgejo Runner requires
the configuration file to be explicitly specified with the `-c` command-line
option. There is no default configuration file location."* — so the unit's
`ExecStart` carries it.

**What this shape buys, concretely:**

- **No privileged container anywhere.** No `privileged: true`, no `docker` group,
  no socket mount, no second root daemon.
- **Jobs are still containerised**, so ticket 02 §4's provenance model holds
  unchanged: image digest recorded alongside rustc/valgrind/glibc, M1/M2/M4/M5/M6
  run *inside the job image* as §4 demands. **Choosing containers is what keeps
  ticket 02's §4 preamble true** — see §7.
- **`valid_volumes` gives the persistent cache** (§3.2) with an explicit
  two-entry allow-list rather than host-wide access.
- **`--memory` / `--cpus` / `--shm-size`** are available via `container.options`.
- It fits the repo's own precedent for host units (§2.2) and is *less* privileged
  than that precedent.

**Honest costs, stated plainly:**

1. **A new host-level ansible role** (`forgejo_runner`) plus a `podman` package,
   a lingering `runner` user, and a user-scoped socket unit. Real work, and it is
   the second-most-complex host role after `restic_backup`.
2. **Rootless Podman networking is the known rough edge.** The
   `ACTIONS_CACHE_URL` ECONNREFUSED failure is *documented* with a documented
   fix (`actions_cache_url_override`), and IPv6 in rootless bridge networks needs
   Podman ≥ 5.3. Neither is a blocker; both are "expect one debugging session".
3. **Podman is not Docker.** Ticket 02's container verification was done under
   **Docker** (`docker run --rm --shm-size=256m debian:trixie`) with default
   seccomp/AppArmor. Podman's rootless userns + its own seccomp profile is
   *very likely* equivalent for cage/grim/valgrind — none of them needs a
   capability — but "very likely" is not "verified". **This is measurement M6b
   below, and it is the one genuinely new risk this recommendation introduces.**
4. **The runner still runs on helium.** It is confined, not removed. §5.6.

**The fallback if Podman fights back:** `host` label, accepting §5.4's costs. Do
not fall back to DinD.

### 5.4 `host` label — the cheapest option, and what it actually costs

Config is trivial (`labels: ["lumin-deep:host"]`, plus `host.workdir_parent`),
and there is no container runtime to install at all. Three real costs:

1. **The token leak, documented verbatim:** *"The Forgejo Runner necessarily needs
   to read the runner's `.runner` state file. In the host execution mode, a
   workflow job would also be able to read this state file. If Mallory
   exfiltrated this state file, they would be able to set up an impersonating
   Forgejo Runner."* And *"There is no isolation at all and a single job can
   permanently destroy the host."* (The documented mitigation is ephemeral mode,
   which conflicts with the persistent-cache design — §1.1.)
2. **The whole toolchain moves onto helium's rootfs** — rustup, a 1.94.1
   toolchain, five `cargo install` builds, `cage`, `grim`, `valgrind`, xwayland.
   That is a lot of surface on the NAS, it drifts with `unattended-upgrades`, and
   a `just preflight` failure becomes a host-provisioning problem rather than an
   image rebuild.
3. **It invalidates ticket 02 §4's provenance model** — see §7. That section is
   written entirely for containers; under `host`, provenance is helium's apt
   state, and the measurements run in a host shell after all.

Cost (2) is the one that actually decides it against Podman: not the security
delta, but that **an image digest is a better provenance anchor for a
byte-identical-`Ir` gate than a mutable apt state on a machine that
auto-upgrades**. That is a ticket-09 concern as much as a ticket-04 one.

### 5.5 Dedicated VM, LXC, or a separate box

- **LXC:** rejected in §2.1 — needs passwordless sudo for all `lxc-*`, runs steps
  as root, has *"no mechanisms available to restrict resource utilization"*, and
  neither its docs default (`bullseye`) nor its code default (`bookworm`) is the
  trixie/glibc-2.41 base the perf gate requires.
- **Dedicated VM on helium:** helium is **bare-metal Debian with no hypervisor**
  (`hosts/helium/PRD.md`; the fleet's virtualisation lives on the retired titan).
  Installing libvirt/KVM on the NAS to host one CI VM, then carving 8 GB of 16 GB
  and 5 of 6 cores for it, is a large amount of new machinery for a confinement
  step above rootless Podman that is real but modest. **Reject on cost, not on
  principle.**
- **Separate physical box:** the map already rules this out — *"Acquiring
  dedicated build hardware / paid CI minutes — ruled out when the goal was settled
  as laptop load rather than wall-clock."* And there is no idle hardware:
  krypton is the laptop, argon runs HA, radon is a small standalone public VPS
  explicitly not on the mesh. Note the docs do confirm it *would* work — *"the
  runner is installed and configured separately from Forgejo"* and can live on a
  different host — so this stays available as a future move without redesign.
  **Reject for now, on the map's own prior decision.**
- **radon specifically: reject twice over.** It is the small public-facing VPS and
  it is **not on the mesh**, so it could not reach helium's Forgejo at all — and
  putting a build runner on the only public-facing box inverts the risk.

### 5.6 The security bottom line — what the "only my own code" argument does and does not cover

**The mitigation is real, and it should be said plainly.** This is a
single-user forge. There are **no other users** (and `DISABLE_REGISTRATION`
should be set — docs: *"`service.DISABLE_REGISTRATION` can be set to `true` which
will prevent unexpected users from registering"*). There are **no fork PRs and no
untrusted contributors**; secrets are withheld from fork PRs anyway (*"It is empty
if the `event` that triggered the `workflow` is `pull_request` and the head is
from a fork"*). Only one repo's workflows can reach this runner at all
(repository-scoped registration, §1.1). Importing a multi-tenant CI threat model
wholesale here would be a mistake: the entire "Mallory mutates a workflow" class
in Forgejo's security doc presumes an attacker who can push, and an attacker who
can push to lumin already has the owner's credentials and does not need CI.

**What that argument does not cover — and the first one is the whole reason
confinement still matters:**

1. **`cargo build` executes third-party code by design.** Every `build.rs` and
   every proc macro in lumin's transitive dependency graph — the
   winit/softbuffer/wayland stack is thick with both — runs **at full privilege
   during the build**, on every one of those 1109 mutant builds. That is not the
   owner's code and no amount of "single user, no fork PRs" touches it. One
   typosquat, one compromised crate release, one hijacked maintainer account, and
   that is arbitrary code execution *in whatever confinement was chosen*. This is
   the argument for confinement, and it survives every mitigation above.
   - **Partial mitigations already in lumin:** `Cargo.lock` is committed (so add
     **`--locked`**, §3.3) and the tier already runs **`cargo deny`**. Make
     `deny` its **own first job** that gates the rest, rather than a step inside
     the same job that has already built everything — cargo-deny needs no build,
     so this is nearly free and it is the difference between a check and a gate.
     Honest limit: advisory databases are reactive; they do not catch a fresh
     malicious release.
2. **The runner is a privilege amplifier for any Forgejo compromise.** Forgejo is
   a LAN+mesh-reachable Go web app with a registry, an SSH port, and a database.
   Compromise it and the runner becomes an execution engine on the same box.
   Under DinD or socket-mount that chain ends at **root on the machine holding
   Immich and Paperless**; under rootless Podman it ends at an unprivileged user
   with two bind-mounted cache directories. **That delta is the entire value of
   the recommendation.**
3. **Availability and the disk.** Nothing confines disk or network I/O in any
   backend (*"no mechanisms available to limit disk or network I/O for any
   container"*). A runaway build can fill the precious 480 GB SSD mirror that
   Immich and Paperless share, or thrash the pool that has a **recurring SAS
   cable IO fault on disk2** (`project_helium_disk2_io_fault`). Put the cache on
   a **scratch** subvolume (§3.2), consider a btrfs **quota** on it, and keep
   ticket 02's `nice`/`ionice` wrapper.
4. **New egress.** Every run reaches crates.io, `data.forgejo.org` (actions), and
   the RustSec advisory DB. Modest and unavoidable for a Rust CI, but it is new
   outbound traffic from the NAS and worth naming rather than discovering.

**Bottom line, in one sentence:** the threat is not the owner's own code, it is
the ~hundreds of third-party crates whose build scripts run on every build — so
the right posture is **not** "accept the risk because it's only my code", and
**also not** "build a VM"; it is **do not give the runner root, and keep the jobs
in containers**, which rootless Podman achieves for the price of one ansible role.

---

## 6. Measurements that must happen on helium before the runner design is locked

Following ticket 02 §4's model. All cheap; none was run (no ssh to helium in this
ticket). **M1–M8 in ticket 02 §4 still stand and are not repeated here.**

**M9 — Does rootless Podman actually work on helium's trixie?** The single
biggest unknown in the recommendation.

```bash
# as the runner user, after `apt install podman` + loginctl enable-linger
podman --version
XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user status podman.socket
podman run --rm docker.io/library/debian:trixie sh -c 'ldd --version | head -1'
# are cgroup limits even available rootless? (§2's --cpus/--memory)
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/cgroup.controllers
```

Expect `glibc 2.41` and a podman ≥ 5.3 (per the documented IPv6 caveat). A podman
older than 5.3 is not fatal but changes the network story. **The
`cgroup.controllers` line must contain both `cpu` and `memory`** — if it does not,
`container.options: --cpus/--memory` are inert and `nice`/`ionice` is the only
contention lever (§2).

**M9b (the one genuinely new risk) — the smoke gate under rootless Podman, not
Docker.** Ticket 02 §2.5 verified cage+grim under **Docker**; podman's rootless
userns and seccomp profile are a different environment.

```bash
podman run --rm --shm-size=256m <ci-image-tag> just smoke
# and, deliberately, to see the SIGBUS failure mode once:
podman run --rm --shm-size=1m  <ci-image-tag> just smoke
```

Pass = a 1280×720 PNG with real content and all four assertions; the 1 MiB run
should die `exit 135` / `signal: 7` with no error message, per ticket 02 §2.5.

**Same measurement, second assertion — the §5.2b socket check.** With
`docker_host: "-"` in config and `DOCKER_HOST=…podman.sock` in the unit, a real
job step must find **no** socket:

```yaml
- run: test ! -e /var/run/docker.sock && echo "confined: no docker socket in job"
```

If that fails, the config took the `unix://…` branch and every dependency's
`build.rs` can spawn containers. This is the single check that validates §5.6's
closing claim.

**M10 — Job image glibc/valgrind parity, inside the image.** This is ticket 02's
M2 pointed at the artifact that will actually run:

```bash
podman run --rm <ci-image-tag> sh -c \
  'ldd --version | head -1; valgrind --version; dpkg -l cage grim valgrind libc6 zstd nodejs git | tail -n +6; echo "GLIBC_TUNABLES=${GLIBC_TUNABLES:-unset}"; just preflight'
```

Must report glibc **2.41-12+deb13u3**, valgrind **1:3.24.0-3**, `GLIBC_TUNABLES=unset`,
and `just preflight` green (including the exact string `gungraun-runner 0.19.4`).
**Then run ticket 02's M1 inside this same image** — that is the check that
closes the perf gate's CPU/glibc channel for the environment that will really
run it.

**M11 — `/tmp` and the cache subvolume.** Ticket 02's M3 plus the CI-specific
half:

```bash
findmnt -no FSTYPE,SIZE /tmp; df -h /tmp
findmnt -no FSTYPE,OPTIONS /data/ssd; btrfs subvolume list /data/ssd | grep -i ci
```

Confirms `nodatacow` is actually on the new `ci` subvolume and that `TMPDIR`
inside the job container is not silently a small tmpfs (`cargo mutants
--in-place` avoids the tree copy, but rustc still uses `TMPDIR`).

**M12 — Does the persistent-cache bind mount actually warm the build?** The whole
of §3.2 rests on this.

```bash
# run the workflow twice back-to-back and compare
time (cd /workspace/... && cargo build --locked --all-targets)
du -sh /data/ssd/ci/target /data/ssd/ci/cargo-home
```

Second run should be dramatically faster and `target/` should be ≥ 2 GB. If the
mount silently fails (an unmatched glob is not an error), the symptom is "every
run is cold" — which looks like slowness, not misconfiguration. **Settle §3.2's
open question here:** try the `container.options: --volume …` form first and
confirm from inside a job that `/cache/target` is the host path (`stat -c %d /cache/target`
vs the workspace), then confirm whether it still works with `valid_volumes: []` —
that answers whether `options`-supplied volumes are gated by the allow-list.
Check any glob against <https://github.com/gobwas/glob>.

**M13 — Path length, in the real workspace.** Ticket 02's M5 said the CI path is
the one variable that changes only in CI. Now the path is knowable: it is
`container.workdir_parent` (default `/workspace`) plus the repo path. Record the
actual in-container `pwd` from a real run and re-run ticket 02's M5 with **that
exact length** as one of the two arms.

**M14 — Registration and verdict surfacing, end to end.** Register at
**repository scope** on `projects/lumin`, push a trivial failing workflow, then
confirm: the Actions tab shows it; the commit in the commit list shows a red
status with the context string `<run> / <job> (push)`; and
`GET /api/v1/repos/projects/lumin/actions/runs` returns it. Also decide badges
(`FORGEJO__badges__ENABLED`) *before* the first badge URL is ever fetched, per
§4's shields.io note.

---

## 7. What this means for the map

**1. Ticket 01's "privileged docker-in-docker" is the *default*, not the
requirement — and that is the finding that unblocks this ticket.** The runner's
label grammar has `host` and `lxc` schemes alongside `docker`, and **rootless
Podman is a first-party documented configuration on Debian 13 trixie
specifically**, requiring *"no particular permissions"* — versus the Docker path's
`usermod -aG docker runner`. The map's fog item can be closed with a real
decision rather than a resigned one.

**1b. But the Podman instructions contain a one-character trap (§5.2b).** The
Podman page says you *"must configure the `docker_host` parameter … with the path
to the Podman socket"*, and `docker-access/` says a `unix://` value means the
runner *"will share the socket with the containers"* — which would hand every
dependency's `build.rs` the ability to spawn containers. The source
(`daemon.go::getDockerSocketPath`) shows the escape: **`docker_host: "-"` in
config plus `Environment=DOCKER_HOST=unix://…/podman.sock` in the systemd unit**
connects the runner without mounting the socket into jobs. Both lines are
required; verify with the one-line job step in M9b. **This is a hard acceptance
criterion, not a preference.**

**2. Recommended shape, one line:** **a `forgejo-runner` host binary as an
unprivileged systemd unit, talking to a rootless Podman socket (via `DOCKER_HOST`,
with `docker_host: "-"`), with `docker://`-scheme labels pointing at a
purpose-built Debian 13 job image** —
because it is the only option that keeps jobs containerised (preserving ticket
02's image-digest provenance model) while giving the runner **no root, no
`docker` group, no privileged container, and no second privileged daemon** on the
box holding Immich and Paperless.

**3. Ticket 02 §4's preamble is preserved by this choice — and would have been
invalidated by the `host` alternative.** §4 is written entirely for containers
("pin the job image to Debian 13 / glibc 2.41", "treat the image digest as part
of the perf gate's provenance", "a musl image is disqualifying"). Under
`docker://` labels that stands unchanged, and M1/M2/M4/M5/M6 must run **inside
the job image** exactly as §4 demands. Under a `host` runner it would all need
rewriting: provenance becomes helium's mutable apt state, and the measurements
run in a host shell after all — the very thing §4 warns would "verify the wrong
environment, come back green, and lock the CI design on a false pass." **This is
the strongest single tiebreaker between the two shapes, and it is a
reproducibility argument, not a security one.**

**4. Every default job image is disqualifying for the perf gate, not merely
suboptimal.** `node:22-bookworm` (code default), `data.forgejo.org/oci/node:lts`
(registration default) and `node:20-bookworm` (docs) are all **bookworm /
glibc 2.36**; krypton and helium are **trixie / glibc 2.41**, and ticket 02 §1.3
makes glibc a live `Ir` channel against only 10% uniform headroom. A
purpose-built trixie image is a **hard requirement of the perf gate**, not a
convenience. It also needs `zstd` (or cache restores silently no-op), `nodejs`
(or `actions/checkout` breaks) and `git` ≥ 2.24.3.

**5. Caching is a bind mount, not `actions/cache`.** A real cache server ships
with the runner (`cache.enabled: true` by default, `ACTIONS_CACHE_URL`,
`data.forgejo.org/actions/cache@v4` unwarned) — but tarball round-trips of a
2 GB+ `target/` plus a second `llvm-cov-target` tree are worse than never moving
the bytes. Use `container.valid_volumes` with a **two-entry allow-list** for
`CARGO_HOME` + `CARGO_TARGET_DIR` on a **new `ci` scratch btrfs subvolume**
(`nodatacow`, and automatically outside `restic_backup_source`, which covers
`appdata` only), keep `capacity: 1` (the design depends on it), and keep the
throwaway checkout so `cargo mutants --in-place` stays safe. Expect to need
`cache.actions_cache_url_override` under rootless Podman — documented symptom,
documented fix.

**6. The map's "CI failure notification" fog item can be closed now.** Four
surfaces exist: the Actions tab; **per-job commit statuses on push** (verified in
source — but **not** for scheduled or `workflow_dispatch` runs, which return
`nil`); a real badge endpoint plus a `…/runs/latest` permalink; and a first-party
opt-in **`enable-email-notifications: true`** workflow key, present on the v15
LTS line. Recommend an `if: failure()` step to **ntfy or HA MQTT** (both already
in the fleet) as the primary, with `if: success()` as a heartbeat — because a
silent runner and a green run are indistinguishable.

**7. Two new spec lines with a privacy edge, both one-liners in `stack.env.j2`.**
`[badges] GENERATOR_URL_TEMPLATE` defaults to **img.shields.io** — a status badge
round-trips workflow name and result through a third-party CDN, which is exactly
counter to this map's motive; decide it explicitly. And `LOG_RETENTION_DAYS`
defaults to **365** on a precious 480 GB mirror shared with Immich and Paperless;
a deep-tier run's logs are large.

**8. Register the runner at repository scope on `projects/lumin`.** Free,
documented (*"By ensuring that the tightest registration is used, the scope of
risk from Mallory is reduced"*), and it matches the map's own premise ("lumin
only") exactly. Prefer the **offline** `forgejo forgejo-cli actions register
--secret` path so the token is a machine-minted sops secret rather than a
copy-paste from the web UI, and load it via `token_url:
file:$CREDENTIALS_DIRECTORY/token.txt` + systemd `LoadCredential=` so it never
lands in a config file. **Two caveats that could force a choice (§1.1):** whether
`--scope` accepts `owner/repo` rather than only an owner is **unverified**, and
the subcommand is documented on **v16** while the pin is **15 LTS**. If they
conflict, **keep repository scope and register through the web UI** — the scope is
the security property; the offline path is only ergonomics.

**9. The security bottom line is `build.rs`, not the owner.** The "only my own
code runs here" mitigation is genuine and substantially narrows the threat model
— no other users, no fork PRs, repository-scoped runner — and a multi-tenant CI
threat model should not be imported wholesale. But **`cargo build` executes
hundreds of third-party build scripts and proc macros at full privilege on every
one of 1109 mutant builds**, and that is untouched by every one of those
mitigations. Add **`--locked`** and promote **`cargo deny` to its own gating
first job**; then confine the runner so that a bad crate release lands on an
unprivileged user with two cache directories rather than on root on the box with
the family photo archive.

**10. Ticket 09 inherits three workflow-file rules, one new one, and one question
this ticket makes urgent rather than merely open.** From ticket 02 §1.3: **no
`RUSTFLAGS`/`target-cpu`, no `CARGO_INCREMENTAL`, `GLIBC_TUNABLES` unset**. New
here: **`--locked`**, and the job-image digest as a recorded provenance field in
`docs/perf-calibration.md` alongside rustc/valgrind/glibc.

**The urgent one: where `nice`/`ionice`/`--in-place` live is now on the critical
path, and it is lumin's spec to change, not the runner's (§2).** Ticket 02 §3.4
left it as an open fork; two findings here close off the easy exits. First, if
rootless cgroup delegation is absent (M9), `nice`/`ionice` is the **only**
contention lever — it stops being a complement to `--cpus`/`--memory` and becomes
the whole mechanism. Second, `container.options` has no niceness knob, so a
containerised job cannot be niced from the runner side at all: it lives either in
**a workflow step wrapping the justfile entry point** (CI-only divergence from
spec §2's "the justfile is *the* entry point") or **in the justfile** (a contract
change, through the §8 rule-6 ritual). Ticket 04 cannot decide this and should not
pretend it can — flagging it as a ticket-09 input with a stated preference for the
workflow-step route, since `--in-place` is a CI-only truth (it mutates the
checkout, fine on a throwaway workspace and wrong on a developer's tree).

**5b. Two open sub-questions inside the caching design**, both cheap and both
folded into measurements rather than guessed: **which lever performs the mount**
(`container.options: --volume` vs a workflow-side `container: volumes:` gated by
`valid_volumes` — recommend `options`, so host paths stay in ansible and out of
lumin's git history; M12), and **whether rootless cgroup delegation makes
`--cpus`/`--memory` work at all** (if `cpu` is not delegated to the user slice,
ticket 02's `nice`/`ionice` is the *only* contention lever; M9).

**11. What is still genuinely unverified.** The runner↔Forgejo version
compatibility matrix is not published anywhere (the docs pair `runner:13` with a
current Forgejo; the map pins Forgejo **15 LTS**) — check on first deploy. That
`node:*-bookworm` means glibc 2.36 is a Debian fact I did not verify against a
running image (folded into M10). And rootless Podman equivalence for cage/grim
under a non-Docker userns/seccomp profile is **the one new risk this
recommendation introduces** — M9b, and cheap to settle.
