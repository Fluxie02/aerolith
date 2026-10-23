UI-011 unit verification (2026-10-23)

- `node tests/js/run-node.mjs`: exit 0, 104 passed, 0 failed. Full output: node.log.
- `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'`: exit 0, Qt V4 104 passed, 0 failed. Full output: qt-v4.log.
- `python3 -m pytest -q tests/py`: exit 0, 71 passed, 1 skipped (15.06 seconds). Full output: pytest.log.

Event capture helpers available to custom headless scenarios:

- `mock '{"op":"focus_workspace","workspace":2}'` changes the mock compositor's workspace and emits its real socket events.
- `mock '{"op":"open","class":"foot","title":"A new focused window","workspace":2}'` opens and focuses a window in the active workspace; its JSON result contains the address. `mock '{"op":"close","address":"0x..."}'` closes it.
- `ipc run workspace.focus '{"workspace":2}'` uses production dispatch, while `ipc run window.focus '{"address":"0x..."}'` changes window focus.
- `wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.7` or `ipc run audio.volume.set '{"level":70}'` produces a real PipeWire/service update with AUDIO=1.
- `ipc open command`, `typ 'foot'`, `key Down`, `ipc open navigator`, `key Right` exercise actual input and selection.
- `ipc run shell.notify '{"message":"Systems acquired"}'` creates a keyed notice; `notify-send` can create a DBus popup.
- `shot name` calls grim to write a full screenshot; for denser motion frames launch a background `for` loop with `shot` and `sleep 0.04` immediately before the triggering event. Each grim capture adds overhead, so frame timing is illustrative rather than a frame-rate benchmark.

No production files modified; no headless or performance run launched by the unit verification subagent.
