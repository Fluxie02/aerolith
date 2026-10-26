#!/usr/bin/env bash
# Host-side wrapper: run a headless AEROLITH scenario in the dev container.
#   tools/headless/run.sh tests/scenarios/smoke.sh [output-dir]
# Environment passed through: SHELL_PATH (shell directory relative to the repo,
# default shell; for prototypes), AUDIO, MEDIA, AI, AI_PROVIDER, INSTALL, RES, SCALE, HYPR_MOCK, HYPR_MOCK_ARGS,
# CONFIG (path to a config.json to install), ROUTINES (routines.json),
# PKGS (directory of built Arch packages to install with pacman -U first;
# the scenario then runs against the packaged tree, see tools/package/build.sh).
set -euo pipefail
here=/home/user/aerolith-astra
scenario=${1:?usage: run.sh <scenario.sh> [output-dir]}
out=${2:-$here/build/headless/$(basename "$scenario" .sh)}
image=${AEROLITH_DEV_IMAGE:-aerolith-dev}
mkdir -p "$out"
out=$(cd "$out" && pwd)  # docker -v needs an absolute path
# Each run starts clean: stale logs would make assertions meaningless.
find "$out" -mindepth 1 -delete
chmod 777 "$out"

extra=()
[ -n "${CONFIG:-}" ] && extra+=(-v "$(realpath "$CONFIG"):/seed/config.json:ro")
[ -n "${ROUTINES:-}" ] && extra+=(-v "$(realpath "$ROUTINES"):/seed/routines.json:ro")
packaged=0
if [ -n "${PKGS:-}" ]; then
  extra+=(-v "$(realpath "$PKGS"):/pkgs:ro")
  packaged=1
fi

docker run --rm --cap-add=SYS_NICE \
  -v "$here:/src:ro" -v "$out:/out" "${extra[@]}" \
  -e AUDIO -e MEDIA -e AI -e INSTALL -e AI_PROVIDER -e WIREPLUMBER_DEBUG -e PIPEWIRE_DEBUG -e RES -e SCALE -e HYPR_MOCK -e HYPR_MOCK_ARGS -e MPV_AO -e SHELL_PATH \
  "$image" bash -c '
    set -e
    if [ -d /pkgs ]; then pacman -U --noconfirm /pkgs/*.pkg.tar.zst >/out/pacman.log 2>&1 || { cat /out/pacman.log; exit 1; }; fi
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000 && chown pilot /run/user/1000 && chmod 700 /run/user/1000
    mkdir -p /home/pilot/.config/aerolith
    [ -f /seed/config.json ] && cp /seed/config.json /home/pilot/.config/aerolith/config.json
    [ -f /seed/routines.json ] && cp /seed/routines.json /home/pilot/.config/aerolith/routines.json
    chown -R pilot /home/pilot
    exec su pilot -c "SHELL_PATH=${SHELL_PATH:-shell} AI=${AI:-0} AI_PROVIDER=${AI_PROVIDER:-claude} AUDIO=${AUDIO:-0} PACKAGED='"$packaged"' INSTALL=\"${INSTALL:-}\" MEDIA=${MEDIA:-0} RES=${RES:-1920x1080} SCALE=${SCALE:-1} HYPR_MOCK=${HYPR_MOCK:-1} HYPR_MOCK_ARGS=\"${HYPR_MOCK_ARGS:-}\" MPV_AO=${MPV_AO:-null} WIREPLUMBER_DEBUG=${WIREPLUMBER_DEBUG:-W} PIPEWIRE_DEBUG=${PIPEWIRE_DEBUG:-2} bash /src/build/ui009/baseline-session.sh /src/'"$scenario"'"
  '
