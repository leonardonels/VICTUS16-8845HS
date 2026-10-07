#!/bin/bash
# All-core load test: N busy loops pinned to CPUs 0..N-1 for S seconds, printing the average clock
# and the package power once a second. Needs no root.
#   tools/load-test.sh [N=16] [S=10]
# Healthy on AC: 16 threads hold 3+ GHz at 45 W (default) or ~60 W (with the power limits).
# The 2026-10-07 fault: within 1-2 s the clock falls to ~1 GHz and power to ~8 W.
N=${1:-16}
S=${2:-10}

ppt=""
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = amdgpu ] && [ "$(cat "$h/power1_label" 2>/dev/null)" = PPT ] && ppt=$h/power1_input
done

pids=()
for i in $(seq 0 $((N - 1))); do
  taskset -c "$i" bash -c 'while :; do :; done' &
  pids+=($!)
done
trap 'kill "${pids[@]}" 2>/dev/null' EXIT
for t in $(seq 1 "$S"); do
  sleep 1
  clock=$(awk '{s += $1} END {printf "%.0f", s / NR / 1000}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq)
  power=$([ -n "$ppt" ] && awk '{printf "%.1f W", $1 / 1e6}' "$ppt" || echo "unknown")
  printf 'threads %2d  t=%2ds  clock %4s MHz  package %s\n' "$N" "$t" "$clock" "$power"
done
