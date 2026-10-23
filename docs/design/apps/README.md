# UI-010 — graphical applications join AEROLITH

Uninstalled appearance fragments are ready in [themes/](../../../themes/README.md).
GTK 3 and GTK 4 retain Adwaita/libadwaita and receive colour/shape overrides.
Qt Widgets use the complete qt5ct/qt6ct palette with stock Fusion and an optional
small rounding stylesheet. Inter labels, JetBrains Mono code, smoked surfaces,
phosphor interaction, 10 px controls and 20 px window corners follow Limb.
The shared application palette works with Saturated and Insane.

Selection stays dark on phosphor in active and inactive windows. GTK's keyboard
focus uses an opaque 2 px ring, with a dark inset ring on filled accent/error
controls; Qt's rounded controls use an opaque 2 px palette-highlight border.
Default buttons remain distinguishable before focus. Native Qt view focus cues
remain with Fusion. Font sizes remain user preferences; the preview uses 11 pt.
No shell, host, service, configuration implementation or schema was edited.

## Rendering evidence and limits

The dev image contains **no** gtk4-demo, gtk3-demo, pavucontrol,
nm-connection-editor, zenity, qt5ct, qt6ct, Qt Assistant/Designer or Qt example
application. GTK 3/4 and Qt 5 development libraries are also absent in the image.
[Availability output](availability.txt) records the check. No packages were installed.

Qt 6.12 Widgets development libraries are present, so [palette-preview.cpp](palette-preview.cpp)
builds a small, explicitly labelled rendering fixture using native Qt Widgets.
It reads the actual shipped `.conf` with QSettings, applies all 22 roles to all
three QPalette groups, uses Fusion, loads the actual shipped QSS and records
its effective palette and resolved Inter font in [palette.json](palette.json).
This validates the QSettings format and native Qt 6 rendering; the unavailable
qt5ct/qt6ct platform-theme plugins and Qt 5 runtime were not exercised.

The three PNGs are direct headless-harness screenshots alongside the real
Ground and Flight Strip, with fixture-controlled focus and selection:

- [Palette and rounded controls](01-qt-palette-with-shell.png)
- [Entry selection and focus](02-qt-entry-selection.png)
- [Qt Widgets file picker](03-qt-file-picker.png)

The file picker is QFileDialog with `DontUseNativeDialog`: native Qt Widgets,
not a desktop portal. Its directory is the repository's real `themes/` folder.
This fixture changes no audio/network/system setting. The harness uses sway,
so exterior window corners stay rectangular: the existing Hyprland fragment
supplies compositor rounding on the target desktop. No real Hyprland/GPU,
GTK 4/libadwaita rendering, third-party app, sandbox or portal coverage is claimed.
GTK 3.24.41 is available as a host runtime library; its own CSS parser accepts
the GTK 3 fragment with **zero errors or warnings** ([output](gtk3-parser.txt)).

The first preview attempt exited 2 because the Wayland app ID was not set.
A corrected attempt mapped the app, but exposed vertically clipped Qt entry
text from the QSS padding and did not capture the file-picker frame reliably.
The final QSS sets a font-relative minimum control height; the final scenario
uses separate fixture states, explicit mapping checks and settled frames.
The screenshot review also caught Qt's stylesheet engine regenerating a dimmer
placeholder when `color` was set. The QSS now inherits text colours directly
from QPalette; the fixture asserts that the polished entry retains the exact
opaque PlaceholderText role and records it in `palette.json`.
The shape layer is limited to plain entries and buttons: native Fusion
spin/combo controls retain their arrows, frame layout and focus affordances.
Only the final captures are retained here. These are rendering checks, not
claims that the earlier synthetic keyboard traversal passed.

## Contrast

[verify.py](verify.py) reads the emitted GTK named colours and every Qt palette
group. [contrast.json](contrast.json) records all **91 passing pairs**.
It uses WCAG sRGB relative luminance, with enabled text >=4.5:1 and focus >=3:1.

| Treatment | Lowest checked ratio |
| --- | ---: |
| Secondary text on the lightest normal surface | 6.53:1 |
| Text on a hovered control | 7.44:1 |
| Selection text, active or inactive | 14.45:1 |
| Phosphor focus against dark adjacent fills, including hover | 6.40:1 |
| Dark inset focus on a destructive control | 8.94:1 |

These are opaque colour-pair checks. Toolkit disabled opacity, app-private CSS,
unmodified native control effects and pixels over third-party content are not
included. Disabled palette values are checked, but their final dimmed rendering
is excluded from the enabled-text claim. The optional CSS should be omitted
when a user selects a high-contrast theme.

## Reproduction

Run from the repository root, using the existing `aerolith-dev` image:

```bash
python3 docs/design/apps/verify.py
mkdir -p build/ui010
docker run --rm -v "$PWD:/src" aerolith-dev bash -lc \
  'cd /src && g++ -std=c++17 -fPIC docs/design/apps/palette-preview.cpp -o build/ui010/palette-preview $(pkg-config --cflags --libs Qt6Widgets)'
tools/headless/run.sh docs/design/apps/capture.sh build/ui010/preview
node tests/js/run-node.mjs
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py
AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" \
  tools/headless/run.sh tests/scenarios/deck.sh build/ui010/deck
CONFIG=tests/fixtures/notify-config.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/ui010/notify
AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui010/perf
git diff --check
```

Final results: Node **104/104**, Qt V4 **104/104**, Python **71 passed / 1 skipped**;
Deck geometry/lifecycle and notification scenarios **passed**; Qt preview
**passed**; `git diff --check` **passed**. The final preview and three shell
scenario `qs.log` files contain no QML parse, type, reference, assignment or
binding-loop errors. Native Qt logs have Wayland text-input focus warnings;
the initial keyboard-driven capture's warnings are not a keyboard validation.
PipeWire reports the harness's missing system bus/RTKit privileges; audio
initialization and the required scenarios still complete.

Performance smoke (`perf.sh`, default 120 s idle / 30 s per subsequent state):
initial idle **0.25%** of one core, **123.0 MiB** RSS; Systems open **3.66%**,
**157.0 MiB**; Command open **0.40%**, **154.4 MiB**; idle after use **0.23%**,
**126.5 MiB**; peak **183.8 MiB**. This is a shell regression smoke run under
software rendering, not a GTK/Qt application performance benchmark or a
before/after comparison: none of the new fragments is loaded by the shell.
See [perf.json](perf.json) and the saved unit-test outputs and `*-qs.log` files.

## One review of Claude's integration

Reviewed the Settings integration in commit `5649b02` once, limited to
`Ui.qml` bay registration, `Deck.qml` mapping and Ctrl+7 routing,
`ShellCommands.qml` registration, and the Settings schema traversal/mutation
contract. No actionable finding in those reviewed portions: bay IDs and
shortcuts agree, mutations use the existing validated `Config.setValue`, and
this task adds no implicit application-configuration write path. No files in
Claude's domain were changed. Claude's single systems review of UI-010 remains
the next handoff; owner approval precedes installer integration.
