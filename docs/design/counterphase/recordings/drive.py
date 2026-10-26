"""Record real Wayland presentation and drive production with keys and IPC."""
import json
import os
from pathlib import Path
import signal
import subprocess
import threading
import time

out = Path(os.environ.get("OUT", "/out"))
shell = os.environ["SHELL_DIR"]
short = os.environ.get("UI014_SHORT") == "1"
duration = 52 if short else 125
subprocess.run(["swaymsg", "--", "output", "HEADLESS-1", "mode", "--custom", "1920x1080@30Hz"], check=True, stdout=(out / "mode-switch.json").open("w"))
subprocess.run(["swaymsg", "-t", "get_outputs", "-r"], check=True, stdout=(out / "outputs.json").open("w"))
events_file = (out / "events.jsonl").open("w", buffering=1)
rec_log = (out / "recorder.log").open("w")
recorder = subprocess.Popen([
    "/capture-tools/wf-recorder", "--no-dmabuf", "-D", "-o", "HEADLESS-1",
    "-c", "libx264", "-p", "preset=ultrafast", "-p", "crf=0", "-p", "threads=2",
    "-x", "yuv420p", "-f", str(out / "raw.mkv"),
], stdout=rec_log, stderr=subprocess.STDOUT, env={**os.environ, "WAYLAND_DEBUG": "client"})
epoch = time.monotonic()
(out / "clock.json").write_text(json.dumps({"recorder_launch_monotonic": epoch, "recorder_launch_unix": time.time(), "duration_target": duration, "timing": "unmodified real time; compositor PTS"}, indent=2))
qs = None
log_thread = None
def event(label, argv=None):
    record = {"time": time.monotonic()-epoch, "chapter": label}
    if argv:
        record["argv"] = argv
        result = subprocess.run(argv, capture_output=True, text=True, timeout=20)
        record.update(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr)
    record["done"] = time.monotonic()-epoch
    events_file.write(json.dumps(record)+"\n")
    if record.get("returncode", 0):
        raise RuntimeError(record)
def at(t, label, argv=None):
    time.sleep(max(0, epoch+t-time.monotonic()))
    event(label, argv)
def ipc(*args): return ["qs", "-p", shell, "ipc", "call", "aerolith", *args]
def key(name): return ["wtype", "-k", "Shift_L", "-k", name]
def ctrl(name): return ["wtype", "-k", "Shift_L", "-M", "ctrl", "-k", name, "-m", "ctrl"]
def status(name):
    result = subprocess.run(ipc("status"), capture_output=True, text=True)
    (out / (name+".json")).write_text(result.stdout)
try:
    at(0, "First-boot assembly / waiting for shell")
    time.sleep(.9)
    qs_log = (out / "qs.log").open("wb")
    timed_log = (out / "qs-timed.jsonl").open("w", buffering=1)
    event("First-boot assembly / fresh process")
    qs = subprocess.Popen(["qs", "-p", shell], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    def copy_log():
        for line in qs.stdout:
            qs_log.write(line)
            qs_log.flush()
            timed_log.write(json.dumps({"time": time.monotonic()-epoch, "line": line.decode(errors="replace").rstrip()})+"\n")
    log_thread = threading.Thread(target=copy_log, daemon=True)
    log_thread.start()
    for _ in range(200):
        if "Configuration Loaded" in (out / "qs.log").read_text(): break
        time.sleep(.05)
    # The seeded compositor fixtures are left visible as registered instruments.
    if short:
        at(3, "Idle desktop / ambient motion")
        at(13, "Workspace 2", ipc("run", "workspace.focus", '{"workspace":2}'))
        at(15, "Workspace 3", ipc("run", "workspace.focus", '{"workspace":3}'))
        at(17, "Deck / Command", ipc("open", "command"))
        starts = [19,21,23,25,27,29]
        for t, number, bay in zip(starts, range(2,8), ["Navigator","Systems","Signal","Routines","AI","Settings"]):
            at(t, f"Ctrl+{number} / {bay}", ctrl(str(number)))
        at(31, "F1 / Help", key("F1"))
        at(33, "Ctrl+1 / Command", ctrl("1"))
        at(33.35, "Tab / Apps scope", key("Tab"))
        at(35.5, "Typing command input", ["wtype", "-k", "Shift_L", "-d", "90", "--", "foot"])
        at(38, "Notification / arrival and expiry", ["python3", "/src/tools/headless/notify_client.py", "--summary", "COUNTERPHASE review", "--body", "Motion capture — notification expiry", "--app", "UI-014", "--wait", "0.1"])
        status("notification-arrived")
        at(43.4, "Notification expired")
        status("notification-expired")
        at(43.5, "Volume / OSD attempt", ipc("run", "audio.volume.set", '{"level":40}'))
        at(45.5, "Brightness / unavailable OSD attempt", ipc("run", "brightness.set", '{"level":65}'))
        at(47.5, "Close Deck / Escape clears query", key("Escape"))
        at(47.75, "Close Deck / Escape", key("Escape"))
        at(48, "Final idle / ambient motion")
    else:
        at(5, "Idle desktop / ambient motion")
        at(18, "Workspace 2", ipc("run", "workspace.focus", '{"workspace":2}'))
        at(22, "Workspace 3", ipc("run", "workspace.focus", '{"workspace":3}'))
        at(26, "Workspace 1", ipc("run", "workspace.focus", '{"workspace":1}'))
        at(30, "Deck / Command", ipc("open", "command"))
        for t, number, bay in zip([34,38,43,47,51,55], range(2,8), ["Navigator","Systems","Signal","Routines","AI","Settings"]):
            at(t, f"Ctrl+{number} / {bay}", ctrl(str(number)))
        at(59, "F1 / Help", key("F1"))
        at(63, "Ctrl+1 / Command", ctrl("1"))
        at(66, "Tab / Apps scope", key("Tab"))
        at(69, "Tab / Windows scope", key("Tab"))
        at(72, "Typing command input", ["wtype", "-k", "Shift_L", "-d", "180", "--", "firefox"])
        at(78, "Clear input / Ctrl+L", ctrl("l"))
        at(80, "Typing command query", ["wtype", "-k", "Shift_L", "-d", "180", "--", "> volume"])
        at(84, "Notification / arrival and expiry", ["python3", "/src/tools/headless/notify_client.py", "--summary", "COUNTERPHASE review", "--body", "Motion capture — notification expiry", "--app", "UI-014", "--wait", "0.1"])
        status("notification-arrived")
        at(90, "Notification expired")
        status("notification-expired")
        at(93, "Volume 40 / OSD attempt", ipc("run", "audio.volume.set", '{"level":40}'))
        at(97, "Volume down / OSD attempt", ipc("run", "audio.volume.down", '{}'))
        at(101, "Brightness / unavailable OSD attempt", ipc("run", "brightness.set", '{"level":65}'))
        at(105, "Close Deck / Escape clears query", key("Escape"))
        at(107, "Close Deck / Escape", key("Escape"))
        at(108, "Final idle / ambient motion")
    status("status-final")
    subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], stdout=(out / "volume-final.txt").open("w"))
    at(duration, "End")
    if qs.poll() is not None: raise RuntimeError("production shell exited during capture")
finally:
    recorder.send_signal(signal.SIGINT)
    recorder.wait(timeout=30)
    if qs is not None:
        qs.terminate()
        qs.wait(timeout=15)
        log_thread.join(timeout=2)
    events_file.close()
    (out / "capture-complete.json").write_text(json.dumps({"recorder_exit": recorder.returncode, "wall_seconds": time.monotonic()-epoch}, indent=2))
