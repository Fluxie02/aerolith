# UI-015 unit checks

All checks ran against the final frozen UI-015 source and exited 0 on 2026-10-24. Exact command strings and exit codes are also in `results.json`.

| Command | Result | Log |
| --- | --- | --- |
| `node tests/js/run-node.mjs` | 118 passed, 0 failed | node.log (`node.log`; unavailable in baseline checkout) |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | Qt V4: 118 passed, 0 failed | qt-v4.log (`qt-v4.log`; unavailable in baseline checkout) |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped in 11.61 s | pytest.log (`pytest.log`; unavailable in baseline checkout) |

The same static JS suite index runs in Node and Qt V4. Scheme tests cover catalog/schema parity, invalid-value fallback, validated persistence while preserving unrelated settings/custom overrides, independent palette copies, all twelve palettes, composited planes, inverse selection and focus contrast.
