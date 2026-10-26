set -e
sleep 4
for id in limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial; do
  python3 - "$id" <<'PY'
import json,os,sys
p=os.path.join(os.environ['XDG_CONFIG_HOME'],'aerolith','config.json')
a=json.load(open(p)) if os.path.exists(p) else {};a.setdefault('theme',{}).update(scheme=sys.argv[1],motion='off');open(p,'w').write(json.dumps(a))
PY
  ipc reload >/dev/null
  sleep .2
  ipc close
  sleep .2
  shot "$id-ground"
  for bay in command navigator systems signal routines help settings ai; do
    ipc open "$bay" >/dev/null
    sleep .45
    shot "$id-$bay"
  done
  ipc close
  sleep .2
  ipc run shell.notify "{\"message\":\"$id / nominal instrument notice\"}" >/dev/null
  sleep .2
  shot "$id-notice"
done
alive || exit 1
echo 'all-scheme bays: passed'
