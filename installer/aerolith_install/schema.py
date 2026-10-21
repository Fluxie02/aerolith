"""Validate config.json against shell/schema/config.schema.json.

The schema is generated from shell/lib/config.mjs (the shell's own
validator), so this module only implements the JSON Schema keywords that
generator emits: type, enum, minimum, maximum, maxLength, pattern,
properties, additionalProperties, items, maxItems. Unknown keys are reported
as warnings, matching the shell's behaviour of keeping them.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

_TYPES = {
    "object": dict,
    "array": list,
    "string": str,
    "boolean": bool,
}


def _type_ok(expected: str, value: Any) -> bool:
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    t = _TYPES.get(expected)
    return isinstance(value, t) if t else True


def validate(value: Any, schema: dict[str, Any], path: str = "") -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    where = path or "(root)"
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{where}: must be one of {', '.join(map(str, schema['enum']))}")
        return errors, warnings
    t = schema.get("type")
    if t and not _type_ok(t, value):
        errors.append(f"{where}: expected {t}, got {type(value).__name__}")
        return errors, warnings
    if t in ("integer", "number"):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{where}: must be at least {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{where}: must be at most {schema['maximum']}")
    if t == "string":
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{where}: longer than {schema['maxLength']} characters")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{where}: does not match {schema['pattern']}")
    if t == "array":
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{where}: more than {schema['maxItems']} entries")
        for i, item in enumerate(value):
            e, w = validate(item, schema.get("items", {}), f"{path}[{i}]")
            errors += e
            warnings += w
    if t == "object":
        props = schema.get("properties")
        extra = schema.get("additionalProperties")
        for k, v in value.items():
            sub = f"{path}.{k}" if path else k
            if props is not None and k in props:
                e, w = validate(v, props[k], sub)
            elif isinstance(extra, dict):
                e, w = validate(v, extra, sub)
            else:
                e, w = [], [f"{sub}: unknown setting (kept, but has no effect)"] if props is not None else []
            errors += e
            warnings += w
    return errors, warnings


def validate_file(config: Path, schema_path: Path) -> tuple[list[str], list[str]]:
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    try:
        data = json.loads(config.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return [], [f"{config} does not exist; AEROLITH runs with defaults"]
    except json.JSONDecodeError as exc:
        return [f"{config}: invalid JSON: {exc.msg} at line {exc.lineno}, column {exc.colno}"], []
    return validate(data, schema)
