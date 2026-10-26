#!/usr/bin/env bash
# Focused C05 installer roundtrip; no compositor, audio or AI process needed.
# docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/C05/themes:/out" \
#   aerolith-dev bash /src/tests/scenarios/themes.sh /out
set -euo pipefail
src=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:?usage: themes.sh OUTPUT_DIRECTORY}
mkdir -p "$out"
out=$(cd "$out" && pwd)
theme_test_root=$(mktemp -d)
trap 'rm -rf "$theme_test_root"' EXIT
export HOME="$theme_test_root/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
export AEROLITH_ALLOW_ROOT=1
verify_flags=()
if [ "$(id -u)" = 0 ]; then verify_flags+=(--i-am-really-stupid); fi
unset AEROLITH_SYSTEM_ROOT HYPRLAND_INSTANCE_SIGNATURE
mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/kitty" "$XDG_CONFIG_HOME/foot" "$XDG_CONFIG_HOME/aerolith"
export PATH="$HOME/.local/bin:$PATH"
# Deliberately no final newlines: uninstall must restore the original bytes.
printf -- '-- user Hyprland config\nhl.config({})' >"$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf 'include other.conf\n# user kitty config' >"$XDG_CONFIG_HOME/kitty/kitty.conf"
printf '# user foot config\n[main]\nfont=monospace:size=10' >"$XDG_CONFIG_HOME/foot/foot.ini"
printf '{"theme":{"scheme":"iris"}}\n' >"$XDG_CONFIG_HOME/aerolith/config.json"
cp "$XDG_CONFIG_HOME/hypr/hyprland.lua" "$out/hyprland.original"
cp "$XDG_CONFIG_HOME/kitty/kitty.conf" "$out/kitty.original"
cp "$XDG_CONFIG_HOME/foot/foot.ini" "$out/foot.original"
for direction in piyti thears; do
    sh "$src/install.sh" --yes --ai none --startup manual --direction "$direction" --themes kitty,foot,hyprland --no-start --no-install-deps --no-install-provider >"$out/install-$direction.log" 2>&1
    aerolith themes status --json >"$out/status-$direction.json"
    python3 - "$out/status-$direction.json" "$direction" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))["apps"]
applied = {r["app"]: r for r in rows if r["applied"]}
assert set(applied) == {"kitty", "foot", "hyprland"}, rows
assert all(r["scheme"] == "iris" and r["direction"] == sys.argv[2] for r in applied.values())
PY
    cp "$XDG_CONFIG_HOME/kitty/kitty.conf" "$out/kitty.applied-$direction"
    cp "$XDG_CONFIG_HOME/foot/foot.ini" "$out/foot.applied-$direction"
    cp "$XDG_CONFIG_HOME/hypr/hyprland.lua" "$out/hyprland.applied-$direction"
    aerolith themes refresh --scheme corona --json >"$out/refresh-$direction.json"
    python3 - "$out/refresh-$direction.json" <<'PYREFRESH'
import json, os, pathlib, sys
result = json.load(open(sys.argv[1]))
assert {r["app"] for r in result["apps"]} == {"kitty", "foot", "hyprland"}
assert all(r["status"] == "refreshed" for r in result["apps"]), result
root = pathlib.Path(os.environ["XDG_DATA_HOME"]) / "aerolith"
for app, name in (("kitty", "aerolith.conf"), ("foot", "aerolith.ini"), ("hyprland", "aerolith.lua")):
    assert (root / "themes" / app / name).read_bytes() == (root / "theme-assets/schemes/corona" / app / name).read_bytes()
PYREFRESH
    cmp "$out/kitty.applied-$direction" "$XDG_CONFIG_HOME/kitty/kitty.conf"
    cmp "$out/foot.applied-$direction" "$XDG_CONFIG_HOME/foot/foot.ini"
    cmp "$out/hyprland.applied-$direction" "$XDG_CONFIG_HOME/hypr/hyprland.lua"
    foot --check-config >"$out/foot-$direction.log" 2>&1
    luac -p "$XDG_CONFIG_HOME/hypr/hyprland.lua"
    luac -p "$XDG_DATA_HOME/aerolith/themes/hyprland/aerolith.lua"
    luac -p "$XDG_DATA_HOME/aerolith/themes/hyprland/direction.lua"
    Hyprland "${verify_flags[@]}" --verify-config -c "$XDG_CONFIG_HOME/hypr/hyprland.lua" >"$out/hyprland-$direction.log" 2>&1
    aerolith themes apply kitty foot hyprland >"$out/reapply-$direction.log" 2>&1
    aerolith --yes uninstall --remove-config >"$out/uninstall-$direction.log" 2>&1
    cmp "$out/hyprland.original" "$XDG_CONFIG_HOME/hypr/hyprland.lua"
    cmp "$out/kitty.original" "$XDG_CONFIG_HOME/kitty/kitty.conf"
    cmp "$out/foot.original" "$XDG_CONFIG_HOME/foot/foot.ini"
    test ! -e "$XDG_DATA_HOME/aerolith"
    test ! -e "$XDG_STATE_HOME/aerolith/manifest.json"
    test ! -e "$XDG_CONFIG_HOME/aerolith/installation.json"
    test ! -e "$HOME/.local/bin/aerolith"
done
echo 'themes: ok (PIYTI and THEARS; byte-exact uninstall)'
