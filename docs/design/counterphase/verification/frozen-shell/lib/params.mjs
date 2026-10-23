// Typed parameter validation shared by commands, routines and AI proposals.
//
// A parameter spec looks like:
//   { name: "level", type: "int", min: 0, max: 150, required: true,
//     description: "Volume in percent" }
// Types: "string", "int", "number", "bool", "enum", "strings".
//   string: maxLength (default 512), pattern (RegExp source, anchored by caller)
//   int / number: min, max
//   enum: choices: [values] or [{ value, label }]
//   strings: a list of strings (e.g. an argv list); maxItems (default 64),
//            maxLength per item (default 4096). Typed input splits on spaces.
// Optional `default` is used when the argument is absent.
//
// Validation never throws for bad input: it returns { ok, values, errors }.
// Errors are { param, message } with messages fit for display.

const NAME = /^[a-z][a-zA-Z0-9_]{0,31}$/;
const TYPES = ["string", "int", "number", "bool", "enum", "strings"];

export function checkSpec(spec) {
  const problems = [];
  if (!spec || typeof spec !== "object") return ["parameter spec must be an object"];
  if (typeof spec.name !== "string" || !NAME.test(spec.name)) problems.push("invalid parameter name " + JSON.stringify(spec.name));
  if (TYPES.indexOf(spec.type) === -1) problems.push("parameter " + spec.name + " has unknown type " + JSON.stringify(spec.type));
  if (spec.type === "enum" && !(Array.isArray(spec.choices) || typeof spec.choices === "function"))
    problems.push("enum parameter " + spec.name + " needs choices");
  return problems;
}

export function choiceValues(spec, ctx) {
  const raw = typeof spec.choices === "function" ? spec.choices(ctx) : spec.choices;
  const list = Array.isArray(raw) ? raw : [];
  return list.map((c) => (c && typeof c === "object" && "value" in c ? c.value : c));
}

export function describeType(spec) {
  switch (spec.type) {
    case "int":
    case "number": {
      const range =
        spec.min !== undefined && spec.max !== undefined
          ? " " + spec.min + "–" + spec.max
          : spec.min !== undefined
            ? " ≥ " + spec.min
            : spec.max !== undefined
              ? " ≤ " + spec.max
              : "";
      return (spec.type === "int" ? "integer" : "number") + range;
    }
    case "bool":
      return "on/off";
    case "strings":
      return "list";
    case "enum":
      return "choice";
    default:
      return "text";
  }
}

function coerce(spec, raw, ctx) {
  switch (spec.type) {
    case "string": {
      if (typeof raw !== "string" && typeof raw !== "number") return { error: "must be text" };
      const s = String(raw);
      const max = spec.maxLength === undefined ? 512 : spec.maxLength;
      if (s.length > max) return { error: "must be at most " + max + " characters" };
      if (spec.minLength !== undefined && s.length < spec.minLength)
        return { error: "must be at least " + spec.minLength + " characters" };
      if (spec.pattern !== undefined && !new RegExp("^(?:" + spec.pattern + ")$").test(s))
        return { error: spec.patternHint || "has an invalid format" };
      return { value: s };
    }
    case "int":
    case "number": {
      let n;
      if (typeof raw === "number") n = raw;
      else if (typeof raw === "string" && /^[+-]?(\d+(\.\d+)?|\.\d+)%?$/.test(raw.trim())) n = Number(raw.trim().replace(/%$/, ""));
      else return { error: "must be a number" };
      if (!Number.isFinite(n)) return { error: "must be a finite number" };
      if (spec.type === "int" && !Number.isInteger(n)) return { error: "must be a whole number" };
      if (spec.min !== undefined && n < spec.min) return { error: "must be at least " + spec.min };
      if (spec.max !== undefined && n > spec.max) return { error: "must be at most " + spec.max };
      return { value: n };
    }
    case "bool": {
      if (typeof raw === "boolean") return { value: raw };
      const s = String(raw).trim().toLowerCase();
      if (["true", "on", "yes", "1", "enable", "enabled"].indexOf(s) !== -1) return { value: true };
      if (["false", "off", "no", "0", "disable", "disabled"].indexOf(s) !== -1) return { value: false };
      return { error: "must be on or off" };
    }
    case "strings": {
      let list = raw;
      if (typeof raw === "string") list = raw.trim().split(/\s+/).filter((w) => w.length > 0);
      if (!Array.isArray(list)) return { error: "must be a list of text values" };
      const maxItems = spec.maxItems === undefined ? 64 : spec.maxItems;
      const maxLen = spec.maxLength === undefined ? 4096 : spec.maxLength;
      if (list.length === 0) return { error: "must not be empty" };
      if (list.length > maxItems) return { error: "must have at most " + maxItems + " entries" };
      for (let i = 0; i < list.length; i++) {
        if (typeof list[i] !== "string") return { error: "entry " + (i + 1) + " must be text" };
        if (list[i].length > maxLen) return { error: "entry " + (i + 1) + " is too long" };
        if (list[i].indexOf("\u0000") !== -1) return { error: "entry " + (i + 1) + " contains a NUL byte" };
      }
      return { value: list.slice() };
    }
    case "enum": {
      const values = choiceValues(spec, ctx);
      for (let i = 0; i < values.length; i++) if (values[i] === raw) return { value: values[i] };
      // Case-insensitive match for typed input.
      const s = String(raw).toLowerCase();
      for (let i = 0; i < values.length; i++) if (String(values[i]).toLowerCase() === s) return { value: values[i] };
      return { error: "must be one of: " + values.slice(0, 8).join(", ") + (values.length > 8 ? ", …" : "") };
    }
  }
  return { error: "has an unsupported type" };
}

// Validate an argument object against a list of parameter specs.
// Unknown argument names are rejected: a typo should not silently do nothing.
export function validateArgs(specs, args, ctx) {
  const list = specs || [];
  const input = args && typeof args === "object" ? args : {};
  const values = {};
  const errors = [];
  const known = {};
  for (let i = 0; i < list.length; i++) known[list[i].name] = true;
  for (const k in input) {
    if (Object.prototype.hasOwnProperty.call(input, k) && !known[k]) errors.push({ param: k, message: "unknown parameter" });
  }
  for (let i = 0; i < list.length; i++) {
    const spec = list[i];
    const present = Object.prototype.hasOwnProperty.call(input, spec.name) && input[spec.name] !== undefined && input[spec.name] !== null && input[spec.name] !== "";
    if (!present) {
      if (spec.default !== undefined) values[spec.name] = spec.default;
      else if (spec.required) errors.push({ param: spec.name, message: "is required" });
      continue;
    }
    const r = coerce(spec, input[spec.name], ctx);
    if (r.error) errors.push({ param: spec.name, message: r.error });
    else values[spec.name] = r.value;
  }
  return { ok: errors.length === 0, values: values, errors: errors };
}

// Map positional words typed after a command alias onto parameter names.
// The last parameter of type string absorbs any remaining words.
export function positionalArgs(specs, words) {
  const list = specs || [];
  const out = {};
  let wi = 0;
  for (let i = 0; i < list.length && wi < words.length; i++) {
    const spec = list[i];
    if (spec.type === "strings" && i === list.length - 1) {
      out[spec.name] = words.slice(wi);
      wi = words.length;
    } else if (spec.type === "string" && i === list.length - 1) {
      out[spec.name] = words.slice(wi).join(" ");
      wi = words.length;
    } else {
      out[spec.name] = words[wi++];
    }
  }
  return { args: out, extra: words.slice(wi) };
}

export function formatErrors(errors) {
  return (errors || []).map((e) => e.param + " " + e.message).join("; ");
}
