# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 4
shot 01-saturated
ipc run settings.intensity '{"intensity":"insane"}'
sleep .4
shot 02-live-insane
ipc status > "$OUT/insane-status.json"
grep -q '"intensity": "insane"' "$XDG_CONFIG_HOME/aerolith/config.json" || fail 'insane not saved'
sleep 4
shot 03-insane-clean
ipc open command; sleep .5
ipc run settings.intensity '{"intensity":"saturated"}'
sleep .3
shot 04-live-saturated-deck
# Intensity changes preserve the focused input and existing bay instance.
typ 'vol 37'; sleep .3; key Return; sleep 1
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.37' || fail 'input lost during switch'
sleep 4
shot 05-live-saturated-clean
for intensity in insane saturated insane saturated; do
  ipc run settings.intensity "{\"intensity\":\"$intensity\"}" >/dev/null
done
sleep 4
shot 06-rapid-switch-settled
# The production fullscreen host changes are pending. Exercise an actual
# unmap/remap of both existing PanelWindows through their supported config.
set_surfaces() {
  python3 - "$XDG_CONFIG_HOME/aerolith/config.json" "$1" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); s=json.loads(p.read_text()); enabled=sys.argv[2]=='true'
s.setdefault('ground',{})['enabled']=enabled
s.setdefault('strip',{})['visible']=enabled
p.write_text(json.dumps(s)+'\n')
PY
}
for intensity in saturated insane; do
  ipc run settings.intensity "{\"intensity\":\"$intensity\"}" >/dev/null
  sleep 4
  shot "07-$intensity-before-unmap"
  set_surfaces false; sleep 1
  shot "08-$intensity-unmapped"
  set_surfaces true; sleep .15
  shot "09-$intensity-remap-immediate"
  sleep .5; shot "10-$intensity-remap-settled"
done
# Off, reduced and opaque effects must all remain usable across switches.
ipc run settings.motion '{"motion":"off"}'
ipc run settings.low-effects ''
sleep 1
ipc run settings.intensity '{"intensity":"saturated"}'
sleep .2
shot 11-off-opaque-saturated
ipc run settings.intensity '{"intensity":"insane"}'
sleep .2
shot 12-off-opaque-insane
ipc open command; sleep .8; typ 'vol 38'; sleep .4; shot 13-off-opaque-command; key Return; sleep 1.5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.38' || fail 'off/low-effects input failed'
ipc status > "$OUT/final-status.json"
alive || fail 'quickshell died'
echo 'live-switch: ok'
