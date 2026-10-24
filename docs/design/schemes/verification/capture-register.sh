# Sourced by headless/session.sh. Exercises the production picker and save path.
set -e
press() { key "$1"; sleep .12; }
sleep 4
ipc open settings
sleep 1
press Home
press Return
ids=(limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial)
for id in "${ids[@]}"; do
  if [ "$id" != limb ]; then press Right; press Return; fi
  sleep .3
  python3 - "$id" <<'PY'
import json,os,sys
p=os.path.join(os.environ['XDG_CONFIG_HOME'],'aerolith','config.json')
assert json.load(open(p))['theme']['scheme']==sys.argv[1]
PY
  shot "picker-$id"
  ipc close
  sleep .4
  shot "scheme-$id"
  ipc open settings
  sleep .4
done
press Home
press Return
press Right
shot cursor-bathyal-active-limb
press Return
sleep .15
shot applied-bathyal
press Tab
sleep .2
shot register
press Tab
sleep .2
shot returned-spectrum
ipc close
ipc open systems
sleep 1
# Config reload while already-open Canvas traces are visible.
python3 - <<'PY'
import json,os
p=os.path.join(os.environ['XDG_CONFIG_HOME'],'aerolith','config.json')
a=json.load(open(p));a['theme']['scheme']='cinder';open(p,'w').write(json.dumps(a))
PY
ipc reload
sleep .3
shot live-systems-cinder
alive || exit 1
echo 'register: 12 live choices, persistence, cursor, Tab and trace switch passed'
