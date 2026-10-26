# UI-014 observed faults

Timecodes use `mm:ss.ff` at 30 fps.
Nothing is fixed here. Repeated instances are preserved in each recording.

* **P2 — Notices obscure Deck navigation.** At PIYTI `01:26.00`, `01:34.00`
  and `01:38.00` in both intensities, and THEARS `00:41.00` / `00:45.00`,
  the notification or volume notice covers the Help and Settings tabs at
  the top right. Calibration review observed the same collision. Affected
  presentation: `shell/modules/deck/DeckView.qml`, `shell/modules/notices/NoticeStack.qml`.
  Minimal future correction: reserve a notice area below or clear of the rail.

* **P2 — No production OSD / brightness control.** Volume commands produce
  generic notices, not the existing passive `OsdView`. Brightness IPC returns
  `error: unknown command brightness.set`. `shell/shell.qml` instantiates no
  OSD host; brightness has no service/command. Minimal future correction:
  Claude wires an OSD host to audio feedback and supplies brightness support.
  PIYTI: volume attempts `01:32.29` and `01:36.29`, brightness `01:40.29`;
  THEARS: volume `00:43.13`, brightness `00:45.13`. Input events and the
  brightness error response are retained in each `events.jsonl`.
* **P2 — Wayland focus warnings on bay changes.** `qs.log` records
  `QWaylandTextInputv3::disableSurface ... but 0x0 is focused` and
  `Ignoring unexpected wl_keyboard.leave event ... compositor bug`.
  Input still changes the bays in the observed captures. The warning alone
  does not establish a fault on real Hyprland. Minimal future correction:
  reproduce the bay focus sequence on supported Hyprland before changing
  lifecycle or compositor code. Preserve the harness warnings in full.
  They occur around bay changes and input, PIYTI about `00:30.00`–`01:47.00`,
  THEARS about `00:17.00`–`00:47.21`. Exact aligned times and full messages
  are saved in each profile's `log-warnings.json`.
* **Harness limitation — Unlinked media fixture.** The real mpv MPRIS player
  appears, but Signal reports its audio stream as `unlinked` / 0%; the harness
  also warns `mpv stream not linked`. This is not evidence of silent audio on
  a real desktop. Retest routing in a normal PipeWire session.
  Visible at PIYTI `00:44.00` (both) and THEARS `00:24.00`.
* **Fixture warning — Invalid routine.** The supplied routines fixture
  intentionally contains `broken-example` with unknown action `rm.rf`.
  `qs.log` reports it; the strip's `CFG 1` and Routines error are retained.
  A clean installation should use valid user routines; do not suppress
  validation to remove this warning.
  Routines: PIYTI `00:48.00` (both), THEARS `00:26.00`. `CFG 1` is already
  present after first-boot assembly because of this supplied invalid routine.

Other startup warnings are harness constraints: sway lacks Hyprland global
shortcuts and toplevel mapping protocols, and no system bus/UPower is present.
They occur around `00:01.00`–`00:02.00`; controls are driven through real
virtual-keyboard input and IPC instead. THEARS's `harness.log` also contains
PipeWire RTKit/system-bus errors near the final volume inspection (about
`00:48.00`); real-time scheduling is unavailable. These messages are retained.

## Recorded timing gaps

These are measured intervals between original captured frames, not inferred
shell-renderer defects. The delivery repeats the displayed frame through each
gap; there is no interpolation or stutter removal. They are short enough that
visual review cannot reliably attribute them to the shell or recorder.

| Recording | Delivery timecode near gap | Source PTS | Interval |
| --- | --- | --- | --- |
| PIYTI Saturated | `00:12.04` | 12.119 s | 61 ms |
| PIYTI Saturated | `02:00.01` | 120.048 s | 76 ms |

Insane and final THEARS have no interval above 50 ms. There is no source gap
above 100 ms in any final take. Raw PTS CSVs, maximum/median intervals and
frame counts are retained in each profile's verification evidence. The
earlier THEARS take in `attempts/short-tab-hold/` has gaps of 69 ms at source
12.180 s and 55 ms at 32.963 s. It was replaced because its Tab-to-typing
hold was too short; the final take holds that state for over two seconds.

## Capture-only color metadata error

The first delivery encodes looked washed out. The recorder marked its master
full-range even though its converted YUV samples contain limited-range levels.
An untouched calibration `grim` screenshot has background RGB `(13,18,21)`;
decoding the incorrectly tagged master yields `(27,30,33)`. Correct limited-range
interpretation yields approximately `(12,16,20)` after YUV420 subsampling.

The delivery corrects the range metadata (`setparams=range=limited`, output
`-color_range tv`) without grading, transforming the sampled levels, changing
motion or modifying shell code. The initial encoded previews are retained in
`attempts/incorrect-range-metadata/`; raw masters retain their original flag.
Use the corrected MP4s at this directory's top level to judge shell colors.

Pre-recording attempts are kept in `attempts/`. The first launcher omitted
the existing harness's required `SYS_NICE` capability, so sway could not
execute and Quickshell could not connect to Wayland. No video was produced.
The launcher was corrected to match the existing wrapper, without editing
the harness or shell. The first complete Saturated run is retained as timing
calibration: recorder launch precedes the first frame. An initial ~0.3 s
estimate was file-creation lag, which includes encoder setup and cannot
measure frame zero. Final runs use exact Wayland presentation timestamps;
their measured offsets are 63–67 ms. Calibration had source gaps of 52 ms
at raw `00:18.13` and 58 ms at raw `00:58.07`, plus seven 50–70 ms gaps
before shell launch. These remain in its retained raw master.

Independent read-only review of Claude's systems layer completed once for
UI-014: the OSD/brightness finding above is the actionable systems finding.
No revision is made because UI-014 explicitly prohibits fixes.
