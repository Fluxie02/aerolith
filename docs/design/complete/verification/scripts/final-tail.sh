#!/usr/bin/env bash
set -u
for scenario in full deck notify ai; do
 extra=()
 case "$scenario" in
 full) extra=(AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json) ;;
 deck) extra=(AUDIO=1 'HYPR_MOCK_ARGS=--mode 2560x1440 --scale 1.5 --transform 1') ;;
 ai) extra=(AUDIO=1 AI=1) ;;
 esac
 env CONFIG=build/ui006/saturated-normal.json "${extra[@]}" tools/headless/run.sh "tests/scenarios/$scenario.sh" "build/ui006/saturated-$scenario-verified" >"build/ui006/saturated-$scenario-verified.txt" 2>&1
 echo "saturated $scenario verified exit=$?"
done
for intensity in saturated insane; do
 env CONFIG="build/ui006/$intensity-small.json" RES=1280x720 AI=1 AUDIO=1 MEDIA=1 AI_PROVIDER=codex tools/headless/run.sh build/ui006/codex-console.sh "build/ui006/$intensity-codex-verified" >"build/ui006/$intensity-codex-verified.txt" 2>&1
 echo "$intensity codex native verified exit=$?"
 env CONFIG="build/ui006/$intensity-small.json" RES=1280x720 MEDIA=1 SHELL_PATH=build/ui006/gallery-shell tools/headless/run.sh build/ui006/gallery.sh "build/ui006/$intensity-gallery-verified" >"build/ui006/$intensity-gallery-verified.txt" 2>&1
 echo "$intensity annunciator gallery exit=$?"
done
