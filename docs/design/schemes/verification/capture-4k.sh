set -e
sleep 5
for id in limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial; do
  python3 - "$id" <<'PY'
import json,os,sys
p=os.path.join(os.environ['XDG_CONFIG_HOME'],'aerolith','config.json')
a=json.load(open(p)) if os.path.exists(p) else {};a.setdefault('theme',{})['scheme']=sys.argv[1];open(p,'w').write(json.dumps(a))
PY
  ipc reload >/dev/null
  ipc close
  sleep .4
  shot "$id-ground"
  ipc open settings >/dev/null
  sleep .6
  shot "$id-picker"
done
alive || exit 1
echo '4K register: all twelve spectra passed'
