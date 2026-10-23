#!/usr/bin/env bash
set -euo pipefail
for kind in lock osd session; do
 SHELL_PATH=build/ui009/previews-after/$kind RES=1280x720 tools/headless/run.sh prototypes/views/capture.sh "build/ui009/check-$kind" > "build/ui009/check-$kind-result.txt" 2>&1
 echo "$kind interactions: passed"
done
