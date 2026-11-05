# shellcheck shell=bash
# Deterministic Ground capture for a before/after pixel comparison. Select the
# reference tree through SHELL_PATH. All edits are in the container's copy.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/ground-pixels-shell"
SHELL_DIR="$HOME/ground-pixels-shell"
python3 - "$SHELL_DIR/components/Instrumentation.qml" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1]); s = p.read_text()
# Freeze only host-dependent sampled values, identically in both source trees.
s = s.replace('T.formatPercent(Telemetry.cpu.total)', '"25%"')
s = s.replace('T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)', '"50%"')
s = s.replace('Telemetry.cpu.cores', '[0, 25, 50, 75]')
p.write_text(s)
p = Path(sys.argv[2]); config = json.loads(p.read_text()) if p.exists() else {}
config.setdefault('theme', {})['motion'] = 'off'
config.setdefault('strip', {})['visible'] = False
config.setdefault('tour', {})['enabled'] = False
p.write_text(json.dumps(config))
PY
qs -p "$SHELL_DIR" >"$OUT/capture-qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
ready=0
for _ in $(seq 60); do
  if ipc status >"$OUT/capture-status.json" 2>/dev/null; then ready=1; break; fi
  sleep .1
done
[ "$ready" = 1 ] || fail "capture shell did not become ready"
sleep 3
# Use raw RGB data so the host can compare pixels without a graphics package.
grim -t ppm "$OUT/ground.ppm"
shot ground
alive || fail "capture shell died"
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/capture-qs.log"; then fail "QML errors"; fi
echo 'ground-pixels: captured (fixed telemetry, motion off, strip hidden)'
