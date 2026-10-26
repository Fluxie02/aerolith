"""Host launcher; invokes the existing session harness without editing it."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

repo = Path(__file__).resolve().parents[4]
base = Path(__file__).resolve().parent
profile = sys.argv[1]
assert profile in ["piyti-saturated", "piyti-insane", "thears-saturated"]
run = base / profile
run.mkdir(exist_ok=True)
os.chmod(run, 0o777)
assert not (run / "raw.mkv").exists(), "Use a new output directory; never overwrite captures silently"
config = {"schemaVersion": 1, "theme": {"intensity": profile.split("-")[1], "motion": "full", "lowEffects": False}, "notifications": {"server": True, "popupTimeoutMs": 5000}}
(run / "fixture-config.json").write_text(json.dumps(config, indent=2)+"\n")
source = "build/counterphase-piyti-motion-shell" if profile.startswith("piyti") else "shell"
hashes = {}
for folder in ["shell", source, "ai-bridge/qml", "tools/headless", "tools/mock-hyprland"]:
    for path in sorted((repo / folder).rglob("*")):
        if path.is_file() and "__pycache__" not in str(path):
            hashes[str(path.relative_to(repo))] = hashlib.sha256(path.read_bytes()).hexdigest()
(run / "source-hashes.json").write_text(json.dumps(hashes, indent=2)+"\n")
command = ["docker", "run", "--rm", "--cap-add=SYS_NICE", "--name", "ui014-"+profile,
    "-v", f"{repo}:/src:ro", "-v", f"{run}:/out",
    "-v", "/tmp/ui014-recorder:/capture-tools:ro",
    "-v", f"{run / 'fixture-config.json'}:/seed/config.json:ro",
    "-v", f"{repo / 'tests/fixtures/routines.json'}:/seed/routines.json:ro",
    "-e", "UI014_SHORT="+str(int(profile.startswith("thears"))),
    "-e", "SHELL_PATH="+source, "-e", "AUDIO=1", "-e", "MEDIA=1", "-e", "AI=1", "-e", "MPV_AO=pipewire",
    "aerolith-dev", "bash", "-c", """
set -e
id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
mkdir -p /run/user/1000 /home/pilot/.config/aerolith
chown pilot /run/user/1000
chmod 700 /run/user/1000
cp /seed/config.json /home/pilot/.config/aerolith/config.json
cp /seed/routines.json /home/pilot/.config/aerolith/routines.json
chown -R pilot /home/pilot
exec su pilot -c 'bash /src/tools/headless/session.sh /src/docs/design/counterphase/recordings/record.sh'
"""]
(run / "command.json").write_text(json.dumps(command, indent=2)+"\n")
with (run / "harness.log").open("w") as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
print(profile, "exit", result.returncode, flush=True)
raise SystemExit(result.returncode)
