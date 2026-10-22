#!/usr/bin/env python3
"""Regenerate the command reference in docs/COMMANDS.md.

Input is the catalogue the running shell reports over IPC
(`qs -p shell ipc call aerolith commands`). The headless scenario
tests/scenarios/catalogue.sh writes it with the AI module present:

    AI=1 tools/headless/run.sh tests/scenarios/catalogue.sh
    python3 tools/gen-commands-doc.py build/headless/catalogue/commands.json

Only the text between the GENERATED markers is replaced.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

BEGIN = "<!-- BEGIN GENERATED: tools/gen-commands-doc.py -->"
END = "<!-- END GENERATED -->"
DOC = Path(__file__).resolve().parent.parent / "docs" / "COMMANDS.md"
ORDER = ["shell", "apps", "windows", "workspaces", "audio", "media", "routines", "system", "settings", "ai"]


def ptype(p: dict) -> str:
    t = p["type"]
    if t in ("int", "number"):
        lo, hi = p.get("min"), p.get("max")
        rng = f" {lo}–{hi}" if lo is not None and hi is not None else (f" ≥ {lo}" if lo is not None else "")
        return ("integer" if t == "int" else "number") + rng
    if t == "enum":
        ch = p.get("choices")
        return "one of " + ", ".join(f"`{c}`" for c in ch) if isinstance(ch, list) else "one of the current choices"
    if t == "strings":
        return "list of strings"
    return t


def params(c: dict) -> str:
    if not c["params"]:
        return "—"
    out = []
    for p in c["params"]:
        s = f"`{p['name']}`: {ptype(p)}"
        if not p["required"]:
            s += f" (optional, default `{json.dumps(p['default'])}`)"
        out.append(s)
    return "<br>".join(out)


def flags(c: dict) -> str:
    f = []
    if c["sensitive"]:
        f.append("asks for confirmation")
    if c["routine"]:
        f.append("routine step")
    if c["routine"] and c["aiAllowed"]:
        f.append("AI may propose")
    if c["source"] != "core":
        f.append(f"from `{c['source']}` module")
    return ", ".join(f) or "—"


def render(cat: list[dict]) -> str:
    out = [BEGIN, "", f"{len(cat)} commands with the AI module installed; without it the `ai` category is absent.", ""]
    cats = sorted({c["category"] for c in cat}, key=lambda k: (ORDER.index(k) if k in ORDER else 99, k))
    for k in cats:
        out += [f"### {k}", "", "| Command | Alias | Parameters | Notes |", "|---|---|---|---|"]
        for c in sorted((c for c in cat if c["category"] == k), key=lambda c: c["id"]):
            alias = f"`{c['alias']}`" if c["alias"] else "—"
            title = c["title"] + (f" — {c['description']}" if c["description"] else "")
            out.append(f"| `{c['id']}`<br>{title.replace('|', '/')} | {alias} | {params(c)} | {flags(c)} |")
        out.append("")
    out.append(END)
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    cat = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    text = DOC.read_text(encoding="utf-8")
    a, b = text.index(BEGIN), text.index(END)
    DOC.write_text(text[:a] + render(cat) + text[b + len(END) :], encoding="utf-8")
    print(f"wrote {DOC}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
