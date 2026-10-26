# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 4
before=$(grep -c UI006_BOOT_PROGRESS "$OUT/qs.log")
[ "$before" -gt 2 ] || fail 'startup animation was not observed'
shot b0-settled
ipc open command; sleep .6; typ 'retained draft'
ipc run settings.intensity '{"intensity":"insane"}'; sleep .4; shot b1-switch-retained
ipc close; sleep .3
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p));c.setdefault('ground',{})['enabled']=False;c.setdefault('strip',{})['visible']=False;open(p,'w').write(json.dumps(c))
PY
sleep .6
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
p=sys.argv[1];c=json.load(open(p));c['ground']['enabled']=True;c['strip']['visible']=True;c['theme']['intensity']='saturated';open(p,'w').write(json.dumps(c))
PY
sleep .7; shot b2-restored
[ "$(grep -c UI006_BOOT_PROGRESS "$OUT/qs.log")" = "$before" ] || fail 'startup animation replayed'
alive || fail 'quickshell died'
echo "boot-probe: ok ($before startup progress events; no events on intensity switch or remap)"
