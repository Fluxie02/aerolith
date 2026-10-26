# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
shot small-idle
for bay in command navigator systems signal help; do
  ipc open "$bay" >/dev/null; sleep .7
  case "$bay" in
    command) typ '@ a'; sleep .2; shot small-command ;;
    signal) shot small-sound ;;
    *) shot "small-$bay" ;;
  esac
  ipc close; sleep .15
done
ipc run shell.notify '{"message":"Layout check: 1280 × 720 / scale 1.25 / Noto / motion off / opaque"}' >/dev/null
sleep .15; shot small-notice
alive || fail 'quickshell died'
echo 'round3 compact: ok'
