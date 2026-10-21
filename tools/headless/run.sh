#!/usr/bin/env bash
# Host-side wrapper: run a headless AEROLITH scenario in the dev container.
#   tools/headless/run.sh tests/scenarios/smoke.sh [output-dir]
# Environment passed through: AUDIO, MEDIA, RES, SCALE, HYPR_MOCK, HYPR_MOCK_ARGS,
# CONFIG (path to a config.json to install), ROUTINES (routines.json).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
scenario=${1:?usage: run.sh <scenario.sh> [output-dir]}
out=${2:-$here/build/headless/$(basename "$scenario" .sh)}
image=${AEROLITH_DEV_IMAGE:-aerolith-dev}
mkdir -p "$out"
chmod 777 "$out"

extra=()
[ -n "${CONFIG:-}" ] && extra+=(-v "$(realpath "$CONFIG"):/seed/config.json:ro")
[ -n "${ROUTINES:-}" ] && extra+=(-v "$(realpath "$ROUTINES"):/seed/routines.json:ro")

docker run --rm --cap-add=SYS_NICE \
  -v "$here:/src:ro" -v "$out:/out" "${extra[@]}" \
  -e AUDIO -e MEDIA -e RES -e SCALE -e HYPR_MOCK -e HYPR_MOCK_ARGS -e MPV_AO \
  "$image" bash -c '
    set -e
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000 && chown pilot /run/user/1000 && chmod 700 /run/user/1000
    mkdir -p /home/pilot/.config/aerolith
    [ -f /seed/config.json ] && cp /seed/config.json /home/pilot/.config/aerolith/config.json
    [ -f /seed/routines.json ] && cp /seed/routines.json /home/pilot/.config/aerolith/routines.json
    chown -R pilot /home/pilot
    exec su pilot -c "AUDIO=${AUDIO:-0} MEDIA=${MEDIA:-0} RES=${RES:-1920x1080} SCALE=${SCALE:-1} HYPR_MOCK=${HYPR_MOCK:-1} HYPR_MOCK_ARGS=\"${HYPR_MOCK_ARGS:-}\" MPV_AO=${MPV_AO:-null} bash /src/tools/headless/session.sh /src/'"$scenario"'"
  '
