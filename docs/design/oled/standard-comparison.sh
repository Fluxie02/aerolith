qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/standard-copy"
SHELL_DIR="$HOME/standard-copy"
python3 - "$SHELL_DIR/modules/strip/StripClock.qml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); p.write_text(p.read_text().replace('text: root.timeText','text: "12:34"').replace('text: root.dateText','text: "WED 04 NOV"'))
p=p.parents[2]/'components/Instrumentation.qml'
p.write_text(p.read_text().replace('readonly property string mem: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)','readonly property string mem: "50%"'))
PY
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
sleep 3
for n in 1 2; do
  grim -o "HEADLESS-$n" "$OUT/standard-$n.png"
done
ipc status >"$OUT/status.json"
echo 'standard screenshots: ok'
