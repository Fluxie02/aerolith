# shellcheck shell=bash
set -euo pipefail
preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
preview theme saturated off false 1
preview setCase empty
key Down; sleep .1
preview status > "$OUT/empty.json"
preview setCase confirm-reboot
preview inhibitPending
key Return; sleep .1
preview status > "$OUT/inhibited.json"
python3 - "$OUT" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); e=json.loads((p/'empty.json').read_text()); i=json.loads((p/'inhibited.json').read_text())
assert e['selected']==0,e
assert i['pending']=='' and i['event']=='none',i
print('UI-007 session: empty navigation and changed availability checks passed')
PY
alive
