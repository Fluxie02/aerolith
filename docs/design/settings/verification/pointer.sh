fail() { echo "FAIL: $*"; exit 1; }
wayland-scanner client-header /src/build/ui008/virtual-pointer.xml "$OUT/virtual-pointer-client.h"
wayland-scanner private-code /src/build/ui008/virtual-pointer.xml "$OUT/virtual-pointer-protocol.c"
gcc -I"$OUT" /src/build/ui008/pointer-client.c "$OUT/virtual-pointer-protocol.c" -lwayland-client -o "$OUT/pointer-client"
click() { "$OUT/pointer-client" "$1" "$2"; sleep .4; }
assert_config() {
  python3 - "$XDG_CONFIG_HOME/aerolith/config.json" "$1" "$2" <<'PY'
import json,sys
v=json.load(open(sys.argv[1]))
for k in sys.argv[2].split('.'): v=v[k]
assert v==json.loads(sys.argv[3]),(sys.argv[2],v,sys.argv[3])
PY
}
sleep 4
ipc open command; sleep .6
click 1087 70
ipc status > "$OUT/status-pointer-systems.json"
python3 - "$OUT/status-pointer-systems.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['telemetryIntervalMs']==1000
PY
shot 01-pointer-rail
ipc open command; sleep .6
click 952 465
shot 02-pointer-scope
# Selection changes instantly; the shared registration retargets during motion.
wtype -k Shift_L -k Tab
shot 03-motion-first
sleep .05; shot 04-motion-second
sleep .2; shot 05-motion-settled
ipc open settings; sleep .6
click 1215 500
assert_config display.warnOnMultipleDisplays false
shot 06-pointer-switch
key Return; sleep .25
assert_config display.warnOnMultipleDisplays true
click 1200 615
assert_config theme.density '"comfortable"'
shot 07-pointer-choice
key Left; sleep .4
assert_config theme.density '"standard"'
click 1014 674
assert_config theme.uiScale 1.05
shot 08-pointer-number
key Left; sleep .3
assert_config theme.uiScale 1
# Reopen and navigate to fontSans, then enter the field by pointer.
ipc close; sleep .3; ipc open settings; sleep .5
wtype -k Shift_L -k Down -k Down -k Down -k Down -k Down -k Down -k Down
sleep .25
click 1000 765
wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace -- 'Noto Sans'
shot 09-pointer-edit
key Return; sleep .4
assert_config theme.fontSans '"Noto Sans"'
key Down; sleep .2
shot 10-keys-after-save
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/config-final.json"
alive || fail 'shell died'
echo 'pointer: ok (rail, scope, switch, choice, number, text, navigation after save)'
