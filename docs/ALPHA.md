# AEROLITH 0.1.0 alpha 1

The first version meant for daily use, so its problems can be found. Expect
rough edges: the design will change (see
[the owner brief](design/OWNER-BRIEF-2026-10.md)), and settings or commands
may still be renamed.

## What you need

- Arch Linux (or an Arch-based distribution) with **Hyprland** running.
- **Quickshell 0.3.0 or newer**, Python 3.11 or newer.
- One or more displays. Ground and the Flight Strip run on every enabled
  output. Set `display.primary` and per-output `display.outputs` options in
  `~/.config/aerolith/config.json`; see [Configuration](CONFIGURATION.md).

`./install.sh` checks all of this first and says what is missing.

## Install, update, remove

```bash
git clone https://github.com/Fluxie02/aerolith.git ~/aerolith
cd ~/aerolith
./install.sh                     # asks a few questions; --dry-run shows the plan
```

The installer copies the shell to `~/.local/share/aerolith`, adds the
`aerolith` command and, if you choose `--startup hyprland`, starts AEROLITH
with Hyprland. It keeps your existing Hyprland configuration and backs up
anything it changes.

- **Update:** `cd ~/aerolith && git pull && ./install.sh`. Reinstalling keeps
  your settings and earlier choices.
- **Check:** `aerolith doctor` and `aerolith status`.
- **Remove:** `aerolith uninstall` (keeps your configuration;
  `--remove-config` removes it too).

## Using it

- **Super + Space** (or a click on AEROLITH in the top bar) opens the command
  overlay: type to search apps and commands. **Super + Tab** shows all
  windows, **Super + Shift + Escape** the session menu (lock, log out,
  power). Inside the overlay, **F1** shows shortcut help and available commands.
  The Super keys are added when you let the installer set up Hyprland (`aerolith hypr
  show` lists them).
- The desktop shows your workspaces, open windows and an application bar:
  click an application to switch to it, again to go to its next window, or
  to start it.
- The Hatch opens scratch space: click it or press **Super + S** to toggle;
  **Super + Shift + S** parks the focused window there.
- Click the network or Bluetooth indicator in the Flight Strip to open its
  picker. Network controls include Wi-Fi power, scanning and connections;
  Bluetooth controls include power, discovery, pairing and connections.
  Enterprise Wi-Fi needs setup in an external tool first.
- A first-run tour introduces the Hatch, workspaces, search, apps and strip.
  Enter/Right advances, Left goes back and Esc skips. Replay it by searching
  for **Show the tour again** in Command Core (`tour.enabled` must be true).
- OLED outputs can use `display.outputs.<connector>.profile: "oled"` for
  black fills and idle dimming/decoration hiding; configure `display.oled`
  in [Configuration](CONFIGURATION.md). This does not change monitor brightness.
- Fullscreen games: AEROLITH steps back while a window is fullscreen and
  comes back when it leaves.
- The lock screen is off by default. Turn it on with
  `"lock": { "enabled": true }` in `config.json`. It fails closed: if the
  shell crashes or reloads while locked, the session stays locked without a
  prompt. To recover, switch to a text console (Ctrl + Alt + F3), log in and
  run `hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'`,
  then `hyprctl --instance 0 dispatch exec hyprlock` (install `hyprlock`
  first), and unlock with your password.

## Known gaps in this alpha

- **The desktop design is being reworked.** See the owner brief for its direction.
- Fullscreen detection on named workspaces and NVIDIA memory readings were
  fixed after a real-hardware report and still need a second confirmation.
- No Arch package yet: install from the repository as above.
- Shader and high-refresh performance has not been profiled on real GPUs.

## Reporting a problem

Open an issue on GitHub with:

1. what you did, what you expected and what happened (a screenshot helps);
2. the output of `aerolith status --json` and `aerolith doctor`;
3. the shell log: the newest `log.qslog` under
   `/run/user/$(id -u)/quickshell/by-id/`, or run `qs -p
   ~/.local/share/aerolith/shell` in a terminal and copy what it prints.

The log never contains passwords; check it for anything else private before
posting.
