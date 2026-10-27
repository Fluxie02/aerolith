# One serial session, 12 schemes, both directions and both intensities.
source "$SRC/docs/design/redesign-2/scripts/helpers.sh"
start_visual_fixture
for direction in piyti thears; do
  if [ "$direction" = thears ]; then
    qs -p "$SHELL_DIR" kill
    wait "$QS_PID" || true
    printf '%s\n' '{"direction":"thears"}' >"$XDG_CONFIG_HOME/aerolith/installation.json"
    restart_visual_fixture
  fi
  for intensity in saturated insane; do
    probe theme intensity "$intensity" >/dev/null
    for scheme in limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial; do
      probe theme scheme "$scheme" >/dev/null
      probe contents parked >/dev/null
      capture_state "$direction-$intensity-$scheme-closed"
      click_hatch
      expect_open true
      capture_state "$direction-$intensity-$scheme-open"
      python3 - "$OUT/$direction-$intensity-$scheme-open.json" "$direction" "$intensity" "$scheme" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert [d['direction'], d['intensity'], d['scheme']] == sys.argv[2:], d
assert d['open'] and d['count'] == 4, d
PY
      click_hatch
      expect_open false
    done
  done
done
audit_visual_logs
echo 'hatch matrix: ok (12 schemes × 2 intensities × 2 directions × open/closed)'
