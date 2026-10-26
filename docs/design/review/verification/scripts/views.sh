set -euo pipefail
preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
kind=$(basename "$SHELL_PATH")
case "$kind" in
 lock) states='idle failed literal' ;;
 session) states='menu confirm-reboot unavailable literal' ;;
 osd) states='volume amplified unknown muted literal' ;;
esac
sleep 1
for intensity in saturated insane; do
 for mode in full small reduced; do
  case "$mode" in
   full) preview theme "$intensity" full false 1 ;;
   small) preview theme "$intensity" off true 1.5 ;;
   reduced) preview theme "$intensity" reduced false 1 ;;
  esac
  for state in $states; do
   preview setCase "$state"; sleep .15; shot "$intensity-$mode-$state"
  done
 done
done
alive || { echo 'FAIL: view died'; exit 1; }
echo "views-$kind: ok"
