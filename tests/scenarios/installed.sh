# shellcheck shell=bash
# Installer integration scenario. Run with
#   INSTALL="--ai claude --startup hyprland" AUDIO=1 tools/headless/run.sh tests/scenarios/installed.sh
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
grep -q 'aerolith:ai' "$hypr/aerolith/aerolith.lua" || fail "AI bind missing from fragment"
aerolith status --json >"$OUT/status.json"
expected_direction=$(python3 -c 'import os,shlex; a=shlex.split(os.environ["INSTALL"]); print(a[a.index("--direction")+1] if "--direction" in a else "piyti")')
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["direction"] == sys.argv[2], s' "$OUT/status.json" "$expected_direction" || fail "installer direction"
ipc status >"$OUT/shell-status.json"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["direction"] == sys.argv[2], s' "$OUT/shell-status.json" "$expected_direction" || fail "running shell direction"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["installed"] and s["mode"] == sys.argv[2] and s["ai_provider"] == "claude" and s["hyprland_dialect"] == "lua", s' "$OUT/status.json" "$mode" \
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
[ -x "$HOME/.local/bin/claude" ] || fail "independently installed provider CLI was removed"
ipc open command; sleep 0.8; typ "vol 40"; sleep 0.5; key Return; sleep 1.5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" || fail "core shell broken after ai remove"

# Full uninstall.
aerolith --yes uninstall --remove-config >"$OUT/uninstall.log" 2>&1 || fail "uninstall exited $?"
same() { [ "$(sha256sum <"$1")" = "$(sha256sum <"$2")" ]; }
same "$hypr/hyprland.lua" "$OUT/hyprland.lua.orig" || fail "hyprland.lua not restored exactly"
[ ! -e "$HOME/.local/share/aerolith" ] || fail "data left: $(find "$HOME/.local/share/aerolith")"
if [ "$mode" = system ]; then
  [ "$(pkg_sum)" = "$pkg_before" ] || fail "the packaged tree changed"
  pacman -Qkk aerolith aerolith-ai-bridge >"$OUT/pacman-qkk.log" 2>&1 || fail "pacman reports altered package files: $(cat "$OUT/pacman-qkk.log")"
fi
[ ! -e "$hypr/aerolith" ] || fail "fragment dir left: $(find "$hypr/aerolith")"
[ ! -e "$HOME/.local/bin/aerolith" ] || fail "maintenance tool left in ~/.local/bin"
[ ! -e "$XDG_STATE_HOME/aerolith/manifest.json" ] || fail "manifest left"
[ ! -e "$XDG_CONFIG_HOME/aerolith/installation.json" ] || fail "installation direction left"
[ -x "$HOME/.local/bin/claude" ] || fail "uninstall removed the provider CLI"
for _ in $(seq 30); do alive || break; sleep 0.1; done
alive && fail "shell still running after uninstall"
# What uninstall deliberately keeps (backups, history), for the record.
find "$XDG_CONFIG_HOME/aerolith" "$XDG_STATE_HOME/aerolith" "$HOME/.local/share" >"$OUT/leftovers.txt" 2>&1 || true
echo "installed: ok"
