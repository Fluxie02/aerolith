#!/usr/bin/env bash
set -euo pipefail
for intensity in saturated insane; do
 for mode in full small reduced; do
  res=1920x1080
  [ "$mode" != small ] || res=1280x720
  SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/$intensity-$mode.json RES=$res AUDIO=1 MEDIA=1 MPV_AO=pipewire AI=1 ROUTINES=tests/fixtures/routines.json tools/headless/run.sh build/ui009/gallery.sh "build/ui009/verified-gallery-$intensity-$mode" > "build/ui009/verified-gallery-$intensity-$mode-result.txt" 2>&1
  echo "$intensity $mode gallery: passed"
 done
 SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/$intensity-full.json AUDIO=1 tools/headless/run.sh build/ui008/tabs-capture.sh "build/ui009/verified-terminal-$intensity" > "build/ui009/verified-terminal-$intensity-result.txt" 2>&1
 echo "$intensity terminal: passed"
done
