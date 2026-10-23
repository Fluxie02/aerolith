#!/usr/bin/env bash
set -euo pipefail
export SHELL_PATH=build/ui009/verified-shell
for pair in saturated-ai insane-deck insane-notify insane-ai; do
 intensity=${pair%%-*}; scenario=${pair#*-}; export CONFIG=build/ui009/$intensity-full.json
 args=()
 case "$scenario" in
  ai) args=(AI=1 AUDIO=1) ;;
  deck) args=(AUDIO=1 'HYPR_MOCK_ARGS=--mode 2560x1440 --scale 1.5 --transform 1') ;;
  notify) args=(CONFIG=build/ui009/notify-$intensity.json) ;;
 esac
 env "${args[@]}" tools/headless/run.sh tests/scenarios/$scenario.sh "build/ui009/retry-$pair" > "build/ui009/retry-$pair-result.txt" 2>&1
 echo "$pair: passed"
done
