# Runner topology for lumin's deep tier

Type: research
Status: open
Blocked by: 01, 02

## Question

Given a Forgejo instance on helium (ticket 01) and a verdict on what lumin's deep
tier needs from its host (ticket 02): what shape does the CI runner take?

1. **Forgejo Actions runner basics** — `forgejo-runner`, how it registers, labels,
   and how workflows are addressed (`.forgejo/workflows/`). Note Forgejo Actions
   is GitHub-Actions-*shaped* but makes **no compatibility guarantee**, and its
   default runner image is a bare Debian bookworm + node — so the whole toolchain
   in ticket 02's list is the effort's own problem.
2. **Docker runner vs host runner.** Which one can satisfy the smoke gate's
   `cage`/`grim` needs (ticket 02 question 2) and the perf gate's valgrind? A
   container needing `/dev/dri` or extra capabilities pushes toward one answer;
   nothing needing them pushes toward the other. Weigh against helium's own
   `issues/010-non-root-containers` posture (CapDrop=[ALL] is the house style —
   see `project_helium_container_dns_netbird` for where that has bitten before).
3. **Getting the pinned toolchain in.** rustc 1.94.1 + 5 cargo subcommands +
   `gungraun-runner` 0.19.4 + `cage`/`grim`/`valgrind`. Options: a purpose-built
   runner image (built where? by what?), a persistent host runner provisioned by
   ansible, or install-on-every-run (slow, and `cargo install` of 5 tools is
   minutes). Also: **cargo/target caching** — a cold `cargo mutants` build on 6
   cores is the difference between tolerable and absurd.
4. **How the verdict comes back.** What a Forgejo Actions run reports, and where a
   human sees red/green without opening a terminal.

Reconcile with ticket 02's findings — if the smoke gate cannot run headless at
all, say what the runner should do with that gate rather than pretending it can.

Capture findings as `../assets/04-runner-topology-research.md`.
