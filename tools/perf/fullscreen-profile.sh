#!/usr/bin/env bash
# Measures what AEROLITH costs before, during and after a fullscreen game on
# real hardware (roadmap B06/F04). Run it in a Hyprland session with the
# shell running:
#   tools/perf/fullscreen-profile.sh [seconds per phase, default 30]
# It asks you to start the game in fullscreen, then to leave fullscreen, and
# writes a JSON report (and prints a summary) to
# ${XDG_STATE_HOME:-~/.local/state}/aerolith/fullscreen-profile-<time>.json.
#
# What it reads, all without root:
# - the shell's GPU memory from the kernel's DRM fdinfo
#   (/proc/<pid>/fdinfo, drm-memory-* / drm-total-*; amdgpu, i915, xe,
#   nouveau) or, on the NVIDIA driver, nvidia-smi's per-process memory;
# - CPU time and context switches (wakeups) from /proc/<pid>/stat and status;
# - resident memory;
# - the shell's phase (desktop / suspended) from its own status command;
# - whether Hyprland reports direct scanout enabled (render:direct_scanout).
# It does not measure the game's frame times: run the game with MangoHud's
# frame-time log in both shell states for that, and keep the two logs.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
secs=${1:-30}
command -v hyprctl >/dev/null || { echo "Run this inside a Hyprland session." >&2; exit 1; }
pid=$(pgrep -xo qs || pgrep -o -f 'quickshell.*aerolith' || true)
[ -n "$pid" ] || { echo "AEROLITH (qs) is not running." >&2; exit 1; }
shell_dir=$(tr '\0' ' ' </proc/"$pid"/cmdline | sed -n 's/.*-p \([^ ]*\).*/\1/p')
out_dir=${XDG_STATE_HOME:-$HOME/.local/state}/aerolith
mkdir -p "$out_dir"
out=$out_dir/fullscreen-profile-$(date +%Y%m%d-%H%M%S).json
hz=$(getconf CLK_TCK)

# Sum each DRM client once (several fds can share a client id). Prints
# "<vram KiB> <total KiB>" for the process; drivers name the regions
# differently, so every drm-memory-*/drm-total-* key counts toward total
# and the vram/local ones toward vram.
drm_kib() {
  python3 - "$1" <<'PY'
import os, re, sys
pid = sys.argv[1]
clients = {}
for fd in os.listdir(f"/proc/{pid}/fdinfo"):
    try:
        text = open(f"/proc/{pid}/fdinfo/{fd}").read()
    except OSError:
        continue
    m = re.search(r"^drm-client-id:\s*(\d+)", text, re.M)
    if not m:
        continue
    vals = {}
    for k, v, unit in re.findall(r"^(drm-(?:memory|total)-[\w-]+):\s*(\d+)\s*(\w*)", text, re.M):
        vals[k] = int(v) * {"": 1 / 1024, "KiB": 1, "MiB": 1024, "GiB": 1024 * 1024}.get(unit, 1)
    clients[m.group(1)] = vals
vram = total = 0.0
for vals in clients.values():
    t = {k: v for k, v in vals.items() if k.startswith("drm-total-")} or vals
    for k, v in t.items():
        total += v
        if re.search(r"vram|local", k):
            vram += v
print(int(vram), int(total), len(clients))
PY
}
# The NVIDIA driver does not fill DRM fdinfo; its XML report lists the
# memory of graphics clients ("G") as well.
nvidia_kib() {
  command -v nvidia-smi >/dev/null || return 0
  nvidia-smi -q -x 2>/dev/null | python3 -I "$here/nvidia-process-mem.py" "$1" || true
}
cpu_ticks() { awk '{ print $14 + $15 }' /proc/"$pid"/stat; }
wakeups() { awk '/^voluntary_ctxt_switches:/ { v = $2 } /^nonvoluntary_ctxt_switches:/ { n = $2 } END { print v + n }' /proc/"$pid"/status; }
rss_kib() { awk '/^VmRSS:/ { print $2 }' /proc/"$pid"/status; }
phase() { qs -p "$shell_dir" ipc call aerolith status 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("phase", "unknown"))' 2>/dev/null || echo unknown; }

declare -a rows=()
measure() {
  local name=$1 t0 t1 w0 w1 nv vram total clients cpu wps
  t0=$(cpu_ticks); w0=$(wakeups)
  sleep "$secs"
  t1=$(cpu_ticks); w1=$(wakeups)
  read -r vram total clients <<<"$(drm_kib "$pid")"
  nv=$(nvidia_kib "$pid")
  cpu=$(awk -v a="$t0" -v b="$t1" -v hz="$hz" -v s="$secs" 'BEGIN { printf "%.3f", (b - a) * 100 / hz / s }')
  wps=$(awk -v a="$w0" -v b="$w1" -v s="$secs" 'BEGIN { printf "%.2f", (b - a) / s }')
  rows+=("$(printf '{"phase_name":"%s","shell_phase":"%s","cpu_percent":%s,"wakeups_per_s":%s,"rss_kib":%s,"drm_vram_kib":%s,"drm_total_kib":%s,"drm_clients":%s,"nvidia_kib":%s}' \
    "$name" "$(phase)" "$cpu" "$wps" "$(rss_kib)" "$vram" "$total" "$clients" "${nv:-null}")")
  echo "  $name: shell phase $(phase), CPU ${cpu}% of a core, ${wps} wakeups/s, VRAM $((vram / 1024)) MiB (all GPU memory $((total / 1024)) MiB${nv:+, NVIDIA $((${nv%.*} / 1024)) MiB}), RSS $(( $(rss_kib) / 1024 )) MiB"
}

echo "Measuring the desktop for ${secs}s; leave the shell idle."
measure desktop
read -r -p "Start the game in fullscreen, wait until it is in play, then press Enter. " _
measure fullscreen
read -r -p "Leave fullscreen (or quit the game), then press Enter. " _
sleep 2
measure after

scanout=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("int"))' 2>/dev/null || echo unknown)
{
  printf '{"pid":%s,"seconds":%s,"hyprland":"%s","direct_scanout_option":"%s","phases":[' "$pid" "$secs" \
    "$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag",""))' 2>/dev/null)" "$scanout"
  (IFS=,; printf '%s' "${rows[*]}")
  printf ']}\n'
} >"$out"
echo "Report: $out"
echo "render:direct_scanout = $scanout (0 off, 1 on, 2 auto). The shell does not change it."
