set -e
sleep 5
swaymsg -t get_outputs -r > "$OUT/outputs-144.json"
ipc open settings >/dev/null
sleep .6
shot settings-full-144
key Tab
sleep .2
shot settings-register-144
ipc run settings.motion '{"motion":"reduced"}' >/dev/null
sleep .3
shot settings-reduced-144
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep .3
shot settings-off-144
python3 - <<'PY'
import json,os
p=os.environ['XDG_CONFIG_HOME']+'/aerolith/config.json'
c=json.load(open(p));c.setdefault('theme',{})['lowEffects']=True
json.dump(c,open(p,'w'))
PY
ipc reload
sleep .3
shot settings-low-effects-144
mock '{"op":"add_monitor","name":"OTHER-OUTPUT"}' >/dev/null
mock '{"op":"remove_monitor","name":"HEADLESS-1"}' >/dev/null
sleep .4
shot settings-unavailable
mock '{"op":"add_monitor","name":"HEADLESS-1"}' >/dev/null
mock '{"op":"remove_monitor","name":"OTHER-OUTPUT"}' >/dev/null
python3 - <<'PY'
import json,os
p=os.environ['XDG_CONFIG_HOME']+'/aerolith/config.json'
c=json.load(open(p));t=c.setdefault('theme',{});t.update({'motion':'reduced','lowEffects':False,'uiScale':1.25})
json.dump(c,open(p,'w'))
PY
ipc reload
# Let action-result notices expire before the compact documentation frames.
sleep 4.2
swaymsg output HEADLESS-1 resolution 1280x720@144Hz scale 1 >/dev/null
sleep .5
shot settings-compact-register
key Tab
sleep .3
shot settings-compact-spectra
swaymsg -t get_outputs -r > "$OUT/outputs-compact.json"
ipc status > "$OUT/status.json"
alive
if grep -E 'TypeError|ReferenceError|Unable to assign|Binding loop|Error loading QML file|Expected token' "$OUT/qs.log"; then
  echo 'FAIL: QML engine error'
  exit 1
fi
echo 'PASS: Settings full/reduced/off/lowEffects, unknown metadata and compact captures'
