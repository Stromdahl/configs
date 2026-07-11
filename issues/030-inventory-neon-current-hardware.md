---
title: Inventory neon's current hardware after the helium harvest
status: done
priority: high
created: 2026-07-11
closed: 2026-07-11
labels: [epic:neon-gaming, wayfinder:task]
---

## Question

What is *actually* left in the neon chassis right now? `HARDWARE.md` is stale
(pre-teardown) — it still lists a GTX 1070, a Samsung 990 PRO 2 TB NVMe, and
16 GB RAM, but issue 009 freed neon's NVMe (→ likely went to helium) and issue
006 (`immich-gpu-ml`) may have claimed the GTX 1070 for helium. This is the
**keystone** ticket: the GPU and storage decisions both block on ground truth.

Establish, against the running machine:
- **GPU:** is any discrete card still installed? (`lspci | grep -i vga`) Or only
  the i5-6600K's Intel HD 530 iGPU?
- **Storage:** which drives remain — the 480 GB Kingston SATA SSD? the 990 PRO
  NVMe, or is the M.2 slot now empty? (`lsblk`, `nvme list`)
- **RAM:** how many DIMMs / how much is present now (`dmidecode -t memory`).
- **CPU / board:** confirm still i5-6600K on the Z170I (`lscpu`, DMI).

The body is booted on the Debian rescue OS and on the network → run this AFK over
SSH (honor the AGENTS.md SSH rules: `ssh-add -l` first). Resolve by refreshing
`hosts/neon/HARDWARE.md` with the true current spec and recording the delta
(what helium took) in the answer.

Type: task (AFK) · Blocks: 032, 033

## Answer

Inventoried live over SSH via the rescue OS (`debian-rescue` @ 192.168.1.153),
2026-07-11. **The chassis is almost entirely intact** — the helium harvest took
far less than assumed:

| Component | Present now | vs. old spec |
|---|---|---|
| Board | ASUS Z170I PRO GAMING | unchanged |
| CPU | i5-6600K, 4C/4T | unchanged |
| RAM | 16 GB (2× 8 GB DDR4-2133, both slots) | unchanged |
| GPU | **NVIDIA GTX 1070** (`10de:1b81`) | **still installed** — NOT taken |
| Internal storage | **Samsung 990 PRO 2 TB NVMe** (`nvme0n1`) | **still installed** — NOT taken |
| NIC/WiFi | Intel I219-V 1GbE + Atheros QCA6174 | unchanged |

**Only the secondary 480 GB Kingston UV400 SATA SSD was harvested for helium.**
The issue-009 note about "freeing the 1.8 TB NVMe as a backup candidate" was never
acted on. (`sda` in `lsblk` is the USB rescue stick, not an internal drive.)

**Consequences for the map:**
- **No GPU purchase implied** — the GTX 1070 is present and drives 1080p/1440p
  gaming fine. Issue 032 collapses to: does the 1070 clear the target (issue 031),
  and does the Turing-written `nvidia` module drive Pascal cleanly?
- **No storage purchase implied** — a single 2 TB NVMe is ample for OS + library.
  Issue 033 collapses to the boot-model question only (single Debian vs dual-boot
  Windows), which still hangs on the anti-cheat question in issue 031.
- `hosts/neon/HARDWARE.md` refreshed to this ground truth.
