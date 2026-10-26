# shellcheck shell=bash
# Performance measurement: CPU time and memory of the quickshell process in
# three states, read from /proc/<pid>/stat and /proc/<pid>/status.
#   AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh
# PERF_IDLE_S / PERF_OPEN_S set the window lengths (defaults 120 / 30).
# This runs under headless sway with software rendering (pixman, Qt software
# backend): rendering cost is higher than on a GPU, idle cost is comparable.
# Results go to $OUT/perf.json; docs/PERFORMANCE.md explains how to read them.
fail() { echo "FAIL: $*"; exit 1; }
idle_s=${PERF_IDLE_S:-120}
open_s=${PERF_OPEN_S:-30}
hz=$(getconf CLK_TCK)

cpu_ticks() { awk '{ print $14 + $15 }' "/proc/$QS_PID/stat"; }
rss_kb() { awk '/^VmRSS:/ { print $2 }' "/proc/$QS_PID/status"; }
hwm_kb() { awk '/^VmHWM:/ { print $2 }' "/proc/$QS_PID/status"; }
threads() { awk '/^Threads:/ { print $2 }' "/proc/$QS_PID/status"; }
wakeups() { awk '/^voluntary_ctxt_switches:/ { v = $2 } /^nonvoluntary_ctxt_switches:/ { n = $2 } END { print v + n }' "/proc/$QS_PID/status"; }

# measure <name> <seconds>: CPU % of one core, context switches per second.
results=()
measure() {
  local name=$1 secs=$2 t0 t1 w0 w1 s0 s1
  t0=$(cpu_ticks); w0=$(wakeups); s0=$(date +%s.%N)
  sleep "$secs"
  t1=$(cpu_ticks); w1=$(wakeups); s1=$(date +%s.%N)
  results+=("$(python3 -c '
import json, sys
name, t0, t1, w0, w1, s0, s1, hz, rss, thr = sys.argv[1:]
wall = float(s1) - float(s0)
cpu = (int(t1) - int(t0)) / int(hz)
print(json.dumps({"state": name, "seconds": round(wall, 1), "cpu_seconds": round(cpu, 2),
  "cpu_percent_of_one_core": round(100 * cpu / wall, 2),
  "context_switches_per_s": round((int(w1) - int(w0)) / wall, 1),
  "rss_mib": round(int(rss) / 1024, 1), "threads": int(thr)}))
' "$name" "$t0" "$t1" "$w0" "$w1" "$s0" "$s1" "$hz" "$(rss_kb)" "$(threads)")")
  echo "${results[-1]}"
}

# Let startup (font loading, first frames, DesktopEntries scan) finish.
sleep 15
alive || fail "quickshell died during startup"
measure idle-strip "$idle_s"

ipc open systems; sleep 3
measure systems-bay-open "$open_s"
ipc close; sleep 3

ipc open command; sleep 2
measure command-core-open "$open_s"
ipc close; sleep 5

measure idle-after-use "$open_s"
alive || fail "quickshell died"

{
  printf '{"cpus": %s, "clk_tck": %s, "peak_rss_mib": %s, "quickshell": "%s", "renderer": "QT_QUICK_BACKEND=software, WLR_RENDERER=pixman", "results": [' \
    "$(nproc)" "$hz" "$(python3 -c "print(round($(hwm_kb)/1024,1))")" "$(qs --version 2>/dev/null | head -1)"
  (IFS=,; printf '%s' "${results[*]}")
  printf ']}\n'
} >"$OUT/perf.json"
python3 -m json.tool "$OUT/perf.json" >/dev/null || fail "perf.json is not valid JSON"
echo "perf: ok"
