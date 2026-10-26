#!/usr/bin/env bash
# What Hyprland and AEROLITH report while a game is fullscreen, for when
# fullscreen-profile.sh shows the shell staying on "desktop" (roadmap B06).
#   tools/perf/fullscreen-diagnose.sh [delay seconds, default 20]
# Start it, switch to the game in fullscreen within the delay, and come back
# after it beeps. Window titles are left out; classes are kept.
set -uo pipefail
delay=${1:-20}
out=${XDG_STATE_HOME:-$HOME/.local/state}/aerolith/fullscreen-diagnose-$(date +%Y%m%d-%H%M%S).txt
mkdir -p "$(dirname "$out")"
pid=$(pgrep -xo qs || pgrep -o -f 'quickshell.*aerolith' || true)
shell_dir=$( [ -n "$pid" ] && tr '\0' ' ' </proc/"$pid"/cmdline | sed -n 's/.*-p \([^ ]*\).*/\1/p')
echo "Switch to the game in fullscreen now; reading in ${delay}s."
sleep "$delay"
{
  echo "== hyprland"; hyprctl version -j 2>&1 | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tag"), d.get("commit","")[:12])' 2>&1
  echo "== monitors (name, focused, active/special workspace, size, scale)"
  hyprctl monitors -j 2>&1 | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    print(m.get("name"), "focused" if m.get("focused") else "-", "ws", (m.get("activeWorkspace") or {}).get("id"),
          "special", (m.get("specialWorkspace") or {}).get("id"), "%sx%s@%s" % (m.get("width"), m.get("height"), m.get("scale")))' 2>&1
  echo "== active window (class, workspace, monitor, fullscreen, fullscreenClient, floating, xwayland)"
  hyprctl activewindow -j 2>&1 | python3 -c '
import json, sys
c = json.load(sys.stdin)
print(c.get("class"), "ws", (c.get("workspace") or {}).get("id"), "mon", c.get("monitor"), "fullscreen", repr(c.get("fullscreen")),
      "fullscreenClient", repr(c.get("fullscreenClient")), "floating", c.get("floating"), "xwayland", c.get("xwayland"),
      "size", c.get("size"), "at", c.get("at"))' 2>&1
  echo "== all clients with any fullscreen state"
  hyprctl clients -j 2>&1 | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    if c.get("fullscreen") or c.get("fullscreenClient"):
        print(c.get("class"), "ws", (c.get("workspace") or {}).get("id"), "mon", c.get("monitor"), "fullscreen", repr(c.get("fullscreen")),
              "fullscreenClient", repr(c.get("fullscreenClient")), "mapped", c.get("mapped"))' 2>&1
  echo "== aerolith status"
  if [ -n "$shell_dir" ]; then
    qs -p "$shell_dir" ipc call aerolith status 2>&1 | python3 -c '
import json, sys
s = json.load(sys.stdin)
for k in ("phase", "fullscreen", "fullscreenOwner", "surfacesReleased", "monitor"):
    print(k, s.get(k))' 2>&1
  else
    echo "qs is not running"
  fi
  echo "== gpu"
  lspci -k 2>/dev/null | grep -EA3 'VGA|3D|Display' | grep -E 'VGA|3D|Display|driver in use'
  command -v nvidia-smi >/dev/null && echo "nvidia-smi present" || echo "no nvidia-smi"
  [ -n "$pid" ] && echo "qs DRM fds: $(grep -l '^drm-client-id' /proc/"$pid"/fdinfo/* 2>/dev/null | wc -l)"
  [ -n "$pid" ] && grep -h '^drm-' /proc/"$pid"/fdinfo/* 2>/dev/null | sort -u | head -20
} >"$out" 2>&1
printf '\a'
echo "Done: $out"
cat "$out"
