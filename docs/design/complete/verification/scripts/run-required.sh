#!/usr/bin/env bash
set -u
intensity=$1
for scenario in smoke full signal deck notify ai; do
 extra=()
 case "$scenario" in
 full) extra=(AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json) ;;
 signal) extra=(AUDIO=1 MEDIA=1 MPV_AO=pipewire) ;;
 deck) extra=(AUDIO=1 'HYPR_MOCK_ARGS=--mode 2560x1440 --scale 1.5 --transform 1') ;;
 ai) extra=(AUDIO=1 AI=1) ;;
 esac
 env CONFIG="build/ui006/$intensity-normal.json" "${extra[@]}" tools/headless/run.sh "tests/scenarios/$scenario.sh" "build/ui006/$intensity-$scenario" >"build/ui006/$intensity-$scenario.txt" 2>&1
 result=$?
 echo "$intensity $scenario exit=$result"
 if [ "$result" != 0 ]; then tail -8 "build/ui006/$intensity-$scenario.txt"; fi
done
