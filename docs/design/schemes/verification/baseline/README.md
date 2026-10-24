# UI-015 frozen baseline

Exact command (exit 0):

```sh
SHELL_PATH=build/ui015-baseline-shell AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui015/baseline-perf
```

Frozen pre-UI-015 production source; **THEARS / Saturated** default, full motion, 1920×1080 / scale 1, no custom configuration. Default 120 s initial idle / 30 s remaining sample lengths. The THEARS baseline is labelled explicitly; final PIYTI runs have a different application direction.

Initial idle: 1.04% of one core, 55.7 context switches/s, 123.5 MiB RSS. Idle after use: 0.93%, 52.1/s, 127.3 MiB RSS. Peak RSS 198.7 MiB. `perf: ok`; no QML parse/type/reference/assignment/binding errors in qs.log.

The first startup did not reach Configuration Loaded because Wayland connection readiness raced; that excluded attempt is retained under `../attempts/baseline-wayland/`. The same exact command then passed without source changes.
