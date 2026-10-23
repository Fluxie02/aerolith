# shellcheck shell=bash
# Sourced by the existing, unmodified tools/headless/session.sh.
set -euo pipefail
kill "$QS_PID"
wait "$QS_PID" 2>/dev/null || true
cp "$OUT/qs.log" "$OUT/bootstrap-qs.log"
python3 "$SRC/docs/design/counterphase/recordings/drive.py"
