#!/usr/bin/env python3
"""Validate UI-012 payload syntax without loading or installing any app theme.

Run from any directory:
  PYTHONPATH=/tmp/aerolith-ui012-css python3 \
    docs/design/thears-piyti/verification/validate-themes.py

Requires tinycss2 and cssselect2. These may be installed with --target in /tmp;
the script does not install dependencies or change host application profiles.
CSS property-value semantics and real app selector matches require app review.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

try:
    import cssselect2
    import tinycss2
except ImportError as error:
    raise SystemExit(
        "Missing CSS parser: use PYTHONPATH=/tmp/aerolith-ui012-css, or install "
        "tinycss2 and cssselect2 into a temporary dependency directory."
    ) from error


PAYLOAD_ROOTS = ("firefox", "libreoffice", "steam", "discord", "artcraft")
RULE_GROUPS = {
    "media", "supports", "-moz-document", "document", "layer", "container",
    "scope", "starting-style",
}
DECLARATION_GROUPS = {"font-face", "page", "property", "counter-style"}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def location(node):
    return {"line": getattr(node, "source_line", None),
            "column": getattr(node, "source_column", None)}


def validate_css(path):
    errors = []
    metrics = {"style_rules": 0, "declarations": 0, "at_rules": 0}

    def error(message, node):
        errors.append({"message": message, **location(node)})

    def component_errors(values):
        for token in values:
            if token.type == "error":
                error(token.message, token)
            for field in ("content", "arguments"):
                nested = getattr(token, field, None)
                if nested is not None:
                    component_errors(nested)

    def declarations(values):
        for item in tinycss2.parse_declaration_list(
            values, skip_whitespace=True, skip_comments=True
        ):
            if item.type == "error":
                error(item.message, item)
            elif item.type == "declaration":
                metrics["declarations"] += 1
                component_errors(item.value)
            else:
                error("Unexpected nested construct in declaration block", item)

    def rules(items, keyframes=False):
        for item in items:
            if item.type == "error":
                error(item.message, item)
            elif item.type == "qualified-rule":
                metrics["style_rules"] += 1
                component_errors(item.prelude)
                if keyframes:
                    steps = tinycss2.serialize(item.prelude).strip()
                    if not re.fullmatch(
                        r"(?:from|to|\d+(?:\.\d+)?%)(?:\s*,\s*(?:from|to|\d+(?:\.\d+)?%))*",
                        steps,
                    ):
                        error(f"Invalid keyframe selector: {steps}", item)
                else:
                    try:
                        cssselect2.compile_selector_list(item.prelude)
                    except cssselect2.SelectorError as selector_error:
                        error(str(selector_error), item)
                declarations(item.content)
            elif item.type == "at-rule":
                metrics["at_rules"] += 1
                component_errors(item.prelude)
                if item.content is None:
                    continue
                name = item.lower_at_keyword
                if name in RULE_GROUPS or name.endswith("keyframes"):
                    rules(
                        tinycss2.parse_rule_list(
                            item.content, skip_whitespace=True, skip_comments=True
                        ),
                        keyframes=name.endswith("keyframes"),
                    )
                elif name in DECLARATION_GROUPS:
                    declarations(item.content)
                else:
                    error(f"Unsupported block at-rule @{name}; add explicit validation", item)

    text = path.read_text(encoding="utf-8-sig")
    rules(tinycss2.parse_stylesheet(text, skip_whitespace=True, skip_comments=True))
    if path.name.endswith(".theme.css"):
        block = re.search(r"/\*\*(.*?)\*/", text, re.S)
        if block is None:
            errors.append({"message": "Missing Vencord metadata header"})
        else:
            for field in ("name", "author", "version", "description"):
                if not re.search(r"^\s*\*\s+@" + field + r"\s+\S.*$", block[1], re.M):
                    errors.append({"message": f"Missing Vencord @{field} metadata"})
    return errors, metrics


def validate_json(path):
    data = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_object)
    if not isinstance(data, dict):
        raise ValueError("Theme payload must be a JSON object")
    if path.name == "skin.json":
        for field in ("name", "author", "description"):
            if not isinstance(data.get(field), str) or not data[field].strip():
                raise ValueError(f"Millennium manifest needs nonempty {field}")
        if data.get("UseDefaultPatches") is not True:
            raise ValueError("Expected UI-012 Millennium UseDefaultPatches=true")
        if "Patches" in data or "Steam-WebKit" in data:
            raise ValueError("Default patches cannot be combined with custom patch routing")
        for target in ("libraryroot.custom.css", "friends.custom.css", "bigpicture.custom.css"):
            if not (path.parent / target).is_file():
                raise ValueError(f"Missing default patch target: {target}")
    elif path.parent.parent.name == "firefox" and path.name == "manifest.json":
        if data.get("manifest_version") not in (2, 3):
            raise ValueError("Firefox manifest_version must be 2 or 3")
        for field in ("name", "version", "theme"):
            if field not in data:
                raise ValueError(f"Firefox static theme is missing {field}")
        if not isinstance(data["theme"], dict) or not isinstance(data["theme"].get("colors"), dict):
            raise ValueError("Firefox theme.colors must be an object")
    return [], {}


def validate_xml(path):
    root = ET.parse(path).getroot()
    registry = "{http://openoffice.org/2001/registry}"
    manifest = "{http://openoffice.org/2001/manifest}"
    if path.suffix == ".xcu":
        if root.tag != registry + "component-data":
            raise ValueError("XCU root is not oor:component-data")
        for prop in root.iter("prop"):
            if prop.get(registry + "name") == "Color":
                for value in prop.findall("value"):
                    number = int(value.text or "")
                    if not -1 <= number <= 0xFFFFFF:
                        raise ValueError(f"RGB integer outside registry colour range: {number}")
    elif path.parent.name == "META-INF" and path.name == "manifest.xml":
        for entry in root.findall(manifest + "file-entry"):
            payload = entry.get(manifest + "full-path")
            if not payload or not (path.parent.parent / payload).is_file():
                raise ValueError(f"Missing LibreOffice extension payload: {payload}")
    return [], {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--json-output", type=Path,
                        default=Path(__file__).with_name("theme-validation.json"))
    args = parser.parse_args()
    repo = args.repo.resolve()
    files = sorted(
        path for app in PAYLOAD_ROOTS for path in (repo / "themes" / app).rglob("*")
        if path.suffix in {".css", ".json", ".xml", ".xcu"}
    )
    results = []
    totals = {"files": 0, "css": 0, "json": 0, "xml": 0,
              "style_rules": 0, "declarations": 0, "at_rules": 0, "errors": 0}
    for path in files:
        kind = "css" if path.suffix == ".css" else "json" if path.suffix == ".json" else "xml"
        try:
            errors, metrics = {"css": validate_css, "json": validate_json, "xml": validate_xml}[kind](path)
        except (ValueError, ET.ParseError, OSError) as failure:
            errors, metrics = [{"message": str(failure)}], {}
        relative = str(path.relative_to(repo))
        results.append({"file": relative, "kind": kind, "ok": not errors,
                        "errors": errors, **metrics})
        totals["files"] += 1
        totals[kind] += 1
        totals["errors"] += len(errors)
        for key, value in metrics.items():
            totals[key] += value
        print(f"{'PASS' if not errors else 'FAIL'} {relative}")
        for failure in errors:
            print(f"  {failure}")
    if not files:
        totals["errors"] += 1
        print("FAIL: no theme payloads discovered")
    report = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "scope": ["themes/" + app for app in PAYLOAD_ROOTS],
        "parsers": {"tinycss2": tinycss2.__version__, "cssselect2": cssselect2.__version__,
                    "json": "Python standard library", "xml": "Python ElementTree"},
        "limits": [
            "Syntax, selectors, metadata shape and local patch targets only; not real application rendering.",
            "Firefox @-moz-document and nested media are parsed as rule groups.",
            "Existing GTK CSS is outside UI-012 payload scope; GTK @define-color syntax needs GTK validation.",
            "Hyprland Lua/conf were verified separately using native Hyprland --verify-config.",
        ],
        "totals": totals,
        "results": results,
    }
    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(totals, sort_keys=True))
    return int(totals["errors"] != 0)


if __name__ == "__main__":
    sys.exit(main())
