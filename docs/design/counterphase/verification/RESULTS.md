# UI-013 verification — Counterphase

PIYTI is the development base and the first review target after the owner's resumed direction. THEARS receives compatibility checks in both intensities and no further design development. Application direction is an installation-only choice for Claude to wire; no Settings control is proposed or added. The disposable PIYTI shell changes only `Theme.applicationDirection` from `thears` to `piyti`.

## Saved unit checks

The interrupted run's completed unit checks were retained. Commands ran from `/home/user/aerolith-astra`:

| Command | Exit | Result |
| --- | --- | --- |
| `node tests/js/run-node.mjs` | 0 | 104 passed, 0 failed |
| `docker run --rm -v /home/user/aerolith-astra:/src:ro aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 0 | Qt V4: 104 passed, 0 failed |
| `python3 -m pytest -q tests/py` | 0 | 71 passed, 1 skipped |

Exact records and stdout are in `unit-final/`. Subsequent source fixes touched only the QML ambient lifecycle and a Theme comment. Final headless scenarios use refreshed copies of those QML files.

## Reproduction

After temporary shell copies have been removed, recreate both explicitly before rerunning:

```sh
python3 docs/design/counterphase/scripts/verify.py freeze --direction thears
python3 docs/design/counterphase/scripts/verify.py freeze --direction piyti
```

`python3 docs/design/counterphase/scripts/campaign.py` defaults to PIYTI first, runs at most two of its own containers, retains completed results on resume, and then checks THEARS compatibility. Every `*.result.json` contains the exact underlying command, environment, exit code, elapsed time and manifest digest. All commands and environments are also retained in `final-command-index.json` when this campaign finishes.

Scenario commands are:

```sh
python3 docs/design/counterphase/scripts/verify.py --round final scenario --direction piyti --intensity saturated --scenario smoke
python3 docs/design/counterphase/scripts/verify.py --round final scenario --direction piyti --intensity saturated --scenario full
python3 docs/design/counterphase/scripts/verify.py --round final scenario --direction piyti --intensity saturated --scenario deck --deck-native-output
python3 docs/design/counterphase/scripts/verify.py --round final scenario --direction piyti --intensity saturated --scenario ai
```

Repeat with `--intensity insane`, and with `--direction thears`. Full uses `AUDIO=1 MEDIA=1 MPV_AO=pipewire` and the routines fixture with the intentionally broken example removed. AI uses `AI=1 AUDIO=1`. Deck uses `AUDIO=1`, a rotated Hyprland mock (`--mode 2560x1440 --scale 1.5 --transform 1`), and a native 1920×1080 headless physical output.

An earlier portrait physical Sway output lost keyboard focus on a rapid Command reopen (`runs/saturated-deck.stdout.txt`, exit 1). Keeping the same rotated/scaled Hyprland mock on the native physical output passed. The failure and the successful fallback are preserved; no input handler was changed to hide it. Real Hyprland focus on a physical portrait monitor remains a systems check.

## Compact and physical 4K capture protocol

Capture commands use `verify.py --round final capture --direction piyti --intensity saturated --profile <profile>`, repeated for Insane. Profiles are `compact-off`, `compact-reduced`, `compact-lowEffects`, `4k-scale2`, `4k-scale1.5`, `4k-scale1`.

Compact is a real 1280×720 output at uiScale 1.5. Each case captures idle, Command, Settings and Navigator, retaining `status*.json` with zero configuration/routine errors and a closed, unmapped Deck. Off, reduced and lowEffects are separate cases in both intensities.

All 4K cases use `RES=3840x2160` and matching `HYPR_MOCK_ARGS="--mode 3840x2160 --scale ..."`, with compositor scale 2/uiScale 1, scale 1.5/uiScale 1, and scale 1/uiScale 1.5. The PNGs are physically 3840×2160; `output-geometry.json` and `mock-geometry.json` retain the output and logical geometries. Both intensities are checked. `final-runs/piyti-*` is the current review set; earlier THEARS captures remain in `final-runs/` without the prefix.

A critic identified a real incomplete Canvas frame in the first PIYTI Insane 4K/scale 2 Command capture despite an exit-0 scenario and clean log. The original is preserved under `attempts/piyti-insane-4k-scale2-uiScale1-missing-canvas/`; exit 0 alone does not validate that image. A targeted same-mode recapture waits five seconds in Command, closes/remaps, reopens Command, and retains all four frames with `capture-4k-stability.sh`.

## Source identity and interruption handling

All shell files are SHA-256 indexed. `capture-source-hashes.json` and `capture-piyti-source-hashes.json` preserve the pre-final-motion capture sources. `source-hashes.json` and `piyti-source-hashes.json` identify the refreshed final scenario source. PIYTI differs only in its application-direction default. `late-motion-changes.json` records the exact three changed files: reduced focus impulse suppression, deferred callback gate checks, live intensity stroke cancellation and the installation comment. These changes do not change the static layout. Completed static captures were kept.

Six PIYTI scenario passes that completed before those final motion guards were archived under `before-final-motion/` and rerun on the final source. Original THEARS 4K/compact captures and unit checks were not repeated. Temporary shell copies are deleted only after all root motion/performance checks finish; their manifests remain.

## Final status

Final runtime matrix: **16/16 scenarios passed**, all exit 0 on the refreshed final source.

| Scenario | PIYTI Saturated | PIYTI Insane | THEARS Saturated | THEARS Insane |
| --- | --- | --- | --- | --- |
| smoke | 0 | 0 | 0 | 0 |
| full (audio/media/routines) | 0 | 0 | 0 | 0 |
| deck (audio, rotated/scaled Hyprland mock, native physical output) | 0 | 0 | 0 | 0 |
| ai (fake provider, approve/removal) | 0 | 0 | 0 | 0 |

All **24 compact/4K capture cases** exited 0; `capture-geometry.json` independently confirms every PNG's physical dimensions and the matching real output scale/geometry. PIYTI's six compact and six physical 4K cases are the current review set. The anomalous original Canvas capture remains excluded; its five-second settled and reopened replacements were visually checked and show complete Ground, Bezel and Carriage geometry. The original software-rendering anomaly is documented rather than erased.

`python3 docs/design/counterphase/scripts/audit-logs.py --round final` exited 0: **40 retained qs.log copies checked, zero QML/runtime-error pattern matches, zero source reloads**. The retained `.txt` files copy the ignored `qs.log` files verbatim. Known harness diagnostics remain: unsupported Hyprland shortcut/toplevel protocols under Sway, unavailable UPower/system D-Bus, PipeWire context connection in cases launched without AUDIO, RTKit privilege warnings, and Sway text-input/focus warnings. None is claimed to be a production Hyprland result.

`final-command-index.json` records all 40 exact runtime command/environment/result entries (16 scenarios and 24 captures). `final-source-audit.json` confirms the final THEARS copy matches all 78 production shell files and PIYTI differs only in the direction default. Root records independent screenshot/motion review and CPU measurements in the round README and REVIEWS. The campaign ran at most two of its own containers while separate root motion/performance runs were also active; these scenario timings are not isolated CPU benchmarks.

Manifest digests:

| Manifest | SHA-256 |
| --- | --- |

| `capture-source-hashes.json` | `389bc67e1b70923802878cd9947ba1b732cac6a174add8ab9c65a46d04306875` |
| `capture-piyti-source-hashes.json` | `0208189ba59f0616ad22fff07d5fb4b4ee13fe41b1c7058549050fa1b9d3533d` |
| `source-hashes.json` | `4fabeb4da829182e35f0d616c5407abd02f2e07731dcddf5993e14be0dd5e706` |
| `piyti-source-hashes.json` | `00b307e4d456e5c43f7464200a6bb5de121c66aa744551969b953421000a5c9a` |

Temporary `frozen-shell` and `piyti-shell` verification copies were deleted after all verification containers exited and root released them. All manifests, configs, scripts, screenshots, failed attempts and command/log records remain. No production QML, host, service, config library or schema file was edited by this verification subtask; no git mutation, completion event or unlock was attempted here.
