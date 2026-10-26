# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
sleep 1
preview theme saturated full false 1
preview setCase menu
for scheme in limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial; do
    [ -z "$(preview scheme "$scheme")" ] || fail "scheme switch refused"
    sleep .5
    preview status >"$OUT/$scheme-status.json"
    python3 - "$OUT/$scheme-status.json" "$scheme" <<'PYmenu' || fail "scheme not live"
import json,sys
s=json.load(open(sys.argv[1])); assert s["scheme"] == sys.argv[2], s
PYmenu
    shot "$scheme"
done
preview theme insane reduced false 1
preview scheme corona
sleep .5
shot insane-reduced
preview theme insane off true 1.25
preview setCase literal
sleep .5
shot insane-off-low-literal
preview status >"$OUT/final-status.json"
alive || fail "quickshell died"
echo "session-schemes: ok"
