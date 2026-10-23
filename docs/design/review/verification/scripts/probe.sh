set -euo pipefail
review() { qs -p "$SHELL_DIR" ipc call review "$@"; }
check() {
 review status > "$OUT/$1.json"
 python3 - "$OUT/$1.json" "$2" <<'PY'
import sys,json
s=json.load(open(sys.argv[1]));assert eval(sys.argv[2],{},s), s
PY
}
sleep 3
check startup 'played and progress == 1'
before=$(review status | python3 -c 'import sys,json;print(json.load(sys.stdin)["events"])')
ipc open command; sleep .3; typ 'retained draft'; sleep .2
check typed 'draft'
shot p1-draft
intensity=$(review status | python3 -c 'import sys,json;print(json.load(sys.stdin)["intensity"])')
other=insane; [ "$intensity" != insane ] || other=saturated
ipc run settings.intensity "{\"intensity\":\"$other\"}"
sleep .3
check switched 'draft and progress == 1'
shot p2-switch
ipc close; sleep .2
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import sys,json
p=sys.argv[1];c=json.load(open(p));c.setdefault('ground',{})['enabled']=False;c.setdefault('strip',{})['visible']=False;open(p,'w').write(json.dumps(c))
PY
sleep .3
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import sys,json
p=sys.argv[1];c=json.load(open(p));c['ground']['enabled']=True;c['strip']['visible']=True;open(p,'w').write(json.dumps(c))
PY
sleep .3; shot p3-remap
for motion in reduced off full; do
 for low in false true; do
  review motion "$motion" "$low"; sleep .2
  check "mode-$motion-$low" 'progress == 1'
 done
done
check final "events == $before"
alive
echo "probe: ok ($before startup events; no replay on switch/remap/motion changes)"
