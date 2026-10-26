#!/usr/bin/env bash
# Illustrative real Wayland recording; never run during timed measurements.
set -euo pipefail
cd "$(dirname "$0")/../../.."
out="$PWD/docs/design/smooth/video"
recorder=${UI016_RECORDER:-/tmp/ui014-recorder/wf-recorder}
test -x "$recorder"
test -f build/ui016/after-shell/shell.qml
mkdir -p "$out"
chmod 777 "$out"
python3 docs/design/smooth/prepare-session.py
printf '{"schemaVersion":1,"theme":{"intensity":"saturated","motion":"full"}}\n' > build/ui016/video-config.json
sha256sum "$recorder" > "$out/recorder-sha256.txt"
docker run --rm --cap-add=SYS_NICE \
  -v "$PWD:/src:ro" -v "$out:/out" -v "$recorder:/capture-tools/wf-recorder:ro" \
  -e UI016_HZ=144 -e UI016_KIND=recording -e SHELL_PATH=build/ui016/after-shell \
  -e RES=1920x1080@144Hz -e UI016_CONFIG=/src/build/ui016/video-config.json \
  aerolith-dev bash -c '
    set -e
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000 /home/pilot/.config/aerolith
    chown pilot /run/user/1000; chmod 700 /run/user/1000
    cp "$UI016_CONFIG" /home/pilot/.config/aerolith/config.json
    chown -R pilot /home/pilot
    exec su pilot -c "bash /src/build/ui016/session.sh /src/docs/design/smooth/record-scenario.sh"
  ' > "$out/result.txt" 2>&1
ffmpeg -y -loglevel warning -i "$out/raw.mkv" -c copy -bsf:v h264_metadata=video_full_range_flag=0 -movflags +faststart "$out/motion.mp4"
ffprobe -v error -show_streams -show_format -of json "$out/motion.mp4" > "$out/ffprobe.json"
python3 - "$out" <<'PY'
import json,sys
from pathlib import Path
out=Path(sys.argv[1]); probe=json.loads((out/'ffprobe.json').read_text())
video=next(s for s in probe['streams'] if s['codec_type']=='video')
(out/'README.md').write_text('''# Illustrative motion recording

`motion.mp4` records the actual 1920×1080 shell on the configured 144 Hz headless output, encoded by wf-recorder at 30 fps. It includes Deck open, bay switches, two Spectra selections, close, workspace changes and the resumed ambient carrier stroke. No frames are interpolated and playback is not sped up or slowed down. A 30 fps movie cannot demonstrate 144 fps physical smoothness; this recording is excluded from all CPU and callback timing measurements.

`outputs.json` proves the configured output mode. `events.jsonl` records the actual IPC/key command windows, `clock.json` records the recording epoch, and `ffprobe.json` retains the codec/frame-rate/duration metadata. wf-recorder uses a constant 30 fps encoder and may repeat or omit captured frames to maintain wall time. `raw.mkv` is the original encoder stream; `motion.mp4` remuxes it with its moov atom at the front. The recorder marks limited-range samples as full-range; the MP4 corrects only the H.264/stream range metadata, without re-encoding, changing sample values, or changing timestamps. The existing recorder binary checksum is in recorder-sha256.txt; no package was installed.

Reproduce with `bash docs/design/smooth/record-motion.sh` after creating the final `build/ui016/after-shell` snapshot. The recorder defaults to the existing `/tmp/ui014-recorder/wf-recorder`; override UI016_RECORDER if the same binary is stored elsewhere. Record only outside CPU/pacing benchmark windows.
''')
print(json.dumps({'codec':video['codec_name'],'width':video['width'],'height':video['height'],'avg_frame_rate':video['avg_frame_rate'],'duration':probe['format']['duration'],'bytes':probe['format']['size']}))
PY
