# UI-NB — Network, Bluetooth and quick tour

4 November 2026. Original UI evidence by Astra; NB-2 behavior coverage and
evidence compaction by Sol. No production code or visual design changed in
NB-2. No commit was made.

The strip now has one Network and Bluetooth cell per output, hidden when its
backend or hardware is absent. Short status words and Wi-Fi strength stay
within the existing annunciator rhythm. Clicking opens a bounded connection
list on that output. Selected rows have an opaque focus edge, saved/connected
status is written out, and secured networks have a drawn lock. Existing Bezel
geometry and type carry through the pickers and tour.

The two picker types share one housing and keyboard implementation. Arrows
select; Enter acts; Esc, outside click and the same indicator close. A masked
password input calls `Network.connectWithPsk` directly and clears itself before
removal. A metadata-only row snapshot keeps incoming scans from destroying the
input while typing; it contains no password. Each constructed picker acquires
one demand and releases it on destruction, including output removal. Closed
pickers have no surface or scan demand. Opening uses a brief Theme fade; no new
idle loop or timer was added.

The five-step tour uses the primary output's DisplayProfile. Search uses the strip's layout and measured brand typography; other highlights
use the exact logical layout equations from Hatch, WorkspaceOrbit and
Instrumentation. Cards stay
clear of the target, including the compact ring layout. Back/Next/Skip, arrows,
Enter and Esc work; finishing, skipping and fullscreen destroy the surface.
The installer default in `installer/aerolith_install/hypr.py` is Super+Space.
Settings remains reachable by opening Search and typing Settings. The final
step names only available connection controls, and uses general status-bar
guidance when neither backend is present.

OLED uses the destination palette: black recessed fills, retained near-black
planes and full-contrast functional text. Reduced motion keeps a short fade;
off motion removes it and highlight travel. The two-output capture uses the
OLED seed fixture, with only the disposable user's primary changed to
HEADLESS-2 and idle timeout raised to 300 seconds for legible captures. The
fixture supplies the same test-only idle override as the existing OLED
scenario for compositors without reliable idle notifications.

## Evidence

JPEG previews are grouped under `1080/`, `4k/`, and `oled/`: Ethernet, connected
Wi-Fi, network list, masked password, Bluetooth devices/battery, absent
hardware, and each of the five tour steps. OLED is the primary tour output in
that capture. `compact/` checks all tour steps at 1280×720, UI scale 1.5 and
reduced motion. Test probes exist only in disposable shell copies; production
objects have stable objectNames.

All 38 original shots are retained at JPEG quality 85, with a maximum width
of 1920 pixels (4K and dual-output captures are reduced proportionally).
`evidence.json` records both preview and original capture dimensions. The
whole directory is under 4 MiB; layout assertions still use original capture
geometry. `visuals.sh` and `compact.sh` write JPEGs via `jpeg.sh` using the
dev image's ffmpeg. Check the archive alone with
`python3 docs/design/network-tour/checks.py --evidence-only`.

| View | 1080p | 4K / 1.5 | OLED + standard |
|---|---|---|---|
| Ethernet | [JPEG](1080/01-ethernet.jpg) | [JPEG](4k/01-ethernet.jpg) | [JPEG](oled/01-ethernet.jpg) |
| Wi-Fi | [JPEG](1080/02-wifi.jpg) | [JPEG](4k/02-wifi.jpg) | [JPEG](oled/02-wifi.jpg) |
| Network picker | [JPEG](1080/03-network.jpg) | [JPEG](4k/03-network.jpg) | [JPEG](oled/03-network.jpg) |
| Password | [JPEG](1080/04-password.jpg) | [JPEG](4k/04-password.jpg) | [JPEG](oled/04-password.jpg) |
| Bluetooth | [JPEG](1080/05-bluetooth.jpg) | [JPEG](4k/05-bluetooth.jpg) | [JPEG](oled/05-bluetooth.jpg) |
| No backend / adapter | [JPEG](1080/06-unavailable.jpg) | [JPEG](4k/06-unavailable.jpg) | [JPEG](oled/06-unavailable.jpg) |
| Tour: hatch | [JPEG](1080/tour-0.jpg) | [JPEG](4k/tour-0.jpg) | [JPEG](oled/tour-0.jpg) |
| Tour: ring | [JPEG](1080/tour-1.jpg) | [JPEG](4k/tour-1.jpg) | [JPEG](oled/tour-1.jpg) |
| Tour: search | [JPEG](1080/tour-2.jpg) | [JPEG](4k/tour-2.jpg) | [JPEG](oled/tour-2.jpg) |
| Tour: apps | [JPEG](1080/tour-3.jpg) | [JPEG](4k/tour-3.jpg) | [JPEG](oled/tour-3.jpg) |
| Tour: strip | [JPEG](1080/tour-4.jpg) | [JPEG](4k/tour-4.jpg) | [JPEG](oled/tour-4.jpg) |

Checks and exact commands: [checks.json](checks/checks.json),
[visual runs](checks/visual-checks.json), [Node](checks/node.txt).
Run the required suite serially with `python docs/design/network-tour/checks.py`.
Visual scripts and their private fixture are retained here for reproduction.

| Required check | Result |
|---|---|
| smoke | exit 0 |
| deck | exit 0 |
| app-links | exit 0 |
| fullscreen | exit 0 |
| network-present | exit 0 |
| network-absent | exit 0 |
| tour | exit 0 |
| oled | exit 0 |
| node | exit 0 — 233 passed, 0 failed |

All four visual runs pass. The three main runs exercise real pointer/keyboard
input, masked entry retained across signal changes, same-indicator / outside /
Esc closing, one demand per open and zero after close, all five tour steps,
exact search-highlight bounds, and no card/target overlap. The OLED run also
checks both demand types when its output is removed. Compact checks fit and
that a subsequent Deck receives F1 and Esc after the tour ends.

The final QML audit covers **14 logs, zero matching engine errors**:
[qml-audit.json](checks/qml-audit.json). Static syntax and whitespace checks
pass: [static.txt](checks/static.txt). Existing scenarios were not edited and
no coordinate adjustment was required. Fullscreen's final 1/10/20-cycle RSS:
181176 / 187244 / 178984 KiB; sustained-growth gate false.

An earlier OLED instrumentation collision was corrected without changing its
scenario. A later tour run was invalidated by an automatic source reload;
its clean isolated rerun passes. [Initial checks](checks/first-checks.json)
and [reload evidence](checks/tour-autoreload.log) retain those limits. The
headless image also logs expected absent optional backends / realtime helpers;
these are distinct from the audited QML engine diagnostics.


## Risks and one systems review

- **Medium, public API limitation — Network.qml:91–95.** `disconnect()`
  disconnects every active device; there is no per-network disconnect or wired
  reconnect action. Connected rows explicitly say “disconnect all” for this supplied operation. The only public wired
  data is the active Ethernet summary, so an inactive cable/profile cannot be
  listed or selected. Minimal follow-up for Opus/Sol: expose wired connection
  rows and a targeted disconnect/connect action before promising wired profile
  switching. Services were left intact as requested.
- Headless software rendering verifies layout, service demand and input paths;
  it does not establish NVIDIA/GPU cost, physical OLED brightness or real
  Wi-Fi authentication / Bluetooth pairing-agent prompts. Hardware validation
  and the single Opus systems/performance review remain.
- Tour geometry deliberately shares existing layout equations. Future changes
  to those desktop elements must update the tour bounds alongside them.
- Sway/Qt log virtual-keyboard focus/leave warnings during surface transitions;
  the final QML error audit is recorded below. The fixture waits for mapped
  surfaces and retries a tour key only if its state has not moved.

Changed production files: `shell/modules/strip/FlightStrip.qml`, new
`NetworkIndicator.qml`, `BluetoothIndicator.qml`, `NetworkPicker.qml`,
`BluetoothPicker.qml`, new `shell/modules/tour/{TourHost,TourCard}.qml`, and the
single lazy tour mount/import in `shell/shell.qml`. Supporting
scripts, captures and this report live entirely in `docs/design/network-tour/`.
An initial strip-id reference collided with the existing OLED probe. The final
implementation leaves the output hosts intact and measures the search mark
inside the tour; existing probes and the static lifecycle check stay intact.
The shared hub's stale UI-016 task label was recorded before edits; the owner's
explicit UI-NB assignment delegates the existing Opus/Claude reservation to
Astra. No external agent was dispatched.

## NB-2 behavior coverage (Sol)

`tests/scenarios/network.sh` now clicks measured indicator/row/input/catcher
coordinates through the harness virtual pointer. For both pickers it asserts
construction on the clicked output, exclusive scan/discovery demand, Esc,
indicator toggle, outside click and Deck dismissal. It checks Quickshell's
`WifiDevice.scannerEnabled` and the mock BlueZ adapter's `Discovering` property.
An unknown WPA2-Personal AP prompts for a password; real typing and Enter
produce exactly one dbusmock `AddAndActivateConnection` carrying the exact
test PSK and expected device/AP/SSID. The input is destroyed afterwards.
The final check searches `qs.log`, both probe snapshots and every file under
the shell's state directory for that PSK. The private mock necessarily sees
the dummy credential; its argument log is not a shell log or an archived
artifact. No real authentication is claimed.

`tests/scenarios/tour.sh` checks the actual `tourHost` on `Displays.primary`,
active keyboard focus, real Enter/Right/Left/Esc, surface destruction after
completion/skip, and destruction/restoration around mock fullscreen. A real
foot window receives an exact line of typed text after dismissal and is
confirmed focused in sway's tree, without a corrective focus command. An
idle virtual keyboard remains attached while focus is probed, since the
headless seat otherwise loses its last keyboard when each wtype exits.
Existing persistence, disabled-tour and startup-fullscreen checks remain.
The fullscreen window is a Hyprland IPC mock; keyboard focus/input use real
sway/Wayland clients.

Shared probes are injected into disposable shell copies by
`fixture.py --behavior`; that mode leaves Idle unchanged. `ui-input.sh` uses `mapToItem`
geometry and output-local pointer mapping, with no fixed click coordinates.
Tour key retries require unchanged state before retrying, and the password
is cleared/retyped before submission if injection is incomplete. Assertions
retain their exact expected states.

Reproduce the serial three-run groups with
`python3 docs/design/network-tour/behavior-checks.py`. Exact commands, exits
and wall times are in [NB-2 results](checks/nb2-behavior.json); each referenced
run has a sibling `nb2-*.txt` transcript. Lock dismissal is explicitly skipped:
it needs the separate LOCK/PAM fixture; both Deck dismissal paths are tested.
Two-output coverage runs separately with `NET=1 OUTPUTS=2`.

All ten final runs passed, each group consecutively and all groups serially:

| Invocation (output directories and exact commands in JSON above) | Exits | Wall seconds |
|---|---|---|
| `NET=1 tools/headless/run.sh tests/scenarios/network.sh` | 0, 0, 0 | 18.34, 18.63, 18.55 |
| `NET=0 tools/headless/run.sh tests/scenarios/network.sh` | 0, 0, 0 | 1.75, 1.87, 1.81 |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh` | 0, 0, 0 | 14.14, 14.69, 14.37 |
| `NET=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/network.sh` | 0 | 28.55 |

These are below the 180-second network and 240-second tour budgets. Final
safe checks and their exact commands: [static checks](checks/nb2-static.txt).
All 38 JPEG dimensions match the manifest; the encoded archive is about
3.54 MiB including scripts, reports and transcripts. No production source,
host configuration, package installation or commit changed in NB-2.

### One UI review finding for Opus

**Medium — unsupported Wi-Fi security silently discards the prompt.**
`shell/modules/strip/NetworkPicker.qml:62` offers the password row for every
unknown secured network; `submit()` at line 205 always calls
`Network.connectWithPsk` and clears/removes the input without reporting its
result. `shell/services/Network.qml:51` reduces the security type to a boolean.
Observed reproduction: add a secured unknown mock AP with WPA/RSN flags 256
(PSK advertised without a cipher), click its row, type and press Enter.
Quickshell rejects its classified security type, logs “has the wrong security
type for a PSK”, and makes no activation call; the input still disappears.
The initial development run retained in `build/nb2/network-dev/qs.log`
demonstrates this; [redacted diagnostic](checks/nb2-ui-review.txt). The same code path for enterprise authentication is an
inference from the missing type distinction, not a hardware-tested claim.
Minimal correction for the owners: expose whether PSK input is supported,
gate this prompt on that capability, and show unsupported-auth guidance for
other secured types. No production fix was made in NB-2.
