# shellcheck shell=bash
set -euo pipefail
preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
expect() {
  local field=$1 expected=$2
  for attempt in $(seq 1 20); do
    preview status > "$OUT/status.json"
    if python3 - "$OUT/status.json" "$field" "$expected" <<'CHECK'
import json,sys
s=json.load(open(sys.argv[1]))
sys.exit(0 if str(s[sys.argv[2]]).lower()==sys.argv[3].lower() else 1)
CHECK
    then return 0; fi
    sleep .05
  done
  cat "$OUT/status.json"
  echo "FAIL: $field did not become $expected" >&2
  exit 1
}

name=$(basename "${SHELL_PATH}")
case "$name" in
 lock) states='idle typing checking failed locked-out prompt literal' ;;
 osd) states='volume zero maximum amplified clamped muted unknown brightness brightness-unknown mic mic-muted mic-unknown unknown-muted literal' ;;
 session) states='menu selected-logout selected-suspend selected-reboot selected-shutdown unavailable empty literal confirm-logout confirm-suspend confirm-reboot confirm-shutdown confirm-logout-accept confirm-suspend-accept confirm-reboot-accept confirm-shutdown-accept' ;;
esac
sleep 1
for intensity in saturated insane; do
  preview theme "$intensity" full false 1
  sleep .2
  for state in $states; do
    preview setCase "$state"; sleep .25; shot "$intensity-$state"
  done
  preview theme "$intensity" reduced false 1
  preview setCase "${states%% *}"; sleep .25; shot "$intensity-reduced"
  preview theme "$intensity" off true 1
  preview setCase "${states%% *}"; sleep .2; shot "$intensity-low-effects"
  preview theme "$intensity" off false 1.25
  preview setCase literal; sleep .2; shot "$intensity-scaled-literal"
done
preview theme saturated off false 1
case "$name" in
 lock)
  preview setCase idle; typ 'fixture-password'; key Return; sleep .15
  expect event submitted; expect bufferLength 0; expect state checking
  typ 'blocked'; key Return; expect bufferLength 0
  preview setCase failed; typ 'retry'; key Return; expect event submitted
  preview setCase locked-out; typ 'blocked'; key Return; expect event none; expect bufferLength 0
  ;;
 osd)
  for motion in full reduced off; do
    preview theme saturated "$motion" false 1
    preview setCase volume; sleep .2; preview setCase exit; sleep .2
    expect event settled; expect presenting false; shot "exit-$motion"
  done
  preview theme insane full true 1
  preview setCase volume; preview setCase exit; expect event settled; expect presenting false
  ;;
 session)
  preview setCase menu; key Return; expect event activated:lock
  preview setCase menu; key Down; key Return; expect pending logout; expect event none
  key Return; expect pending ''; expect event none
  preview setCase confirm-reboot; key Right; key Return; expect event activated:reboot
  preview setCase confirm-shutdown; key Escape; expect pending ''; expect event none
  key Escape; expect event cancelled
  preview setCase unavailable; key Return; expect event none
  preview setCase empty; key Return; expect event none
  ;;
esac
alive || { echo 'FAIL: preview died'; exit 1; }
echo "UI-007 $name: state captures and interaction checks passed"
