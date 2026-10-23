#!/usr/bin/env python3
"""Record QML runtime-error evidence from UI-013 retained logs."""
import argparse
import json
from pathlib import Path
import re

base = Path(__file__).resolve().parents[1] / "verification"
parser = argparse.ArgumentParser()
parser.add_argument("--round", choices=["initial", "final"], default="final")
args = parser.parse_args()
area = "final-runs" if args.round == "final" else "runs"
pattern = re.compile(r"TypeError|ReferenceError|SyntaxError|Unable to assign|Cannot assign|Binding loop|is not a type|Error loading|Failed to load QML|Cannot animate|Invalid property|non-existent property|Cannot read property|Failed to create.*component|Segmentation fault|Aborted|ASSERT failure", re.I)
records = []
for path in sorted((base / area).glob("*/qs.txt")):
    lines = path.read_text(errors="replace").splitlines()
    records.append({"log": str(path.relative_to(base)), "lines": len(lines), "source_reloads": sum("Reloading configuration" in line for line in lines), "matches": [{"line": i+1, "text": line} for i, line in enumerate(lines) if pattern.search(line)]})
result = {"round": args.round, "pattern": pattern.pattern, "logs": len(records), "matches": sum(len(r["matches"]) for r in records), "records": records}
(base / ("initial-log-audit.json" if args.round == "initial" else "log-audit.json")).write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
raise SystemExit(1 if result["matches"] else 0)
