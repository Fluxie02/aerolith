# One serial session; no app/theme deployment or host configuration.
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
for intensity in saturated insane; do
 ipc run settings.intensity "{\"intensity\":\"$intensity\"}" >/dev/null
 for scheme in limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial; do
  ipc run settings.scheme "{\"scheme\":\"$scheme\"}" >/dev/null
  sleep 0.25
  ipc status >"$OUT/$intensity-$scheme.json"
  grep -q "\"scheme\":\"$scheme\"" "$OUT/$intensity-$scheme.json" || fail "$scheme did not apply"
  shot "$intensity-$scheme"
 done
done
ipc run settings.motion '{"motion":"reduced"}' >/dev/null
sleep 0.4
shot insane-reduced
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep 0.4
shot insane-off
alive || fail 'shell died'
echo 'schemes: ok (12 schemes × 2 intensities, reduced, off)'
