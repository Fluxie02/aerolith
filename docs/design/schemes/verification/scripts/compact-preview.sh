# shellcheck shell=bash
preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
sleep .5
preview theme insane off true 1.25
preview scheme corona
preview setCase literal
sleep .5
shot 01-compact-literal
preview status >"$OUT/status.json"
alive || { echo "FAIL: preview died"; exit 1; }
echo "compact-preview: ok"
