"""Audit only final headless logs and record the production source identity."""
from pathlib import Path
import hashlib
import json
import re

repo = Path(__file__).resolve().parents[4]
build = repo / "build/redesign-2"
out = repo / "docs/design/redesign-2/checks"
runs = ["smoke", "deck", "fullscreen", "direction", "app-links", "before-1920",
        "before-2560", "before-3840", "after-1920", "after-2560", "after-3840", "matrix", "motion"]
pattern = re.compile(r"Error:|Failed to load configuration|Cannot override FINAL|ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign|Error loading QML|is not a type|Cannot assign")
records = []
for run in runs:
    logs = sorted((build / run).glob("qs*.log"))
    assert logs, f"missing logs: {run}"
    for path in logs:
        data = re.sub(r"\x1b\[[0-9;]*m", "", path.read_text(errors="replace"))
        errors = [{"line": i, "text": line} for i, line in enumerate(data.splitlines(), 1) if pattern.search(line)]
        records.append({"path": str(path.relative_to(repo)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "errors": errors})
result = {"logs": len(records), "matched_errors": sum(len(r["errors"]) for r in records), "records": records}
(out / "qml-audit.json").write_text(json.dumps(result, indent=2) + "\n")
sources = {}
for name in ["shell/components/Hatch.qml", "shell/components/InstrumentField.qml"]:
    sources[name] = hashlib.sha256((repo / name).read_bytes()).hexdigest()
deleted = ["shell/components/ShearField.qml", "shell/shaders/bevel.frag", "shell/shaders/bevel.frag.qsb"]
assert not any((repo / name).exists() for name in deleted)
(out / "source-hashes.json").write_text(json.dumps({"sha256": sources, "deleted": deleted}, indent=2) + "\n")
assert not result["matched_errors"], result
print(f"PASS: {len(records)} final QML logs, zero matched errors; production hashes recorded")
