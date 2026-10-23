# UI-012 unit verification

Run against the working tree on 2026-10-23 before UI-012 shell edits. Every command exited 0.

| Command | Result | Evidence |
|---|---|---|
| `node tests/js/run-node.mjs` | 104 passed, 0 failed | [node.log](node.log) |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | Qt V4: 104 passed, 0 failed | [qt-v4.log](qt-v4.log) |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped in 13.83 s | [pytest.log](pytest.log) |

Exact commands, exit codes and elapsed times: [results.json](results.json). The skipped Python test requires `luac` on the host; the Node and Qt runs both include the palette contrast gate. These checks do not verify real compositor operation or GPU memory release.
