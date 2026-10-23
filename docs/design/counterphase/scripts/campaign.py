#!/usr/bin/env python3
"""Run the UI-013 visual matrix with at most two headless containers."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
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
for intensity in ("saturated", "insane"):
    jobs.append(["scenario", "--intensity", intensity, "--scenario", "smoke", "--direction", "piyti"])

def work(job):
    return subprocess.call(["python3", str(here / "verify.py"), "--round", "final"] + job)

with ThreadPoolExecutor(max_workers=2) as pool:
    codes = list(pool.map(work, jobs))
raise SystemExit(1 if any(codes) else 0)
