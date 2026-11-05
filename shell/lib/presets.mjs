// Pure, V4-compatible appearance preset codec. Never migrates or silently
// substitutes defaults on import. Config's schema/validator remain authoritative.
import { SCHEMA, defaultsOf, schemaAt, previewAllowed, validateConfig, prepareBatch } from "./config.mjs";
import { PALETTE } from "./tokens.mjs";

export const FORMAT_VERSION = 1;
export const MAX_BYTES = 65536;
export const MAX_PRESETS = 64;
const MAX_DEPTH = 12, MAX_ENTRIES = 1024;
const unsafe = key => ["__proto__", "prototype", "constructor"].indexOf(key) >= 0;
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const copy = value => JSON.parse(JSON.stringify(value));

// Count UTF-8 bytes without TextEncoder (not available in Qt's V4).
function bytes(text) {
  let size = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c < 128) size++;
    else if (c < 2048) size += 2;
    else if (c >= 0xd800 && c <= 0xdbff && i + 1 < text.length && text.charCodeAt(i + 1) >= 0xdc00 && text.charCodeAt(i + 1) <= 0xdfff) { size += 4; i++; }
    else size += 3;
  }
  return size;
}
function parse(text) {
  if (typeof text !== "string" || bytes(text) > MAX_BYTES) return {error: "Preset exceeds " + MAX_BYTES + " bytes"};
  let value;
  try { value = JSON.parse(text); } catch (e) { return {error: "Invalid preset JSON: " + e.message}; }
  let entries = 0;
  function bound(v, depth) {
    if (depth > MAX_DEPTH) return "Preset nesting exceeds " + MAX_DEPTH;
    if (typeof v === "number" && !Number.isFinite(v)) return "Preset numbers must be finite";
    if (typeof v === "string" && v.length > 4096) return "Preset string exceeds 4096 characters";
    if (v && typeof v === "object") {
      for (const key of Object.keys(v)) {
        if (++entries > MAX_ENTRIES) return "Preset has too many entries";
        if (unsafe(key)) return "Forbidden property: " + key;
        if (key.length > 128) return "Preset key exceeds 128 characters";
        const error = bound(v[key], depth + 1);
        if (error) return error;
      }
    }
    return "";
  }
  const error = bound(value, 0);
  return error ? {error: error} : {value: value};
}
export function validateName(name) {
  return typeof name === "string" && name.trim().length > 0 && name.length <= 80 && !/[\x00-\x1f\x7f]/.test(name)
    ? "" : "Preset name must contain 1–80 printable characters";
}

// Leaves are structured arrays: a connector named DP.1 never means DP -> 1.
// Omitted leaves survive; arrays and explicitly empty maps replace as a unit.
export function validate(text) {
  const parsed = parse(text);
  if (parsed.error) return parsed;
  let values = parsed.value, name = "Imported";
  if (!object(values)) return {error: "Preset must be an object"};
  if (Object.prototype.hasOwnProperty.call(values, "formatVersion")) {
    for (const key of Object.keys(values))
      if (["formatVersion", "name", "values"].indexOf(key) < 0) return {error: "Unknown preset key: " + key};
    if (values.formatVersion !== FORMAT_VERSION) return {error: "Unsupported preset formatVersion: " + values.formatVersion};
    name = values.name;
    const error = validateName(name);
    if (error) return {error: error};
    values = values.values;
    if (!object(values)) return {error: "Preset values must be an object"};
  }
  const leaves = [];
  function visit(value, path) {
    if (path.length && ["ai", "routines", "binds", "direction", "startup"].indexOf(path[0]) >= 0)
      return path.join(".") + ": not an appearance setting";
    const schema = path.length ? schemaAt(path) : SCHEMA;
    if (!schema) return "Unknown setting: " + path.join(".");
    if (path.length === 3 && path[0] === "theme" && path[1] === "palette"
        && !Object.prototype.hasOwnProperty.call(PALETTE, path[2]))
      return "Unknown palette role: " + path[2];
    if (path.length === 3 && path[0] === "display" && path[1] === "outputs"
        && (!path[2] || path[2].length > 64 || /[?*\x00-\x1f\x7f]/.test(path[2])))
      return "Output overrides require an exact output name: " + path[2];
    if (schema.type === "object" || schema.type === "map") {
      if (!object(value)) return path.join(".") + ": expected an object";
      const keys = Object.keys(value);
      // Empty non-appearance branches must also be refused.
      if (path.length && !previewAllowed(path) && !keys.length)
        return path.join(".") + ": no appearance leaves supplied";
      if (!keys.length && schema.type === "map") leaves.push({path: path, value: {}});
      for (const key of keys) {
        const error = visit(value[key], path.concat([key]));
        if (error) return error;
      }
      return "";
    }
    if (!previewAllowed(path)) return path.join(".") + ": not an appearance setting";
    leaves.push({path: path, value: copy(value)});
    return "";
  }
  const error = visit(values, []);
  if (error) return {error: error};
  const checked = validateConfig(JSON.stringify(values));
  const issues = checked.errors.concat(checked.warnings);
  if (issues.length) return {error: issues.map(e => e.path + ": " + e.message).join("; ")};
  const batch = prepareBatch({}, leaves, true);
  if (batch.error) return {error: batch.error};
  if (!leaves.length) return {error: "Preset contains no appearance settings"};
  return {preset: {formatVersion: FORMAT_VERSION, name: name, values: copy(values)}, values: leaves};
}

// Portable by default. Include output overrides only with explicit opt-in;
// never include primary/output placement, runtime state or installation data.
export function appearance(config, includeOutputs) {
  function collect(value, path) {
    if (path[0] === "display" && (!includeOutputs || (path.length > 1 && path[1] !== "outputs"))) return undefined;
    const schema = path.length ? schemaAt(path) : SCHEMA;
    if (!schema) return undefined;
    if (schema.type === "object" || schema.type === "map") {
      const out = {};
      const source = value || {};
      const keys = schema.type === "object" ? Object.keys(schema.props) : Object.keys(source);
      for (const key of keys) {
        if (unsafe(key)) continue;
        if (path.length === 2 && path[0] === "theme" && path[1] === "palette"
            && !Object.prototype.hasOwnProperty.call(PALETTE, key)) continue;
        const result = collect(source[key], path.concat([key]));
        if (result !== undefined) out[key] = result;
      }
      return Object.keys(out).length || (schema.type === "map" && previewAllowed(path)) ? out : undefined;
    }
    return previewAllowed(path) && value !== undefined ? copy(value) : undefined;
  }
  return collect(config, []) || {};
}
export function encode(config, name, includeOutputs) {
  const error = validateName(name);
  if (error) return {error: error};
  const preset = {formatVersion: FORMAT_VERSION, name: name.trim(), values: appearance(config, includeOutputs === true)};
  const text = JSON.stringify(preset, null, 2) + "\n";
  const checked = validate(text);
  return checked.error ? checked : {text: text, preset: checked.preset};
}
export function builtins() {
  const defaults = defaultsOf(SCHEMA);
  const readable = copy(defaults);
  readable.theme.density = "comfortable";
  readable.theme.motion = "reduced";
  readable.theme.lowEffects = true;
  return [
    {id: "default", builtin: true, name: "Default", values: appearance(defaults, false)},
    {id: "readable", builtin: true, name: "Readable", values: appearance(readable, false)}
  ];
}
export function readStore(text) {
  const parsed = parse(text);
  if (parsed.error) return parsed;
  const store = parsed.value;
  if (!object(store) || store.formatVersion !== FORMAT_VERSION || !Array.isArray(store.presets))
    return {error: "Invalid presets store or unsupported formatVersion"};
  if (Object.keys(store).some(k => ["formatVersion", "presets"].indexOf(k) < 0)) return {error: "Unknown presets store key"};
  if (store.presets.length > MAX_PRESETS) return {error: "At most " + MAX_PRESETS + " user presets are allowed"};
  const users = [], ids = {};
  for (const entry of store.presets) {
    if (!object(entry) || typeof entry.id !== "string" || !/^user-[a-zA-Z0-9-]{1,80}$/.test(entry.id) || ids[entry.id])
      return {error: "Invalid or duplicate user preset id"};
    if (Object.keys(entry).some(k => ["id", "name", "values"].indexOf(k) < 0)) return {error: "Unknown user preset key"};
    const checked = validate(JSON.stringify({formatVersion: FORMAT_VERSION, name: entry.name, values: entry.values}));
    if (checked.error) return checked;
    ids[entry.id] = true;
    users.push({id: entry.id, name: checked.preset.name, values: checked.preset.values});
  }
  return {presets: users};
}
export function writeStore(users) {
  const text = JSON.stringify({formatVersion: FORMAT_VERSION, presets: users}, null, 2) + "\n";
  const checked = readStore(text);
  return checked.error ? checked : {text: text};
}
