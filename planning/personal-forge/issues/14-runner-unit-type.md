# The runner's systemd unit type — system-with-`User=` or `systemd --user`?

Type: grilling
Status: resolved
Assignee: claude (session 2026-08-24b)

## Question

Graduated 2026-08-24, on review after ticket 13 emptied the frontier. This is **not
new fog** — it is a decision two closed tickets deliberately left open, and it fell
between them rather than being shelved. It has to be settled before the runner's
ansible task can be written.

**Where it comes from.** [Ticket 12](12-adopt-runner-shape.md) §The spec, item 1:

> **OPEN implementation detail: system unit with `User=` vs. `systemd --user` unit.**
> Ticket 04 does not disambiguate it (it says only "unprivileged systemd unit"), the
> owner was not asked, and the argument I originally used for a system unit — access
> to the `io` controller — **I withdrew as inapplicable to jobs**. So this is
> deliberately left open rather than invented here.

And [ticket 09](09-lumin-definition-of-done.md) parked work **behind** it: systemd
resource values *"belong to whoever closes the unit type"*, because *"picking numbers
for an unnamed unit would be invention."* So this blocks a real spec detail in two
places, which is why it is a ticket and not an implementer's coin-flip.

**What is already established — do not re-research it:**

- The `io` argument for a system unit is **dead**: ticket 12's M9 measurement found
  `cpu memory pids` **are** cgroup-delegated but **`io` never is**, and every device
  is `mq-deadline`, so `ionice` and cgroup `io` are unavailable to jobs *by
  construction*. Ticket 09 dropped `nice` on the same finding.
- The hazard ticket 12 names: a **system** unit has no ordering dependency on
  `user@<uid>.service`, so `/run/user/<uid>/podman/podman.sock` may not exist when it
  starts — it needs `After=`/retry. A **`systemd --user`** unit sidesteps that.
- The socket is already fixed as a **`systemd --user`** unit for the
  `forgejo-runner` user with `loginctl enable-linger` (ticket 12 §The spec item 2,
  from Forgejo's own documented rootless-Podman pattern), and both acceptance lines
  are mandatory: `docker_host: "-"` **and** `Environment=DOCKER_HOST=…`.
- Rootless Podman's prerequisites are **absent on helium** and already parked in the
  map's fog as unscoped ansible work (podman/uidmap/slirp4netns/fuse-overlayfs + a
  non-colliding subuid range + linger). Whichever unit type wins rides along with it.

**The apparent lean, stated honestly so the grilling can attack it:** the facts point
at `systemd --user` — it removes the ordering hazard rather than papering over it, and
it matches the pattern the socket already uses, so the runner and its socket share one
lifecycle and one lingering user. The counter worth putting to the owner is
**operability**: a system unit is what every other helium service is, so it shows up in
`systemctl status` and ansible's `systemd` module without a `--user`/`XDG_RUNTIME_DIR`
dance, and it is the shape the rest of `ansible/roles/` already knows how to write.
That is a real house-consistency argument against a real correctness argument.

## What to settle

1. **The unit type**, on the two arguments above.
2. **The systemd resource values ticket 09 parked** — now nameable: `MemoryMax`,
   `CPUWeight`/`CPUQuota`, `TasksMax` on the chosen unit, given helium is a 16 GB /
   6C6T box that also runs Jellyfin transcodes, Immich ML, Paperless OCR and the *arr
   stack, and that `cpu memory pids` are the only delegated controllers. Whatever is
   chosen must not contradict the map's premise that *helium being loaded sometimes is
   explicitly acceptable*.
3. **The `After=`/retry shape** if the system unit wins, so the hazard is closed in
   the spec rather than discovered on first boot.

Output: an amendment to ticket 12's §The spec item 1 (it stops saying OPEN), the
resource values ticket 09 was waiting on, and a note on the map so no one reads the
empty frontier as "the runner spec is finished".

## Answer (resolved 2026-08-24)

**`systemd --user`, and every real limit is on the container or the slice — nothing
on the unit.** The owner's decisions, in order: *"systemd --user, the ordering
correctness wins"*; the memory and CPU recommendations accepted as put; *"confirmed,
nothing on the unit"*.

### 1. The unit type — `systemd --user` for the `forgejo-runner` user

A `systemd --user` unit, enabled under `loginctl enable-linger`, copying
`ansible/roles/syncthing/tasks/service.yml`'s pattern verbatim: `getent` the uid →
enable linger **first** → `ansible.builtin.systemd` with `scope: user` and
`XDG_RUNTIME_DIR=/run/user/<uid>`.

**Two premises moved, and both moved toward this answer:**

- **The house-consistency counter-argument is mostly spent.** Ticket 12 framed this as
  "a real house-consistency argument against a real correctness argument", on the
  grounds that a system unit "is the shape the rest of `ansible/roles/` already knows
  how to write". That was true when 12 wrote it and is not true now: the **syncthing
  role already does the whole `systemd --user` dance** — uid lookup, linger-first
  ordering, `scope: user` with `XDG_RUNTIME_DIR` — with a comment explaining why it is
  a user service. And `ms` is **lingering on helium right now**
  (`ssh ms@192.168.1.191 loginctl list-users` → `1000 ms yes active`). So the pattern
  is committed, working, and copyable; what remained of the counter-argument was
  operator friction, not ansible work.
- **`cpuset` is not delegated either — the system unit's last capability argument dies
  the same death as `io`.** helium ships `Delegate=pids memory cpu` on `user@.service`
  (`ssh ms@192.168.1.191 systemctl cat user@.service | grep -i delegate`), and
  `/sys/fs/cgroup/user.slice/user-1000.slice/cgroup.{controllers,subtree_control}` both
  read exactly `cpu memory pids`. Podman's docs permit `--cpuset-cpus` rootless on
  cgroups v2, but the controller is absent from the delegated subtree, so hard CPU
  pinning is unavailable **by construction** — the same shape ticket 12's M9 used to
  kill `io`. Resurrecting it would have been a regression in this map's reasoning.
  (It could be bought with `Delegate=cpuset` on `user@.service`, but that is a
  system-wide change to *every* user session, not a runner-local one. Not taken.)

Accepted cost, stated at decision time: a `systemd --user` unit is invisible to a
plain `systemctl status forgejo-runner` / `journalctl -u` from a root shell. Debugging
it needs `machinectl shell forgejo-runner@` or
`sudo -u forgejo-runner XDG_RUNTIME_DIR=/run/user/<uid> systemctl --user status`,
which is unlike every other helium service. The owner took the ordering correctness
over that friction.

**What the choice buys:** the ordering hazard ticket 12 named — a system unit with no
dependency on `user@<uid>.service`, so `/run/user/<uid>/podman/podman.sock` may be
absent at start — **ceases to exist** rather than being papered over with `After=` and
a retry loop. Runner and socket share one manager, one lifecycle, one lingering user.
It also demotes ticket 12's mandatory
`Environment=DOCKER_HOST=unix:///run/user/<uid>/podman/podman.sock` from a
`sudo -u … XDG_RUNTIME_DIR=…` dance to a plain `Environment=` line. Both of 12's
acceptance lines stand unchanged: that `Environment=` **and** `docker_host: "-"` in
the runner config.

### 2. Where the limits actually live — the reframe this ticket turned on

Ticket 09 parked "systemd resource values" here. **The framing was wrong, and the
correction matters more than the numbers.**

With `docker://` labels against `/run/user/<uid>/podman/podman.sock`, the job container
is created by the **podman user service**, not by the runner process. Its cgroup lands
under `user-<uid>.slice` as a `libpod-*` scope — **not inside
`forgejo-runner.service`'s cgroup**. So `MemoryMax`/`CPUWeight`/`TasksMax` on the
runner unit would govern a Go daemon that polls every 2s and streams logs — tens of MB
— and would do **nothing** to the 25–40 min mutants job.

The real channel is `container.options` in the runner config, which Forgejo documents
as *"other options to be used when the container is started"* — free-form
`podman run` flags (verified in
`code.forgejo.org/forgejo/runner/…/config.example.yaml`, the `container:` block).
This is the **same channel ticket 09 already reserved** for the custom seccomp profile
(`personality(0x40000)`), so it costs no new mechanism.

### 3. Memory — `--memory=6g --memory-swap=6g`

Measured, not guessed: a **cold** `cargo build --workspace --all-targets -j6` of lumin
peaks at **3.48 GB** (`memory.peak` of a scope with `MemoryAccounting=yes`; 137 crates
compiled from `proc-macro2` up, 2.7 GB target dir, 22 s wall on krypton's 16 threads).
`--all-targets` means test-binary links are in that figure. `cargo mutants` rebuilds
incrementally after the baseline, so **3.48 GB is a ceiling, not a typical**.

Command, so the next ticket can re-run it rather than re-derive it:

```
systemd-run --user --scope -p MemoryAccounting=yes --unit=lumin-mem-probe -q bash -c \
  'export CARGO_TARGET_DIR=/tmp/lumin-target; cargo build --workspace --all-targets -j6 >/dev/null 2>&1;
   cat /sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)/memory.peak'
```

**6g** gives ~1.7× headroom over the peak (mutants can change codegen shape and a
`-j6` link storm is spiky). **`--memory-swap` equal to `--memory` means the container
gets zero swap**, and that half is what protects the box: helium already has
**4.1 GB in swap** on the NVMe root (`/proc/swaps`, 12.3 GB partition on
`nvme0n1p3`), which is the **same disk** ticket 12 put the ~80 MB/s mutants cache on.
A job allowed to swap freely would thrash that disk while also driving the cache IO at
it. Denied swap, a runaway build is OOM-killed **inside** the container: the job goes
red and the box stays responsive.

Context for the numbers: helium at decision time was 15.8 GB total / 11.9 GB available
/ 3.9 GB used, load 0.58 on 6 cores, with `qbittorrent-nox` alone at 3.4 GB RSS.

**Accepted cost, named:** an OOM-killed build reads as a *test failure* in the CI
verdict, not as "the runner ran out of room" — a false-negative shape. The only cheap
mitigation is that 6g is generous enough it should not fire. **Uncapped was rejected
for a specific reason:** with no container limit the kernel OOM killer picks the
largest process on the box, which today is qbittorrent at 3.4 GB — the wrong victim.

### 4. CPU — `CPUWeight=20` on a `user-<uid>.slice` drop-in, no `--cpus` cap

The job gets all 6 cores when nothing else wants them and yields hard the moment a
Jellyfin transcode, Immich ML pass or Paperless OCR run shows up.

**Why the drop-in and not `--cpu-shares` on the container:** cgroup weight only ranks
*siblings*. A container weight would rank the job against other things inside
`user.slice` — i.e. nothing — and would **not** make it defer to Jellyfin at all. That
competition happens at `user.slice` vs `system.slice`, which is exactly where the
drop-in sits: `/etc/systemd/system/user-<uid>.slice.d/50-forgejo-runner.conf`. The uid
is looked up the way the syncthing role already looks one up; never hardcoded.

**Why not a hard `--cpus=4`:** it was the live alternative and it is *predictable* —
always 2 cores' worth of headroom for the rest of the box, and no root-owned file in
an otherwise user-scoped role. It was rejected because it throttles **even when the
box is idle**, which is the common case (load 0.58), taking the deep tier from ~25–40
min to roughly ~35–55 min for no benefit most of the time. Weight-based yielding is
the shape that matches this map's own premise that *helium being loaded sometimes is
explicitly acceptable*.

**Accepted cost, named:** a job's duration now varies with whatever else the box is
doing, so "25–40 min warm" becomes a wider band and there is no stable baseline for
judging whether a run is stuck. This is a real loss against `--cpus=4`, taken
knowingly.

Note the drop-in is a **second, system-scoped artifact** in a role whose unit is
user-scoped. That is not a contradiction of §1 — the runner's *lifecycle* is
user-managed; its *slice's* weight is only settable by root.

### 5. Nothing on the unit — ticket 09's parked values, answered

`forgejo-runner.service` (user) gets **no `MemoryMax`, no `CPUWeight`, no
`TasksMax`**. Per §2 the unit's cgroup holds only the daemon, so a cap there cannot
protect the box and can only convert a harmless daemon into a dead one mid-job.

**`--pids-limit`: left at podman's default of 2048** — checked rather than picked.
2048 comfortably fits a `-j6` rustc fan-out plus linkers, and `pids` **is** delegated,
so the default is genuinely enforced rather than nominal. Nothing to invent.

This is ticket 09's answer, **recorded here rather than by editing 09**, whose §3/§6/§7
the map fixes as proposed-until-reopened; reaching into it would reopen a deliberately
shelved record.

### 6. Ordering — one line, not a retry loop

`Wants=podman.socket` + `After=podman.socket` in the user unit. The ticket's question 3
(the `After=`/retry shape for a system unit) is **moot by construction** — but the
runner still must not start before its socket exists, and same-manager ordering makes
that one line. `podman.socket` stays a `systemd --user` unit for the `forgejo-runner`
user with linger, exactly as ticket 12 §The spec item 2 has it.

### What this leaves for the build issues

All of it rides along with the rootless-Podman prerequisites already parked in the
map's fog (podman / uidmap / slirp4netns / fuse-overlayfs, a non-colliding subuid range,
linger). Added by this ticket: the `user-<uid>.slice` drop-in, and the
`container.options` line that now carries **three** things at once —
`--memory=6g --memory-swap=6g`, the custom seccomp profile from ticket 09, and nothing
else.
