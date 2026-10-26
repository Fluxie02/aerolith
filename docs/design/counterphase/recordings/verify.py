"""Verify delivered streams, logs, source immutability and captured cadence."""
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess

base = Path(__file__).resolve().parent
repo = base.parents[3]
results = {}
def probe(path, *args):
    return json.loads(subprocess.check_output(["ffprobe", "-v", "error", *args, "-of", "json", str(path)], text=True))
def tc(seconds):
    frame = round(seconds*30)
    return f"{frame//1800:02d}:{frame//30%60:02d}.{frame%30:02d}"
for profile in ["piyti-saturated", "piyti-insane", "thears-saturated"]:
    run = base / profile
    video = base / (profile+".mp4")
    source = probe(run / "raw.mkv", "-select_streams", "v:0", "-show_packets", "-show_entries", "packet=pts_time")
    pts = [float(p["pts_time"]) for p in source["packets"]]
    gaps = [(a,b-a) for a,b in zip(pts,pts[1:]) if b-a > .05]
    (run / "source-pts.csv").write_text("frame,pts_seconds\n"+"".join(f"{i},{t:.6f}\n" for i,t in enumerate(pts)))
    timing = json.loads((run / "timing.json").read_text())
    timed_logs = [json.loads(line) for line in (run / "qs-timed.jsonl").read_text().splitlines()]
    warnings = []
    for line in timed_logs:
        if re.search(r"WARN|ERROR|FATAL|TypeError|ReferenceError|Unable to assign|Binding loop",line["line"]):
            t = max(0,line["time"]-timing["recorder_initialization_seconds"])
            warnings.append({"time":t,"timecode":tc(t),"message":re.sub(r"\x1b\[[0-9;]*m","",line["line"])})
    (run / "log-warnings.json").write_text(json.dumps(warnings,indent=2)+"\n")
    stream_data = probe(video, "-show_format", "-show_streams")
    stream = next(s for s in stream_data["streams"] if s["codec_type"]=="video")
    assert (stream["width"],stream["height"])==(1920,1080)
    assert stream["codec_name"]=="h264" and stream["pix_fmt"]=="yuv420p"
    # x264 may omit the default limited-range flag entirely. Full-range would
    # be signalled as pc (and decode with elevated blacks in this capture).
    assert stream.get("color_range", "tv")=="tv", stream
    assert stream["avg_frame_rate"]=="30/1"
    assert video.stat().st_size < 40_000_000
    decode = subprocess.run(["ffmpeg","-v","error","-threads","2","-i",str(video),"-f","null","-"],capture_output=True,text=True)
    assert decode.returncode==0 and not decode.stderr,decode.stderr
    raw_bytes = video.read_bytes()
    assert raw_bytes.find(b"moov") < raw_bytes.find(b"mdat"),"faststart missing"
    hashes=json.loads((run / "source-hashes.json").read_text())
    changed=[name for name,sha in hashes.items() if hashlib.sha256((repo/name).read_bytes()).hexdigest()!=sha]
    assert not changed,changed
    final=json.loads((run / "status-final.json").read_text())
    assert final["deckMapped"] is False and final["configErrors"]==0 and final["ai"] is True
    assert json.loads((run/"notification-arrived.json").read_text())["popups"]==1
    assert json.loads((run/"notification-expired.json").read_text())["popups"]==0
    errors=[w for w in warnings if re.search(r"TypeError|ReferenceError|Unable to assign|Binding loop|FATAL|ERROR",w["message"])]
    assert not errors,errors
    chapter_labels=[c["label"] for c in json.loads((run/"chapters.json").read_text())]
    assert all(any(f"Ctrl+{n}" in c for c in chapter_labels) for n in range(1,8))
    assert any("F1" in c for c in chapter_labels) and any("Tab" in c for c in chapter_labels)
    result={"file":video.name,"bytes":video.stat().st_size,"sha256":hashlib.sha256(raw_bytes).hexdigest(),"duration":float(stream_data["format"]["duration"]),"codec":stream["codec_name"],"profile":stream["profile"],"level":stream["level"],"pixel_format":stream["pix_fmt"],"resolution":[1920,1080],"fps":stream["avg_frame_rate"],"faststart":True,"decode_errors":0,"source_files_changed":changed,"qml_engine_errors":errors,"log_warnings":len(warnings),"raw_frames":len(pts),"raw_frame_span":pts[-1]-pts[0],"raw_effective_fps":(len(pts)-1)/(pts[-1]-pts[0]),"raw_median_interval":statistics.median(b-a for a,b in zip(pts,pts[1:])),"raw_max_interval":max(b-a for a,b in zip(pts,pts[1:])),"source_gaps_over_50ms":[{"start":a,"timecode":tc(a),"duration":d} for a,d in gaps],"timing":timing}
    (run/"verification.json").write_text(json.dumps(result,indent=2)+"\n")
    results[profile]=result
(base / "verification.json").write_text(json.dumps(results,indent=2)+"\n")
print(json.dumps({k:{f:v[f] for f in ["bytes","duration","raw_effective_fps","raw_max_interval","log_warnings"]} for k,v in results.items()},indent=2))
