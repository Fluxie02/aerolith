#!/usr/bin/env bash
# Reproduce UI-016 without changing tools/, services, or production host files.
# Usage: run-benchmark.sh before|after 60|144 saturated|insane cpu|timing|capture
set -euo pipefail
cd "$(dirname "$0")/../../.."
phase=${1:?phase}; rate=${2:?rate}; intensity=${3:?intensity}; kind=${4:?kind}
case $phase in before|after) ;; *) exit 2;; esac
case $rate in 60|144) ;; *) exit 2;; esac
case $intensity in saturated|insane) ;; *) exit 2;; esac
case $kind in cpu|timing|capture) ;; *) exit 2;; esac
snapshot="build/ui016/$phase-shell"
test -f "$snapshot/shell.qml"
out="$PWD/docs/design/smooth/data/$phase-$rate-$intensity-$kind"
mkdir -p "$out"
find "$out" -mindepth 1 -delete
chmod 777 "$out"
python3 docs/design/smooth/prepare-session.py
printf '{"schemaVersion":1,"theme":{"intensity":"%s","motion":"full"}}\n' "$intensity" > "build/ui016/$phase-$rate-$intensity.json"
docker run --rm --cap-add=SYS_NICE \
  -v "$PWD:/src:ro" -v "$out:/out" \
  -e "UI016_HZ=$rate" -e "UI016_KIND=$kind" -e "SHELL_PATH=$snapshot" \
  -e "RES=1920x1080@${rate}Hz" -e "UI016_CONFIG=/src/build/ui016/$phase-$rate-$intensity.json" \
  "${AEROLITH_DEV_IMAGE:-aerolith-dev}" bash -c '
    set -e
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000 /home/pilot/.config/aerolith
    chown pilot /run/user/1000; chmod 700 /run/user/1000
    cp "$UI016_CONFIG" /home/pilot/.config/aerolith/config.json
    chown -R pilot /home/pilot
    exec su pilot -c "bash /src/build/ui016/session.sh /src/docs/design/smooth/benchmark-scenario.sh"
  ' > "$out/result.txt" 2>&1
python3 docs/design/smooth/analyse-timing.py "$out"
tail -n 4 "$out/result.txt"
