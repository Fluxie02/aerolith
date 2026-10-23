#!/usr/bin/env bash
set -euo pipefail
intensity=$1
export SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/$intensity-full.json
for scenario in smoke full signal deck notify ai; do
 args=()
 case "$scenario" in
  full|signal) args=(AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json) ;;
  deck) args=(AUDIO=1 'HYPR_MOCK_ARGS=--mode 2560x1440 --scale 1.5 --transform 1') ;;
  notify) args=(CONFIG=build/ui009/notify-$intensity.json) ;;
  ai) args=(AI=1 AUDIO=1) ;;
 esac
 env "${args[@]}" tools/headless/run.sh "tests/scenarios/$scenario.sh" "build/ui009/verified-$intensity-$scenario" > "build/ui009/verified-$intensity-$scenario-result.txt" 2>&1
 echo "$intensity $scenario: passed"
done
