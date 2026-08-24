# The runner's systemd unit type — system-with-`User=` or `systemd --user`?

Type: grilling
Status: open

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
