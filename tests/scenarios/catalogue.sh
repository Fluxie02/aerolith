# shellcheck shell=bash
# Dump the command catalogue (with the AI module present) for
# tools/gen-commands-doc.py. Run with AI=1.
sleep 3
ipc commands >"$OUT/commands.json"
python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); assert len(c) > 30, len(c); print(len(c), "commands")' "$OUT/commands.json" || { echo "FAIL: bad catalogue"; exit 1; }
echo "catalogue: ok"
