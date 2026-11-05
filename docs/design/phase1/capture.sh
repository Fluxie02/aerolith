# Run inside the standard disposable headless container; writes config only there.
fail() { echo "FAIL: $*"; exit 1; }
tour() { qs -p "$SHELL_DIR" ipc call tour "$@"; }
snapshot() { qs -p "$SHELL_DIR" ipc call phase1Evidence snapshot >"$OUT/ui.json"; }
assert_ui() {
  snapshot
  python3 - "$OUT/ui.json" "$1" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert eval(sys.argv[2]), s
PY
}
probe_click() {
  local point
  snapshot
  point=$(python3 - "$OUT/ui.json" "$1" "$2" "$SCALE" <<'PY'
import json, sys
s=json.load(open(sys.argv[1])); p=next(p for p in s[sys.argv[2]]['parts'] if p['name']==sys.argv[3]); scale=float(sys.argv[4])
assert p['w'] > 0 and p['h'] > 0, p
print(round((p['x']+p['w']/2)*scale), round((p['y']+p['h']/2)*scale))
PY
)
  click $point
}
# Instrument only a temporary copy. Production services and UI stay intact.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/phase1-shell"
SHELL_DIR="$HOME/phase1-shell"
python3 "$SRC/docs/design/phase1/instrument.py" "$SHELL_DIR"
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
for _ in $(seq 60); do snapshot 2>/dev/null && break; sleep .1; done
sleep 1
# Hold a virtual keyboard so focus can be inspected between input injections.
wtype -k Shift_L -s 240000 &
PIDS+=($!)
ipc open command >/dev/null
sleep 1
assert_ui 's["bay"] == "command" and any(p["text"] == "SEARCH" for p in s["deck"]["parts"])'
shot deck
cp "$OUT/ui.json" "$OUT/deck.json"
ipc open help >/dev/null
sleep 1
assert_ui 'any(p["name"] == "helpTakeTour" for p in s["deck"]["parts"])'
shot help
cp "$OUT/ui.json" "$OUT/help.json"
# Real keyboard activation of Help's action, starting at its filter.
key Tab
key Return
sleep .8
assert_ui 's["tourActive"] and s["step"] == 0 and s["bay"] == ""'
shot tour-1
cp "$OUT/ui.json" "$OUT/tour-1.json"
for _ in 1 2 3 4; do tour next; done
sleep .7
assert_ui 's["step"] == 4 and any(p["text"] == "5 of 5 · Status strip" for p in s["tour"]["parts"]) and any("bottom status strip" in p["text"] for p in s["tour"]["parts"])'
shot tour-5
cp "$OUT/ui.json" "$OUT/tour-5.json"
probe_click tour tourSettings
sleep .8
assert_ui 'not s["tourActive"] and s["bay"] == "settings" and len(s["warnings"]) == 1 and len(s["errors"]) == 0 and any(p["text"] == "WARNING / theme.decorationLevel" for p in s["deck"]["parts"])'
shot settings-warning
cp "$OUT/ui.json" "$OUT/settings-warning.json"
# Test the warning view remains available after leaving and returning.
ipc open help >/dev/null
sleep .4
ipc open settings >/dev/null
sleep .5
assert_ui 'len(s["warnings"]) == 1 and any(p["name"] == "settingsDiagnostics" for p in s["deck"]["parts"])'
# Spectrum -> register -> diagnostics -> tour, then keyboard replay.
key Tab
sleep .3
key Tab
sleep .3
assert_ui 'any(p["name"] == "settingsDiagnosticsList" and p["focus"] for p in s["deck"]["parts"])'
key Tab
sleep .3
assert_ui 'any(p["name"] == "settingsTakeTour" and p["focus"] for p in s["deck"]["parts"])'
key Return
sleep .7
assert_ui 's["tourActive"] and s["step"] == 0 and s["bay"] == ""'
tour skip
sleep .3
alive || fail 'shell died'
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail 'QML runtime errors'; fi
echo 'phase1 capture: ok (real Help/Settings keyboard replay, final Settings pointer action, persistent warning, bottom strip)'
