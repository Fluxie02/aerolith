# UI-016 final unit checks

All required unit engines passed against production source whose complete SHA-256 manifest is retained in `production-source-hashes.json`. Its 80 files matched the provisional runtime snapshot exactly after the checks (`../provisional-current-comparison.json`). `test-source-hashes.json` identifies the shared tests. Exact commands, timestamps, exit codes and elapsed times are in `results.json`.

| Command | Exit | Result | Output |
| --- | ---: | --- | --- |
| `node tests/js/run-node.mjs` | 0 | 118 passed, 0 failed | `node.txt` |
| `docker run --rm -v /home/user/aerolith-astra:/src:ro aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 0 | Qt V4: 118 passed, 0 failed | `../unit-provisional/qt-v4.txt` |
| `python3 -m pytest -q tests/py` | 0 | 71 passed, 1 skipped | `pytest.txt` |

The Qt output retains its original provisional-directory name because it ran during the cleared functional gap immediately before the Node/Python final records. It tested the same unchanged shared JavaScript suites and production source; the log has not been retimed or rewritten. Any final source difference will be recorded explicitly in the final comparison before these results are applied to the handoff.
