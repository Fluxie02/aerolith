preview() { qs -p "$SHELL_DIR" ipc call preview "$@"; }
sleep 2
name=$(basename "$SHELL_PATH")
case "$name" in
  lock) states='idle failed literal' ;;
  session) states='menu confirm-reboot unavailable' ;;
  osd) states='volume amplified unknown' ;;
esac
for intensity in saturated insane; do
  preview theme "$intensity" full false 1
  for state in $states; do
    preview setCase "$state"; sleep .25; shot "$intensity-$state"
  done
  preview theme "$intensity" off true 1.25
  preview setCase literal; sleep .25; shot "$intensity-compact-plain"
done
alive
echo "rounded $name: ok"
