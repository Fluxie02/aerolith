#!/usr/bin/env python3
"""Run the UI-013 visual matrix with at most two headless containers."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import subprocess

here = Path(__file__).resolve().parent
jobs = []
# Compact first: this is the geometry corrected after the independent review.
for intensity in ("saturated", "insane"):
    for profile in ("compact-reduced", "compact-lowEffects", "compact-off"):
        jobs.append(["capture", "--intensity", intensity, "--profile", profile])
for intensity in ("saturated", "insane"):
    for profile in ("4k-scale2", "4k-scale1.5", "4k-scale1"):
        jobs.append(["capture", "--intensity", intensity, "--profile", profile])
for intensity in ("saturated", "insane"):
    for scenario in ("smoke", "full", "deck", "ai"):
        job = ["scenario", "--intensity", intensity, "--scenario", scenario]
        if scenario == "deck":
            job += ["--deck-native-output"]
        jobs.append(job)
# Preserve THEARS compatibility without developing its visuals further.
for intensity in ("saturated", "insane"):
    for scenario in ("smoke", "full", "deck", "ai"):
        job = ["scenario", "--intensity", intensity, "--scenario", scenario, "--direction", "thears"]
        if scenario == "deck":
            job += ["--deck-native-output"]
        jobs.append(job)

def work(job):
    # Resume from saved, completed results; interrupted empty logs are rerun.
    intensity = job[job.index("--intensity") + 1]
    direction = job[job.index("--direction") + 1] if "--direction" in job else "piyti"
    if job[0] == "scenario":
        name = job[job.index("--scenario") + 1]
        suffix = "-native-output" if "--deck-native-output" in job else ""
    else:
        name = job[job.index("--profile") + 1]
        suffix = ("-uiScale1.5" if name == "4k-scale1" else "-uiScale1") if name.startswith("4k-") else ""
    label = ("piyti-" if direction == "piyti" else "") + intensity + "-" + name + suffix
    record = here.parent / "verification/final-runs" / (label + ".result.json")
    if record.exists() and json.loads(record.read_text())["exit_code"] == 0:
        print("Already passed:", label, flush=True)
        return 0
    return subprocess.call(["python3", str(here / "verify.py"), "--round", "final"] + job)

with ThreadPoolExecutor(max_workers=2) as pool:
    codes = list(pool.map(work, jobs))
raise SystemExit(1 if any(codes) else 0)
