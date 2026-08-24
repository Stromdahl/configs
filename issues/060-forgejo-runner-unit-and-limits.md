---
title: Run the Forgejo CI runner as a confined user unit with its resource limits
status: open
priority: medium
created: 2026-08-24
closed: null
labels: [epic:forge]
---

## Description

The `forgejo-runner` daemon runs as a `systemd --user` unit for the dedicated runner
user, registered at **repository scope on lumin** (not instance-wide), executing jobs in
rootless Podman containers from the baked job image — bounded so that a runaway build
fails the job rather than the box.

Depends on `issues/058` (the user, the socket, the prerequisites), `issues/059` (the
job image), and `issues/063` (the lumin repository must exist on the forge before a
repo-scoped registration token can be issued).

**The unit type is decided and the reasoning is load-bearing.** A `systemd --user` unit
makes the ordering hazard cease to exist rather than papering over it: runner and podman
socket share one manager, one lifecycle, one lingering user, so a plain ordering
dependency replaces an `After=` plus retry loop against a socket that might not be
there yet. Both pointers at the socket are mandatory — the runner's own config setting
**and** the environment variable — because either alone leaves the socket mounted into
every job.

**Where the limits live is the part most likely to be got wrong.** Job containers are
created by the podman *user service*, not by the runner process, so they land in the
user slice and **not** inside the runner unit's cgroup. Limits on the unit would govern
a Go daemon that polls every two seconds and does nothing to a 25–40 minute mutation
run. So:

- **Nothing on the unit** — no memory cap, no CPU weight, no task limit. A cap there
  cannot protect the box and can only kill a harmless daemon mid-job.
- **Memory on the container**, at roughly 1.7× the measured cold-build peak, **with
  swap denied** (the swap half is what protects the box: helium already has gigabytes in
  swap on the same NVMe as the CI cache, and a job allowed to swap freely would thrash
  that disk while also driving cache IO at it). Denied swap, a runaway build is
  OOM-killed inside the container: the job goes red and the box stays responsive.
  Accepted cost, named at decision time: an OOM kill reads as a *test failure*, not as
  "the runner ran out of room" — a false-negative shape, mitigated only by the limit
  being generous. Uncapped was rejected specifically because the kernel would then pick
  the largest process on the box, which is qbittorrent, the wrong victim.
- **CPU as a weight on a root-owned drop-in for the runner user's slice**, not as a
  container share and not as a hard core cap. Cgroup weight only ranks siblings, so a
  container-level share would rank the job against nothing and would **not** make it
  defer to a Jellyfin transcode; the competition happens at the user-slice level, which
  is where the drop-in sits. A hard core cap was the live alternative and was rejected
  because it throttles even when the box is idle — the common case. Accepted cost: job
  duration now varies with whatever else the box is doing, so there is no stable
  baseline for judging whether a run is stuck. Note the drop-in is a *system*-scoped
  artifact in an otherwise user-scoped role; that is not a contradiction — the runner's
  lifecycle is user-managed, its slice's weight is only settable by root.
- The process limit stays at podman's default, which was checked rather than picked.

The container options line carries exactly three things: the memory pair, the custom
seccomp profile (default plus the one syscall the perf tooling needs), and nothing else.

The job cache is a persistent bind mount on the NVMe root disk — not the action-based
cache, not a new mirrored subvolume — and the temp directory must be pointed explicitly
at it, or the mutation tool's default scratch location applies, which is fatal on a
16 GB box with a ~10 GB target dir.

The space guard is three parts, because two of them each miss a real case: a first step
failing the run when free space is below the threshold, a cleanup step removing the
scratch tree **on exit including on failure**, and a pre-job sweep of stale scratch dirs
(cleanup-on-exit misses a killed job). Plus an advisory disk-free sensor over the
existing metrics path. No filesystem project quota — it would need a reboot.

Third-party build-script execution is knowingly accepted: moving CI here changes blast
radius, not likelihood, and rootless confinement is what bounds the radius.

## Acceptance criteria

- [ ] The runner is a `systemd --user` unit for the runner user, ordered after the
      podman socket, and comes back automatically after a reboot with nobody logged in.
- [ ] It is registered at repository scope on lumin, not instance-wide.
- [ ] Both socket pointers are set, and an inspection of a running job container shows
      **no** podman/docker socket mounted inside it.
- [ ] The runner unit itself carries no memory, CPU or task limits.
- [ ] A job container is created with the memory pair and the seccomp profile, and
      exceeding the memory limit kills the job rather than anything else on the box.
- [ ] The CPU weight drop-in exists on the runner user's slice, with the uid looked up
      rather than hardcoded.
- [ ] A job's cache and temp directory both live on the NVMe bind mount.
- [ ] A job aborted mid-run leaves no scratch tree behind after the next run's pre-job
      sweep, and a run starting with insufficient free space fails at the first step.
