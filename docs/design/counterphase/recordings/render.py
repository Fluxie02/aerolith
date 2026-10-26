"""Offline ffmpeg overlay and delivery encode; no smoothing or retiming."""
import json
from pathlib import Path
import re
import subprocess
import sys

base = Path(__file__).resolve().parent
profile = sys.argv[1]
run = base / profile
events = [json.loads(line) for line in (run / "events.jsonl").read_text().splitlines()]
clock = json.loads((run / "clock.json").read_text())
# Wayland ready timestamps use the same CLOCK_MONOTONIC as the driver. wf-recorder
# subtracts the first presentation timestamp when writing the VFR file.
ready = re.search(r"zwlr_screencopy_frame_v1[#@]\d+\.ready\((\d+),\s*(\d+),\s*(\d+)\)", (run / "recorder.log").read_text())
assert ready, "Need first screencopy ready event for accurate chapter alignment"
hi, lo, ns = map(int, ready.groups())
first_presentation = (hi << 32) + lo + ns / 1e9
offset = first_presentation - clock["recorder_launch_monotonic"]
assert -.1 < offset < 2, offset
for event in events:
    event["time"] = max(0, event["time"] - offset)
    event["done"] = max(0, event["done"] - offset)
duration = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(run / "raw.mkv")], text=True))
(run / "timing.json").write_text(json.dumps({"first_presentation_monotonic": first_presentation, "recorder_initialization_seconds": offset, "raw_duration": duration, "timecode": "mm:ss.ff, frames 00..29", "method": "real-time compositor PTS; fps=30 frame hold/drop only, no interpolation, no retiming"}, indent=2)+"\n")
font = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
# wf-recorder's conversion produced limited-range samples but marks its master
# full-range. Correct the frame metadata, without transforming sample values.
filters = ["setparams=range=limited", "fps=30", "drawbox=x=8:y=1042:w=780:h=30:color=black@0.82:t=fill"]
# ff denotes the frame number within the second, 00..29 at 30 fps.
tc = r"%{eif\:floor(n/1800)\:d\:2}\:%{eif\:mod(floor(n/30),60)\:d\:2}.%{eif\:mod(n,30)\:d\:2}"
filters.append(f"drawtext=fontfile={font}:text='{tc}':x=16:y=1049:fontsize=17:fontcolor=white")
chapters = []
for i, event in enumerate(events):
    start = event["time"]
    end = events[i+1]["time"] if i+1 < len(events) else duration
    if start >= duration or end <= start: continue
    label = event["chapter"]
    # All input labels are local, static strings. Restrict ffmpeg syntax anyway.
    assert all(c.isalnum() or c in " /+-." for c in label), label
    filters.append(f"drawtext=fontfile={font}:text='{label}':x=136:y=1049:fontsize=17:fontcolor=white:enable='gte(t,{start:.6f})*lt(t,{end:.6f})'")
    chapters.append({"start": start, "end": end, "label": label})
(run / "overlay.ffmpeg").write_text(",\n".join(filters)+"\n")
(run / "chapters.json").write_text(json.dumps(chapters, indent=2)+"\n")
metadata = [";FFMETADATA1"]
for chapter in chapters:
    metadata += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={round(chapter['start']*1000)}", f"END={round(chapter['end']*1000)}", "title="+chapter["label"]]
(run / "chapters.ffmetadata").write_text("\n".join(metadata)+"\n")
command = ["ffmpeg", "-hide_banner", "-y", "-i", str(run / "raw.mkv"), "-i", str(run / "chapters.ffmetadata"), "-map", "0:v:0", "-map_metadata", "1", "-map_chapters", "1", "-filter_script:v", str(run / "overlay.ffmpeg"), "-t", str(duration), "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-maxrate", "2000k", "-bufsize", "4000k", "-threads", "2", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p", "-color_range", "tv", "-fps_mode", "cfr", "-movflags", "+faststart", str(base / (profile+".mp4"))]
(run / "encode-command.json").write_text(json.dumps(command, indent=2)+"\n")
with (run / "encode.log").open("w") as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
print(profile, "encode exit", result.returncode, flush=True)
raise SystemExit(result.returncode)
