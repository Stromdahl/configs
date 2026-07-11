---
title: Inventory neon's current hardware after the helium harvest
status: open
priority: high
created: 2026-07-11
closed: null
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
