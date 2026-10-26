#!/usr/bin/env bash
# Run in the dev image with Qt's qsb. Sources and portable packages ship together.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
qsb=${QSB:-/usr/lib/qt6/bin/qsb}
mode=${1:-}
[[ "$mode" = "" || "$mode" = --check ]] || { echo 'usage: build-shaders.sh [--check]' >&2; exit 2; }
[[ -x "$qsb" ]] || { echo "qsb unavailable: $qsb (use aerolith-dev)" >&2; exit 2; }
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
failed=0
for source in "$repo"/shell/shaders/*.frag; do
    name=$(basename "$source")
    "$qsb" --glsl '100es,120,150' --hlsl 50 --msl 12 -o "$scratch/$name.qsb" "$source"
    if [[ "$mode" = --check ]]; then
        if ! cmp -s "$scratch/$name.qsb" "$source.qsb"; then
            echo "stale or missing: shell/shaders/$name.qsb" >&2
            failed=1
            continue
        fi
    else
        cp "$scratch/$name.qsb" "$source.qsb"
    fi
    echo "$name: ${mode:---build} ok"
done
exit "$failed"
