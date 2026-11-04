# UI-NB — Network, Bluetooth and quick tour

4 November 2026. Astra. Production services, IPC, host release logic and
existing scenarios are unchanged. No commit was made.

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

Native PNGs are grouped under `1080/`, `4k/`, and `oled/`: Ethernet, connected
Wi-Fi, network list, masked password, Bluetooth devices/battery, absent
hardware, and each of the five tour steps. OLED is the primary tour output in
that capture. `compact/` checks all tour steps at 1280×720, UI scale 1.5 and
reduced motion. Test probes exist only in disposable shell copies; production
objects have stable objectNames.

| View | 1080p | 4K / 1.5 | OLED + standard |
|---|---|---|---|
| Ethernet | [PNG](1080/01-ethernet.png) | [PNG](4k/01-ethernet.png) | [PNG](oled/01-ethernet.png) |
| Wi-Fi | [PNG](1080/02-wifi.png) | [PNG](4k/02-wifi.png) | [PNG](oled/02-wifi.png) |
| Network picker | [PNG](1080/03-network.png) | [PNG](4k/03-network.png) | [PNG](oled/03-network.png) |
| Password | [PNG](1080/04-password.png) | [PNG](4k/04-password.png) | [PNG](oled/04-password.png) |
| Bluetooth | [PNG](1080/05-bluetooth.png) | [PNG](4k/05-bluetooth.png) | [PNG](oled/05-bluetooth.png) |
| No backend / adapter | [PNG](1080/06-unavailable.png) | [PNG](4k/06-unavailable.png) | [PNG](oled/06-unavailable.png) |
| Tour: hatch | [PNG](1080/tour-0.png) | [PNG](4k/tour-0.png) | [PNG](oled/tour-0.png) |
| Tour: ring | [PNG](1080/tour-1.png) | [PNG](4k/tour-1.png) | [PNG](oled/tour-1.png) |
| Tour: search | [PNG](1080/tour-2.png) | [PNG](4k/tour-2.png) | [PNG](oled/tour-2.png) |
| Tour: apps | [PNG](1080/tour-3.png) | [PNG](4k/tour-3.png) | [PNG](oled/tour-3.png) |
| Tour: strip | [PNG](1080/tour-4.png) | [PNG](4k/tour-4.png) | [PNG](oled/tour-4.png) |

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
