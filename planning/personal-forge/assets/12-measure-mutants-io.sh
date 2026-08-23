#!/usr/bin/env bash
# Measure disk WRITE volume of one full `cargo mutants` run.
# TMPDIR is forced onto a real disk because krypton's /tmp is tmpfs (RAM) —
# leaving it there would measure zero and be non-transferable to helium.
set -uo pipefail
DEV=nvme0n1
SECT=512
out=/tmp/claude-1000/-home-ms--dotfiles/b04eddb3-869f-4f5d-bea0-9d51c6164d4a/scratchpad/mutants-io.txt
r() { awk -v d="$DEV" '$3==d {print $10}' /proc/diskstats; }   # field 10 = sectors written
before=$(r); t0=$(date +%s)
cd /home/ms/projects/lumin
TMPDIR=/home/ms/.cache/mutants-measure cargo mutants > /tmp/claude-1000/-home-ms--dotfiles/b04eddb3-869f-4f5d-bea0-9d51c6164d4a/scratchpad/mutants-run.log 2>&1
rc=$?
after=$(r); t1=$(date +%s)
{
  echo "rc=$rc"
  echo "elapsed_s=$((t1-t0))"
  echo "sectors_written=$((after-before))"
  echo "GiB_written=$(awk -v s=$((after-before)) -v b=$SECT 'BEGIN{printf "%.2f", s*b/1073741824}')"
  tail -20 /tmp/claude-1000/-home-ms--dotfiles/b04eddb3-869f-4f5d-bea0-9d51c6164d4a/scratchpad/mutants-run.log
} > "$out" 2>&1
