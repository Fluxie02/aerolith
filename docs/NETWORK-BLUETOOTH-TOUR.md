# Network, Bluetooth and first-run tour: contract and work record

From the owner brief (`docs/design/OWNER-BRIEF-2026-10.md`): the top bar gets
**network** (Wi-Fi/ethernet, click to switch) and **Bluetooth** (click to
connect), roadmap D08, and a **short first-run tour** of the four or five key
things. Astra listed the fields the UI needs in
`docs/design/redesign-1/RESULTS.md` ("Later round, Sol"). This file is the
contract between the three jobs and their status record.

## Rules (Opus)

- Event driven. No polling and no background scanning: Wi-Fi scanning and
  Bluetooth discovery run only while a picker asks for them (a demand count),
  and stop when it closes.
- A missing backend (no NetworkManager, no BlueZ, no adapter) is a normal
  state, not an error: `available: false`, no warnings in the log, and the UI
  hides or greys the control. Many users run iwd or systemd-networkd only.
- Never log, store or expose a Wi-Fi password. A PSK goes straight from the
  input to `connectWithPsk` and is cleared.
- Global singletons, one per shell (never per monitor).
- Actions go through `Registry` so the command search, IPC and the UI share one
  path, each with an `available` reason.

## Contract

### `services/Network.qml` (Sol), on `Quickshell.Networking`

| Property | Meaning |
|---|---|
| `available` | a backend is present |
| `kind` | `"wifi"`, `"ethernet"` or `"none"`: the device carrying the active connection, ethernet first |
| `state` | `"connected"`, `"connecting"`, `"disconnected"`, `"unavailable"` |
| `connectionName` | SSID or wired connection name, `""` if none |
| `signal` | 0–100 for Wi-Fi, -1 otherwise |
| `online` | connectivity check result when the backend offers it, else `connected` |
| `wifiAvailable`, `wifiEnabled` | a Wi-Fi device exists; radio on |
| `networks` | sorted `[{ name, signal, secured, known, connected, connecting, failed, failReason }]`: connected first, then known, then signal; one entry per SSID |

Actions: `setWifiEnabled(bool)`, `connect(name)` (known or open network),
`connectWithPsk(name, psk)`, `disconnect()`, `forget(name)`,
`requestScan()` / `releaseScan()` (demand count).

### `services/Bluetooth.qml` (Sol), on `Quickshell.Bluetooth`

| Property | Meaning |
|---|---|
| `available` | BlueZ and an adapter are present |
| `powered` | default adapter on |
| `adapterName` | |
| `discovering` | |
| `devices` | sorted `[{ address, name, icon, connected, paired, connecting, battery }]`: connected, then paired, then name; battery -1 if unknown |
| `connectedCount` | |

Actions: `setPowered(bool)`, `connect(address)`, `disconnect(address)`,
`pair(address)`, `forget(address)`, `requestDiscovery()` /
`releaseDiscovery()` (demand count).

### `services/Tour.qml` (Terra)

| Property | Meaning |
|---|---|
| `active` | the tour is showing |
| `step`, `steps` | current index; ordered step ids (`hatch`, `ring`, `search`, `apps`, `strip`) |
| `completed` | finished or skipped at least once (persisted) |

Actions: `start()`, `next()`, `back()`, `skip()`, `finish()`. It starts once
on first run when `tour.enabled` (config, default true) and not `completed`,
only on the primary output, never while locked or during fullscreen, and
waits for those to clear. `completed` lives in `Store`, so a reinstall keeps
it and a user config is never touched. Command "Show the tour again".

### UI (Astra, after the services land)

Top-bar network and Bluetooth indicators with a picker each (switch Wi-Fi,
enter a password, connect a device), and the tour visuals. Design only;
services are not changed in that job.

## Assignments

| Who | Task | Files |
|---|---|---|
| Sol | NB-1: Network and Bluetooth services, pure logic, Registry actions, status fields, D-Bus mocks in the harness, scenario | `services/Network.qml`, `services/Bluetooth.qml` (new), `lib/network.mjs`, `lib/bluetooth.mjs` (new), `modules/ControlSurface.qml`, `tools/headless/*`, `tools/devcontainer/Containerfile`, `tests/js/{network,bluetooth}.test.mjs`, `tests/scenarios/network.sh` (new) |
| Terra | TOUR-1: tour state | `services/Tour.qml`, `lib/tour.mjs` (new), `lib/config.mjs` (+ schema), `core/Store.qml`, `tests/js/tour.test.mjs`, `tests/scenarios/tour.sh` (new) |
| Astra | UI-NB: indicators, pickers, tour visuals | strip and tour components |
| Opus | contract, review, harness runs, merge, PR | — |

## Status

- [x] NB-1 (Sol): Network and Bluetooth services, demand-only scanning/discovery, Registry toggles, status fields, private system bus with dbusmock NetworkManager/BlueZ (NET=1), network.sh. Sol ran its own headless runs. Opus verified: network NET=1 and NET=0 pass. Limits: availability needs a device; several wired profiles show the interface name (Quickshell 0.3.2 exposes no active-profile id).
- [x] TOUR-1 (Terra): Tour state, Store persistence (versioned), tour.enabled, primary-output, lock and fullscreen hold, "Show the tour again", tour.sh. Terra ran its own headless runs. Opus: suites registered, CI steps (network, network-absent, tour), tour status field, harness marks the tour done unless TOUR=1. Opus verified: JS 233, pytest 306; tour, smoke, network, fullscreen, deck, app-links, catalogue pass.
- [ ] UI-NB (Astra)
- [ ] Final review and PR (Opus)
