# shellcheck shell=bash
# Installer integration scenario. Run with
#   INSTALL="--ai claude --startup hyprland" AUDIO=1 tools/headless/run.sh tests/scenarios/installed.sh
# C05 opt-in roundtrip:
#   INSTALL="--ai claude --startup hyprland --themes kitty,foot,hyprland" AUDIO=1 tools/headless/run.sh tests/scenarios/installed.sh
# or, against the Arch packages (built by tools/package/build.sh):
#   PKGS=build/packages INSTALL="--ai claude --startup hyprland" AUDIO=1 tools/headless/run.sh tests/scenarios/installed.sh
# session.sh has already run the real installer (install.sh, or
# /usr/bin/aerolith for packages) into a fresh home with a minimal
# hyprland.lua, and started the shell from the installed tree.
# Verifies: installed layout and Hyprland fragment, the AI path through the
# installed bridge, `aerolith ai remove` while the shell runs, and a full
# uninstall that restores hyprland.lua byte for byte and keeps the
# independently installed provider CLI.
fail() { echo "FAIL: $*"; exit 1; }
hypr="$XDG_CONFIG_HOME/hypr"
if [ "${PACKAGED:-0}" = 1 ]; then
  aerolith() { /usr/bin/aerolith "$@"; }
  expect_shell=/usr/share/aerolith/shell mode=system
  pkg_sum() { find /usr/share/aerolith -type f -exec sha256sum {} + | sort | sha256sum; }
  pkg_before=$(pkg_sum)
else
  aerolith() { "$HOME/.local/bin/aerolith" "$@"; }
  expect_shell=$HOME/.local/share/aerolith/shell mode=user
fi
sleep 3

[ "$SHELL_DIR" = "$expect_shell" ] || fail "not running the installed shell"
[ -f "$XDG_STATE_HOME/aerolith/manifest.json" ] || fail "no manifest"
grep -qF -- "-p '$expect_shell'" "$hypr/aerolith/aerolith.lua" || fail "autostart does not run $expect_shell"
grep -q 'pcall(require, "aerolith/aerolith")' "$hypr/hyprland.lua" || fail "include not added to hyprland.lua"
cp "$hypr/aerolith/aerolith.lua" "$OUT/fragment.lua"
luac -p "$hypr/hyprland.lua" "$hypr/aerolith/aerolith.lua" || fail "generated Lua does not parse"
# Check real compositor parsing as well as Lua grammar. Generate the legacy
# dialect with the same installer entry point; this session installs Lua.
PYTHONPATH="$SRC/installer" python3 - "$OUT/fragment.conf" <<'PY'
from pathlib import Path
import sys
from aerolith_install import hypr
Path(sys.argv[1]).write_text(hypr.fragment("hyprlang", hypr.default_binds(True, True), "qs -p /installed/shell"))
PY
for namespace in aerolith-ground aerolith-strip aerolith-deck aerolith-notices aerolith-osd; do
  grep -qxF "hl.layer_rule({ match = { namespace = \"^$namespace\$\" }, no_anim = true })" "$hypr/aerolith/aerolith.lua" || fail "Lua no_anim missing: $namespace"
  grep -qxF "layerrule = no_anim on, match:namespace ^$namespace\$" "$OUT/fragment.conf" || fail "hyprlang no_anim missing: $namespace"
done
for config in "$hypr/aerolith/aerolith.lua" "$OUT/fragment.conf"; do
  Hyprland --verify-config --config "$config" >"$OUT/verify-$(basename "$config").log" 2>&1 || fail "Hyprland rejected $config"
done
grep -q 'aerolith:ai' "$hypr/aerolith/aerolith.lua" || fail "AI bind missing from fragment"
aerolith status --json >"$OUT/status.json"
aerolith themes status --json >"$OUT/themes-status.json"
python3 - "$OUT/themes-status.json" <<'PY' || fail "opt-in themes not deployed"
import json, os, shlex, sys
args = shlex.split(os.environ["INSTALL"])
wanted = args[args.index("--themes") + 1].split(",") if "--themes" in args else []
rows = json.load(open(sys.argv[1]))["apps"]
assert {r["app"] for r in rows if r["applied"]} == set(wanted), rows
PY
# Native parser check of the installed foot include, when opted in.
if [ -f "$XDG_CONFIG_HOME/foot/foot.ini" ]; then
  foot --check-config >"$OUT/foot-config.log" 2>&1 || fail "foot include does not parse"
fi
expected_direction=$(python3 -c 'import os,shlex; a=shlex.split(os.environ["INSTALL"]); print(a[a.index("--direction")+1] if "--direction" in a else "piyti")')
expected_provider=$(python3 -c 'import os,shlex; a=shlex.split(os.environ["INSTALL"]); p=a[a.index("--ai")+1]; assert p in ("claude", "codex"), p; print(p)')
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["direction"] == sys.argv[2], s' "$OUT/status.json" "$expected_direction" || fail "installer direction"
ipc status >"$OUT/shell-status.json"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["direction"] == sys.argv[2], s' "$OUT/shell-status.json" "$expected_direction" || fail "running shell direction"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["installed"] and s["mode"] == sys.argv[2] and s["ai_provider"] == sys.argv[3] and s["hyprland_dialect"] == "lua", s' "$OUT/status.json" "$mode" "$expected_provider" \
  || fail "status: $(cat "$OUT/status.json")"
aerolith doctor >"$OUT/doctor.log" 2>&1 || true
python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["ai"] is True, s' "$(ipc status)" || fail "AI commands not registered"
[ ! -s "$FAKE_LOG" ] || fail "provider was contacted before any request"

# The installed bridge answers through the fake provider.
ipc open command; sleep 0.8
typ "ai please lower the volume"; sleep 0.5; key Return
wait_for_log "answer received" 10 || fail "installed AI bridge did not answer"
shot i1-installed-ai
key Escape; ipc close; sleep 0.5

# Remove the AI integration with the maintenance tool while the shell runs.
aerolith --yes ai remove >"$OUT/ai-remove.log" 2>&1 || fail "ai remove exited $?"
sleep 2
python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["ai"] is False, s' "$(ipc status)" || fail "AI commands still registered after ai remove"
if [ "$mode" = system ]; then
  [ -f "$SHELL_DIR/modules/ai/AiModule.qml" ] || fail "ai remove touched the aerolith-ai-bridge package"
  grep -q "sudo pacman -R aerolith-ai-bridge" "$OUT/ai-remove.log" || fail "ai remove did not explain the package"
else
  [ ! -e "$SHELL_DIR/modules/ai" ] || fail "AI module left behind: $(find "$SHELL_DIR/modules/ai")"
fi
[ ! -e "$XDG_CONFIG_HOME/aerolith/ai.json" ] || fail "ai.json left behind"
! grep -q 'aerolith:ai' "$hypr/aerolith/aerolith.lua" || fail "AI bind still in fragment"
[ -x "$HOME/.local/bin/$expected_provider" ] || fail "independently installed provider CLI was removed"
# Removing modules/ai makes Quickshell reload the shell; wait until the
# Command Core is really open before typing (fixed sleeps lost keys).
deck_mapped() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("deckMapped"))' "$(ipc status 2>/dev/null)" 2>/dev/null; }
ipc open command >/dev/null
for _ in $(seq 50); do [ "$(deck_mapped)" = True ] && break; sleep 0.1; done
[ "$(deck_mapped)" = True ] || fail "the Command Core did not open after ai remove"
sleep 0.5
typ "vol 40"; sleep 0.5; key Return
for _ in $(seq 30); do wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" && break; sleep 0.1; done
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" || fail "core shell broken after ai remove"

# Full uninstall.
aerolith --yes uninstall --remove-config >"$OUT/uninstall.log" 2>&1 || fail "uninstall exited $?"
same() { [ "$(sha256sum <"$1")" = "$(sha256sum <"$2")" ]; }
same "$hypr/hyprland.lua" "$OUT/hyprland.lua.orig" || fail "hyprland.lua not restored exactly"
! grep -q 'no_anim' "$hypr/hyprland.lua" || fail "managed animation rules left in main config"
[ ! -e "$hypr/aerolith/aerolith.lua" ] || fail "managed animation fragment left after uninstall"
[ ! -e "$HOME/.local/share/aerolith" ] || fail "data left: $(find "$HOME/.local/share/aerolith")"
if [ "$mode" = system ]; then
  [ "$(pkg_sum)" = "$pkg_before" ] || fail "the packaged tree changed"
  pacman -Qkk aerolith aerolith-ai-bridge >"$OUT/pacman-qkk.log" 2>&1 || fail "pacman reports altered package files: $(cat "$OUT/pacman-qkk.log")"
fi
[ ! -e "$hypr/aerolith" ] || fail "fragment dir left: $(find "$hypr/aerolith")"
[ ! -e "$HOME/.local/bin/aerolith" ] || fail "maintenance tool left in ~/.local/bin"
[ ! -e "$XDG_STATE_HOME/aerolith/manifest.json" ] || fail "manifest left"
[ ! -e "$XDG_CONFIG_HOME/aerolith/installation.json" ] || fail "installation direction left"
for app_config in kitty/kitty.conf foot/foot.ini; do
  [ ! -e "$XDG_CONFIG_HOME/$app_config" ] || fail "owned theme config left: $app_config"
done
[ -x "$HOME/.local/bin/$expected_provider" ] || fail "uninstall removed the provider CLI"
for _ in $(seq 30); do alive || break; sleep 0.1; done
alive && fail "shell still running after uninstall"
# What uninstall deliberately keeps (backups, history), for the record.
find "$XDG_CONFIG_HOME/aerolith" "$XDG_STATE_HOME/aerolith" "$HOME/.local/share" >"$OUT/leftovers.txt" 2>&1 || true
echo "installed: ok"
