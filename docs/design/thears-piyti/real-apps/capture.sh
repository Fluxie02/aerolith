#!/usr/bin/env bash
# Sourced inside the existing tools/headless/session.sh, under pilot.
# DIRECTION is the app asset direction. SHELL_PATH selects matching shell.
set -euo pipefail
trap 'echo "FAILED_LINE: $LINENO"' ERR
direction=${DIRECTION:-thears}
sleep 3
printf '%s\n' "$direction" >"$OUT/direction.txt"
firefox --version >"$OUT/app-versions.txt" 2>&1
libreoffice --version >>"$OUT/app-versions.txt" 2>&1

# Sway manages the real clients. The Hyprland protocol mock stays separate;
# these app windows are deliberately not injected into its simulated state.
swaymsg 'default_border pixel 2'
swaymsg 'client.focused #ceebac #1b282b #edf3f5 #ceebac #ceebac'
swaymsg 'for_window [app_id="firefox"] floating enable'
swaymsg 'for_window [app_id="libreoffice-writer"] floating enable'

profile="$HOME/firefox-$direction"
mkdir -p "$profile/chrome"
cp "/src/themes/firefox/$direction/userChrome.css" "$profile/chrome/"
cp "/src/themes/firefox/$direction/userContent.css" "$profile/chrome/"
cat >"$profile/user.js" <<'EOF'
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("browser.newtabpage.enabled", false);
EOF
MOZ_ENABLE_WAYLAND=1 MOZ_WEBRENDER=0 \
  firefox --no-remote --profile "$profile" \
  file:///src/docs/design/thears-piyti/real-apps/fixture.html >"$OUT/firefox.log" 2>&1 &
firefox_pid=$!
PIDS+=("$firefox_pid")
sleep 12
swaymsg -t get_tree >"$OUT/firefox-preposition-tree.json"
swaymsg '[app_id="(?i).*firefox.*"] floating enable, resize set 1250 760, move position 560 125' || true
sleep 1
swaymsg -t get_tree >"$OUT/firefox-sway-tree.json"
shot firefox
kill "$firefox_pid" 2>/dev/null || true
wait "$firefox_pid" 2>/dev/null || true
sleep 1

# LibreOffice profile is preseeded by run-captures.sh for the installed
# application's own registry format. Use GTK3 so the shared GTK theme applies.
cp /src/docs/design/thears-piyti/real-apps/fixture.fodt "$HOME/fixture.fodt"
SAL_USE_VCLPLUGIN=gtk3 libreoffice \
  "-env:UserInstallation=file://$HOME/libreoffice-$direction" \
  --nologo --norestore --nodefault --writer "$HOME/fixture.fodt" \
  >"$OUT/libreoffice.log" 2>&1 &
lo_pid=$!
PIDS+=("$lo_pid")
sleep 12
swaymsg -t get_tree >"$OUT/libreoffice-preposition-tree.json"
swaymsg '[app_id="(?i).*libreoffice.*"] floating enable, resize set 1250 820, move position 560 110' || true
sleep 1
swaymsg -t get_tree >"$OUT/libreoffice-sway-tree.json"
shot libreoffice
kill "$lo_pid" 2>/dev/null || true
pkill -u "$(id -u)" -f soffice.bin 2>/dev/null || true
wait "$lo_pid" 2>/dev/null || true
sleep 1

photo_app=/tmp/photocraft/photocraft-0.10.0-linux-x86_64/bin/photocraft
if [ -x "$photo_app" ]; then
  swaymsg 'for_window [app_id="photocraft"] floating enable'
  LIBGL_ALWAYS_SOFTWARE=1 WGPU_BACKEND=gl "$photo_app" \
    >"$OUT/photocraft.log" 2>&1 &
  photo_pid=$!
  PIDS+=("$photo_pid")
  sleep 12
  swaymsg '[app_id="(?i).*photocraft.*"] floating enable, resize set 1250 820, move position 560 110' || true
  sleep 1
  swaymsg -t get_tree >"$OUT/photocraft-sway-tree.json"
  if kill -0 "$photo_pid" 2>/dev/null; then shot photocraft; fi
  kill "$photo_pid" 2>/dev/null || true
  wait "$photo_pid" 2>/dev/null || true
fi
alive || { echo 'FAIL: Quickshell exited'; exit 1; }
echo "real-apps $direction: capture complete"
