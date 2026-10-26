# UI-015 verification

All final checks below passed on 2026-10-24. No systems hosts or services were changed. The frozen final shell matches all 80 production source files exactly (`source-comparison.json`). Node/Qt each passed 118 tests; pytest passed 71 with 1 skipped. Exact unit commands are in [unit/README.md](unit/README.md).

## Headless checks

All commands exited 0. `SHELL_PATH` points to the frozen production source; separate fixtures are named explicitly for visual-only previews. Every result text begins with its exact command and ends with the exit code. Screenshots, statuses, IPC logs and `qs.log` live in each matching `runs/<name>/` directory.

| Run | Exit | Exact command |
| --- | ---: | --- |
| smoke | 0 | `SHELL_PATH="build/ui015/verification/final-shell" CONFIG="/home/user/aerolith-astra/build/ui015/verification/saturated.json" tools/headless/run.sh tests/scenarios/smoke.sh build/ui015/verification/smoke` |
| full | 0 | `SHELL_PATH="build/ui015/verification/final-shell" AUDIO="1" MEDIA="1" MPV_AO="pipewire" ROUTINES="tests/fixtures/routines.json" CONFIG="/home/user/aerolith-astra/build/ui015/verification/saturated.json" tools/headless/run.sh tests/scenarios/full.sh build/ui015/verification/full` |
| deck | 0 | `SHELL_PATH="build/ui015/verification/final-shell" AUDIO="1" HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" CONFIG="/home/user/aerolith-astra/build/ui015/verification/insane.json" tools/headless/run.sh tests/scenarios/deck.sh build/ui015/verification/deck` |
| ai | 0 | `SHELL_PATH="build/ui015/verification/final-shell" AUDIO="1" AI="1" CONFIG="/home/user/aerolith-astra/build/ui015/verification/insane.json" tools/headless/run.sh tests/scenarios/ai.sh build/ui015/verification/ai` |
| settings-focus | 0 | `SHELL_PATH="build/ui015/verification/final-shell" CONFIG="/home/user/aerolith-astra/build/ui015/verification/saturated.json" tools/headless/run.sh build/ui015/verification/settings-focus.sh build/ui015/verification/settings-focus` |
| lock-schemes | 0 | `SHELL_PATH="build/ui015/verification/preview-lock" tools/headless/run.sh build/ui015/verification/capture-lock.sh build/ui015/verification/lock-schemes` |
| osd-schemes | 0 | `SHELL_PATH="build/ui015/verification/preview-osd" tools/headless/run.sh build/ui015/verification/capture-osd.sh build/ui015/verification/osd-schemes` |
| session-schemes | 0 | `SHELL_PATH="build/ui015/verification/preview-session" tools/headless/run.sh build/ui015/verification/capture-session.sh build/ui015/verification/session-schemes` |
| lock-compact | 0 | `SHELL_PATH="build/ui015/verification/preview-lock" RES="1280x720" tools/headless/run.sh build/ui015/verification/compact-preview.sh build/ui015/verification/lock-compact` |
| osd-compact | 0 | `SHELL_PATH="build/ui015/verification/preview-osd" RES="1280x720" tools/headless/run.sh build/ui015/verification/compact-preview.sh build/ui015/verification/osd-compact` |
| session-compact | 0 | `SHELL_PATH="build/ui015/verification/preview-session" RES="1280x720" tools/headless/run.sh build/ui015/verification/compact-preview.sh build/ui015/verification/session-compact` |

The four required scenarios cover Command keyboard invocation, audio effects, workspace dispatch, routine execution, Systems demand release, Deck lifecycle/rapid switches/no-focus expiry, geometry, save failure rollback, AI proposal approval and module removal. The routines fixture deliberately includes the rejected `broken-example`/`rm.rf`; its CFG count and warning are expected fixture evidence, not configuration errors. Full status records `configErrors: 0`.

After the required scenario queue, two count-label bindings were refreshed from the production tree: SchemePicker exposes catalogue length and Settings reads it. They do not change the catalogue or JS logic. The focused Settings run loaded that final QML and verified initial keyboard focus, End/Enter scheme selection and saved Glacial, Tab into the register, text-draft Escape without closing Settings, Tab back to the picker, and Escape to close.

## Additional surfaces

Lock, OSD and Session fixtures reuse the production views and dependencies in disposable snapshots; they add only an ordinary overlay window and fixture IPC. The lock preview does **not** secure a session, and session/OSD controls perform no system work. Their production hosts were not modified.

Each surface captured all twelve schemes with live `Config.setValue("theme.scheme", id)`, checked the resulting active configuration, then captured Insane/reduced and Insane/off/lowEffects with Noto at scale 1.25. Separate 1280×720 captures verify literal untrusted strings in compact layouts. There are 45 additional-surface PNGs. [Pixel verification](preview-pixel-verification.json) passes 36/36 scheme images: selected surface/signal/text pigments occur exactly, and the corner field sample matches within one colour-channel level for the translucent Session plane. Small antialiased text need not contain exact full-coverage textDim pixels; those counts are diagnostic only.

Representative frames were visually inspected: Ferrite lock, Lichen OSD, Corona Session, live Glacial picker and compact literal states. Source review and the corrected stale Trace repaint are in [PALETTE-REVIEW.md](PALETTE-REVIEW.md). The required single review of Claude's current systems contracts is in [SYSTEMS-REVIEW.md](SYSTEMS-REVIEW.md).

The log audit contains no QML parse/type/reference/assignment/binding errors in any passing final run. Expected headless warnings include unavailable Hyprland global shortcuts, missing RTKit/system bus and absent system power facilities; these do not replace real compositor testing.

## Performance

The [frozen baseline](baseline/README.md) is THEARS/Saturated/full at the pre-UI-015 revision: 1.04% initial idle, 0.93% idle after use, 198.7 MiB peak RSS. Its first excluded Wayland readiness startup attempt is retained under `attempts/`; the same command passed unchanged on retry.

Final PIYTI Saturated/Corona and Insane/Ferrite default-length measurements run sequentially without screenshot or test containers on the host.

| Direction / intensity / scheme | Initial idle % core | After-use idle % core | Initial / after-use RSS MiB | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: |
| Frozen baseline THEARS / Saturated / original Limb | 1.04 | 0.93 | 123.5 / 127.3 | 198.7 |
| PIYTI / Saturated / Corona | 0.98 | 0.93 | 124.7 / 128.1 | 207.5 |
| PIYTI / Insane / Ferrite | 2.36 | 2.47 | 126.6 / 129.7 | 203.6 |

Both final benchmarks completed with `perf: ok`, exit 0. All four final idle samples are below the UI-013 budgets. Each final result log records its exact command and exit code. All default windows are 120 s initial idle, 30 s Systems open, 30 s Command open and 30 s idle after use. The direction differs from the THEARS baseline, so it is not a controlled single-variable performance comparison. The UI-013 owner budgets are approximately 2% Saturated / 4% Insane of one core.



Final exact commands (both exited 0):

```sh
SHELL_PATH="build/ui015/verification/final-shell" AUDIO="1" MEDIA="1" CONFIG="/home/user/aerolith-astra/build/ui015/verification/saturated.json" tools/headless/run.sh tests/scenarios/perf.sh build/ui015/verification/piyti-saturated-perf
SHELL_PATH="build/ui015/verification/final-shell" AUDIO="1" MEDIA="1" CONFIG="/home/user/aerolith-astra/build/ui015/verification/insane.json" tools/headless/run.sh tests/scenarios/perf.sh build/ui015/verification/piyti-insane-perf
```

## Reproduction and limits

The archived scripts are in `scripts/`; run `prepare-preview.py` from either archive or build location to recreate the preview snapshots. The verification driver expects its shell snapshot/configs under `build/ui015/verification/` and uses the unchanged repository `tools/headless/run.sh` and scenarios. Do not mutate snapshots while they run. Source manifests identify the measured source.

Sway/pixman and Qt Quick software at 1920×1080/scale 1 are the default. Root Astra's separate capture matrix establishes the four 4K direction/intensity combinations, every scheme across bays, compact picker and live switch sequence. The harness cannot establish real Hyprland/GPU/VRAM behaviour, secure-lock integration or automatic external app-theme activation.

## Final deferred-layout check

After the performance runs, `AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/rapid-settings.sh build/ui015/rapid-settings` exited 0. Twenty immediate Settings → Command → close cycles exercised the deferred containment callback across view exits, followed by a settled picker selection. The log (`runs/rapid-settings/qs.log`; unavailable in baseline checkout) has no QML errors. No production change followed.
