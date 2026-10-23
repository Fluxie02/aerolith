#!/usr/bin/env python3
"""UI-013 reproducible checks; production shell and harness stay read-only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

REPO = Path(__file__).resolve().parents[4]
BASE = REPO / "docs/design/counterphase/verification"
RUN_AREA = BASE / "runs"
ROUND = "initial"

def run(name, argv, *, env=None, folder="runs"):
    if ROUND == "final":
        folder = {"runs": "final-runs", "unit": "unit-final"}.get(folder, folder)
    area = BASE / folder
    area.mkdir(parents=True, exist_ok=True)
    log = area / (name + ".stdout.txt")
    start = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(argv, cwd=REPO, env=env, stdout=stream, stderr=subprocess.STDOUT)
    record = {"name": name, "command": argv, "environment": {k:env[k] for k in ("SHELL_PATH", "CONFIG", "ROUTINES", "AUDIO", "MEDIA", "AI", "MPV_AO", "RES", "SCALE", "HYPR_MOCK_ARGS") if env and k in env}, "exit_code": result.returncode, "elapsed_seconds": round(time.monotonic()-start, 2), "stdout": str(log.relative_to(REPO))}
    source_manifest = BASE / ("piyti-source-hashes.json" if env and env.get("SHELL_PATH", "").endswith("piyti-shell") else "source-hashes.json")
    if env and env.get("SHELL_PATH") and source_manifest.exists():
        record["source_manifest_sha256"] = hashlib.sha256(source_manifest.read_bytes()).hexdigest()
    if folder in ("runs", "final-runs"):
        # *.log is ignored by the repository. Keep reviewable text copies.
        run_dir = Path(argv[-1])
        for source in run_dir.glob("*.log"):
            shutil.copy2(source, source.with_suffix(".txt"))
    (area / (name + ".result.json")).write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    return result.returncode

def units():
    commands = [
        ("node", ["node", "tests/js/run-node.mjs"]),
        ("qt-v4", ["docker", "run", "--rm", "-v", str(REPO)+":/src:ro", "aerolith-dev", "bash", "-c", "cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml"]),
        ("pytest", ["python3", "-m", "pytest", "-q", "tests/py"]),
    ]
    codes = [run(name, cmd, folder="unit") for name, cmd in commands]
    return int(any(codes))

def config(intensity, motion="full", scale=1, low=False):
    path = BASE / "configs" / (f"{intensity}-{motion}-scale{scale}" + ("-low" if low else "") + ".json")
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps({"schemaVersion": 1, "theme": {"intensity": intensity, "motion": motion, "uiScale": scale, "lowEffects": low}}) + "\n"
    if not path.exists() or path.read_text() != content:
        path.write_text(content)
    return path

def scenario(intensity, name, native_output=False, direction="thears"):
    # A resumed coordinator can finish in-flight containers before replacing
    # read-only snapshots. No production file is ever edited by this harness.
    while (BASE / "snapshot-refresh.pending").exists():
        time.sleep(0.2)
    env = os.environ.copy()
    snapshot = BASE / ("piyti-shell" if direction == "piyti" else "frozen-shell")
    if not snapshot.exists():
        raise SystemExit(f"Missing {snapshot.name}; run verify.py freeze --direction {direction} first")
    env["SHELL_PATH"] = str(snapshot.relative_to(REPO))
    env["CONFIG"] = str(config(intensity))
    if name == "full":
        env.update(AUDIO="1", MEDIA="1", MPV_AO="pipewire", ROUTINES=str(BASE / "configs/valid-routines.json"))
    elif name == "ai":
        env.update(AI="1", AUDIO="1")
    elif name == "deck":
        env.update(AUDIO="1", HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1", RES="1440x2560", SCALE="1.5")
        if native_output:
            env.update(RES="1920x1080", SCALE="1")
    label = ("piyti-" if direction == "piyti" else "") + f"{intensity}-{name}" + ("-native-output" if native_output else "")
    return run(label, ["bash", "tools/headless/run.sh", "tests/scenarios/"+name+".sh", str(RUN_AREA / label)], env=env)

def capture(intensity, profile, direction="piyti", stability=False):
    env = os.environ.copy()
    snapshot = BASE / ("piyti-shell" if direction == "piyti" else "frozen-shell")
    if not snapshot.exists():
        raise SystemExit(f"Missing {snapshot.name}; run verify.py freeze --direction {direction} first")
    env["SHELL_PATH"] = str(snapshot.relative_to(REPO))
    motion = "full"
    low = False
    ui_scale = 1.5
    if profile.startswith("compact-"):
        mode = profile.removeprefix("compact-")
        motion = mode if mode in ("off", "reduced") else "full"
        low = mode == "lowEffects"
        env.update(RES="1280x720", SCALE="1", HYPR_MOCK_ARGS="--mode 1280x720 --scale 1")
    else:
        output_scale = profile.removeprefix("4k-scale")
        ui_scale = 1.5 if output_scale == "1" else 1
        env.update(RES="3840x2160", SCALE=output_scale, HYPR_MOCK_ARGS="--mode 3840x2160 --scale " + output_scale)
    env["CONFIG"] = str(config(intensity, motion, ui_scale, low))
    env["ROUTINES"] = str(BASE / "configs/valid-routines.json")
    label = ("piyti-" if direction == "piyti" else "") + intensity + "-" + profile + ("-uiScale" + str(ui_scale) if profile.startswith("4k-") else "")
    script = "capture-4k.sh" if ROUND == "final" and profile.startswith("4k-") else "capture.sh"
    if stability:
        script = "capture-4k-stability.sh"
    return run(label, ["bash", "tools/headless/run.sh", "docs/design/counterphase/scripts/"+script, str(RUN_AREA / label)], env=env)

parser = argparse.ArgumentParser()
parser.add_argument("kind", choices=["unit", "scenario", "capture", "configs", "freeze"])
parser.add_argument("--intensity", choices=["saturated", "insane"], default="saturated")
parser.add_argument("--scenario", choices=["smoke", "full", "deck", "ai"], default="smoke")
parser.add_argument("--deck-native-output", action="store_true")
parser.add_argument("--round", choices=["initial", "final"], default="initial")
parser.add_argument("--direction", choices=["thears", "piyti"], default="piyti")
parser.add_argument("--stability-capture", action="store_true")
parser.add_argument("--profile", choices=["compact-off", "compact-reduced", "compact-lowEffects", "4k-scale2", "4k-scale1.5", "4k-scale1"], default="compact-off")
args = parser.parse_args()
ROUND = args.round
RUN_AREA = BASE / ("final-runs" if ROUND == "final" else "runs")
if args.kind == "unit":
    raise SystemExit(units())
if args.kind == "freeze":
    target = BASE / ("piyti-shell" if args.direction == "piyti" else "frozen-shell")
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(REPO / "shell", target)
    if args.direction == "piyti":
        theme = target / "core/Theme.qml"
        source = theme.read_text()
        original = 'property string applicationDirection: "thears"'
        assert source.count(original) == 1
        theme.write_text(source.replace(original, 'property string applicationDirection: "piyti"'))
    hashes = {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob("*")) if p.is_file()}
    name = "piyti-source-hashes.json" if args.direction == "piyti" else "source-hashes.json"
    (BASE / name).write_text(json.dumps(hashes, indent=2) + "\n")
    print(f"Frozen {len(hashes)} shell files; source-hashes.json retained.")
    raise SystemExit(0)
if args.kind == "configs":
    for i in ("saturated", "insane"):
        for m in ("full", "reduced", "off"):
            for s in (1, 1.5):
                config(i,m,s)
        config(i,low=True)
    source = json.loads((REPO / "tests/fixtures/routines.json").read_text())
    source["routines"] = [r for r in source["routines"] if r["id"] != "broken-example"]
    (BASE / "configs/valid-routines.json").write_text(json.dumps(source, indent=2) + "\n")
elif args.kind == "capture":
    raise SystemExit(capture(args.intensity, args.profile, args.direction, args.stability_capture))
else:
    raise SystemExit(scenario(args.intensity, args.scenario, args.deck_native_output, args.direction))
