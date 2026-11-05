**P2-ASTRA — layout fit, 5 November 2026**

Implemented ASTRA decision 1 / M2 and portrait–ultrawide–1080p fit. Base:
`36b1dc2a1fa3faf59196a82b7dbe0b42e1d18cef`. No commit made.

`geometry.mjs` classifies the available output after its actual strip reservation
and `theme.uiScale`: compact below 1500 wide **or** 850 high. Density sizes
content; it no longer introduces different breakpoints. Theme supplies the same
policy to Ground, Strip, Deck (including ChordSlot) and Tour. Bezel and Lock
retain named local clock/form/header minimum sizes with unchanged values.

Portrait uses the compact station row; its decorative ring radius also fits the
narrow axis. Ultrawide means available aspect ratio >2:1: media, entry controls,
core comb and window register cap at 420; the app register caps at 1120, before
UI scaling and independently of density. Existing origins/bearings and the
primary-only app register remain. Applying these caps only to ultrawide preserves
the established 16:9 composition.

Compact stations, including projecting marks, clear both the strip and app row
by at least two Theme gaps. At 1280×720, comfortable/bottom, measured app clearance
is **16**, strip clearance **85**, gap **8**. The window register scrolls all
windows within a maximum three-row viewport bounded two gaps above the shared
second bearing. Its position mark appears on hover or after scrolling. A
one-border horizontal clip allowance preserves fractional-scale rule endpoints.
No added animation, timer, integration, lifecycle or sampling changes.

**Pixel identity: both pairs byte-identical; zero changed pixels.**
The deterministic fixture freezes telemetry, disables motion and hides the strip;
this proves resting Ground identity, not live strip/clock identity. Reference:
`mkdir -p build/p2-astra/reference` then
`git archive 36b1dc2a1fa3faf59196a82b7dbe0b42e1d18cef shell | tar -x -C build/p2-astra/reference`.
Raw RGB PPM SHA-256 pairs are in [pixels.json](pixels.json). Initial 4K clipping
removed six rule-endpoint pixels; the allowance above corrected all six.

Commands below ran from the worktree. **Every listed command exited 0.** Logs,
raw captures and probe snapshots are under `build/p2-astra/` (ignored by Git).

| Exact command | Result |
| --- | --- |
| `docker info --format '{{.ServerVersion}}'` | 29.9.1; existing daemon only |
| `node tests/js/run-node.mjs` | 273 passed, 0 failed; geometry 11/11 |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/p2-astra/smoke` | smoke: ok |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/p2-astra/tour` | tour: ok |
| `TOUR=1 RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/tour.sh build/p2-astra/tour-4k` | tour: ok |
| `TOUR=1 RES=1080x1920 tools/headless/run.sh tests/scenarios/tour.sh build/p2-astra/tour-portrait` | tour: ok |
| `tools/headless/run.sh tests/scenarios/app-links.sh build/p2-astra/app-links-final` | app-links: ok |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/p2-astra/multimonitor` | multimonitor: ok |
| `AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/p2-astra/oled-final` | oled: ok; idle zero swaps/3 s |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/p2-astra/deck-final` | deck: ok |
| `SHELL_PATH=build/p2-astra/reference/shell tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-astra/pixels-before-1080` | reference captured |
| `tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-astra/pixels-after-1080` | 1920×1080 identical |
| `SHELL_PATH=build/p2-astra/reference/shell RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-astra/pixels-before-4k` | reference captured |
| `RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-astra/pixels-after-4k` | 3840×2160 ×1.5 identical |
| `bash -n docs/design/phase2/capture.sh` | pass |
| `git diff --check` | pass |

An initial Node assertion incorrectly expected an ultrawide window register to
fill its cap even when its original width was smaller; corrected to test a
maximum. An early OLED/Deck overlap was discarded for sequencing purposes; both
were rerun sequentially as the `*-final` commands above. All remaining headless
checks and captures ran one at a time. Headless Network/RTKit/PipeWire backend
messages without the corresponding fixtures are expected, with no QML errors.

[capture.sh](capture.sh) instruments only a disposable container copy. Every
capture checks actual station/strip/app clearance, matching compact flags across
Strip/Ground/Deck/ChordSlot/Tour, media/app caps, window clipping and scroll range,
and the measured tour ring target. Run:
`<environment below> tools/headless/run.sh docs/design/phase2/capture.sh build/p2-astra/<case>`.
All nine cases passed; [fit.json](fit.json) records measurements. JPEGs retain
full target resolution; eleven files total about 2.2 MiB, each below 4 MiB.

| Case | Environment | Ground evidence |
| --- | --- | --- |
| ground-1080 | defaults | [1920×1080](ground-1920x1080.jpg) |
| ground-4k | `RES=3840x2160 SCALE=1.5` | [4K ×1.5](ground-3840x2160-scale1.5.jpg) |
| ground-1366 | `RES=1366x768` | [1366×768](ground-1366x768.jpg) |
| ground-720 | `RES=1280x720` | [1280×720](ground-1280x720.jpg) |
| ground-portrait | `RES=1080x1920` | [portrait](ground-1080x1920.jpg) |
| ground-portrait-1440 | `RES=1440x2560` | [large portrait](ground-1440x2560.jpg) |
| ground-ultrawide | `RES=3440x1440` | [ultrawide](ground-3440x1440.jpg) |
| ground-superwide | `RES=5120x1440` | [superwide](ground-5120x1440.jpg) |
| ground-comfortable-bottom | `RES=1280x720 CONFIG=build/p2-astra/comfortable-bottom.json` | [comfortable/bottom](ground-1280x720-comfortable-bottom.jpg) |

The bottom fixture contains `{"theme":{"density":"comfortable"},"strip":{"edge":"bottom"}}`.
Tour step 2: [portrait](tour-1080x1920.jpg), [ultrawide](tour-3440x1440.jpg).

Changed production files: `shell/lib/geometry.mjs`, `shell/core/Theme.qml`;
components `AppContinuity`, `Bezel`, `ChordSlot`, `Counterphase`, `Hatch`,
`InstrumentField`, `Instrumentation`, `WorkspaceOrbit`; module views
`strip/FlightStrip`, `deck/DeckView`, `lock/LockView`, `tour/TourHost`.
Also `tests/js/geometry.test.mjs` and this evidence directory. NowPlaying's
existing content consumes the capped parent width without component changes.

Peer review of Terra's measured-anchor/lease and shared workspace integration:
no actionable findings. Used the owner-authorized Claude-held P2-ASTRA reservation;
Astra's additional LockView lock is released at completion, leaving Opus's
reservation for its owner. Published as Astra. No daemon lifecycle operations,
host configuration, global installs or secrets access. Follow-up: owner review
and real Hyprland/GPU/mixed-scale hardware verification; headless software
rendering cannot establish those results.
