#!/usr/bin/env bash
set -euo pipefail
intensity=$1
export SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/$intensity.json
for scenario in smoke full deck notify; do
  args=()
  case "$scenario" in
    full) args=(AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json) ;;
    deck) args=(AUDIO=1 'HYPR_MOCK_ARGS=--mode 2560x1440 --scale 1.5 --transform 1') ;;
    notify) args=(CONFIG=build/ui008/notify-$intensity.json) ;;
    perf) args=(AUDIO=1 MEDIA=1) ;;
  esac
  env "${args[@]}" tools/headless/run.sh "tests/scenarios/$scenario.sh" "build/ui008/final-$intensity-$scenario" > "build/ui008/final-$intensity-$scenario-result.txt" 2>&1
  echo "$intensity $scenario: passed"
done
