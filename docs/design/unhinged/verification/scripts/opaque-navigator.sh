# shellcheck shell=bash
sleep 3
ipc open navigator
sleep .5
shot 01-navigator-low-effects
key Right
sleep .1
shot 02-selection-low-effects
ipc close
sleep .3
alive || exit 1
echo 'opaque-navigator: ok'
