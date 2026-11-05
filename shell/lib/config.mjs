// AEROLITH core configuration: schema, validation, defaults and migration.
//
// The schema below is the single source of truth. It drives:
//   - runtime validation in the shell (validateConfig),
//   - the defaults the shell runs with,
//   - schema/config.schema.json for editor completion (tools/gen-schema.mjs).
//
// Validation is forgiving by design: an invalid value is reported and replaced
// by its default, so a typo degrades one setting instead of the whole shell.
// Unknown keys are preserved in the returned object (so a writer keeps them)
// and reported as warnings.
//
// AI settings are deliberately NOT here. They live in ai.json, owned by the
// optional AI Bridge, so removing AI never touches this file.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

import { OLED_DEFAULTS } from "./tokens.mjs";

export const SCHEMA_VERSION = 1;

const S = {
  bool: (def, description) => ({ type: "bool", default: def, description: description }),
  int: (def, min, max, description) => ({ type: "int", default: def, min: min, max: max, description: description }),
  num: (def, min, max, description) => ({ type: "number", default: def, min: min, max: max, description: description }),
  str: (def, maxLength, description) => ({ type: "string", default: def, maxLength: maxLength, description: description }),
  enumOf: (def, values, description) => ({ type: "enum", default: def, values: values, description: description }),
  obj: (props, description) => ({ type: "object", props: props, description: description }),
};

export const SCHEMA = S.obj(
  {
    schemaVersion: S.int(SCHEMA_VERSION, 1, 1000, "Configuration schema version. Written by AEROLITH; do not change by hand."),
    display: S.obj(
      {
        primary: S.str("", 64, "Primary output name. Empty or unavailable: deprecated output alias, then lowest Hyprland id, then first screen. Applies live."),
        output: Object.assign(S.str("", 64, "Deprecated alias for display.primary (one release). Used when primary is empty or unavailable."), { hidden: true, deprecated: true }),
        outputs: {
          type: "map",
          values: S.obj({
            strip: S.bool(true, "Enable the Flight Strip on this output (also requires strip.visible)."),
            ground: S.bool(true, "Enable Ground on this output (also requires ground.enabled)."),
            profile: S.enumOf("standard", ["standard", "oled"], "Display profile: standard preserves the theme; oled uses black fills and display.oled idle protection. Applies live."),
          }, "Per-output settings."),
          default: {},
          description: "Settings by output name: strip/ground default true, profile standard or oled (default standard). Disconnected or renamed entries are retained and ignored; new names use defaults.",
        },
        oled: Object.assign(S.obj({
          idleDimAfter: S.int(300, 0, 86400, "Seconds without activity before dimming shell surfaces on OLED outputs. 0 disables idle protection. Respects idle inhibitors."),
          idleDimLevel: S.num(OLED_DEFAULTS.idleDimLevel, 0, 1, "Shell surface opacity when idle, on OLED outputs only."),
          hideDecorationWhenIdle: S.bool(true, "Hide static decorative geometry while OLED shell surfaces are idle-dimmed."),
        }, "Protection for outputs whose profile is oled; standard outputs are unaffected. idleDimAfter is idle seconds (0 disables); idleDimLevel is surface opacity (0–1); hideDecorationWhenIdle hides static geometry. No display brightness changes or pixel shifting."), { default: { idleDimAfter: 300, idleDimLevel: OLED_DEFAULTS.idleDimLevel, hideDecorationWhenIdle: true } }),
        overlayOn: S.enumOf("focused", ["focused", "primary"], "Output for Deck, OSD and session menu. Missing focus falls back to primary."),
        noticesOn: S.str("primary", 64, "Output for notices: primary, focused, or an output name. Missing names fall back to primary."),
        warnOnMultipleDisplays: Object.assign(S.bool(true, "Retired; accepted for compatibility and ignored. All enabled outputs get surfaces."), { hidden: true, deprecated: true }),
      },
      "Multi-monitor placement. Ground and Strip run on every enabled output; global services remain singletons.",
    ),
    theme: S.obj(
      {
        scheme: S.enumOf("limb", ["limb", "bathyal", "corona", "cinder", "ferrite", "iris", "argent", "lichen", "helios", "umbra", "vellum", "glacial"], "Colour spectrum. Choose in Settings; applies live. Palette overrides take precedence."),
        density: S.enumOf("standard", ["compact", "standard", "comfortable"], "Spacing and type scale."),
        uiScale: S.num(1.0, 0.75, 2.0, "Multiplier applied on top of the compositor's own scaling."),
        motion: S.enumOf("full", ["full", "reduced", "off"], "Animation level. 'off' disables all transitions."),
        intensity: S.enumOf("saturated", ["saturated", "insane"], "How much the interface shows: 'saturated' or the even denser 'insane'. Switch with `aerolith intensity`."),
        lowEffects: S.bool(false, "Opaque backdrops and no shadows, for slow GPUs or screen recording."),
        fontSans: S.str("Inter", 128, "Interface font family."),
        fontMono: S.str("JetBrains Mono", 128, "Monospaced font for commands and telemetry."),
        palette: {
          type: "map",
          values: { type: "color" },
          default: {},
          description: "Colour overrides. Keys: obsidian, surface, surface2, grid, text, textDim, signal, caution, critical, nominal.",
        },
      },
      "AEROLITH Instrument System appearance.",
    ),
    strip: S.obj(
      {
        visible: S.bool(true, "Show the Flight Strip."),
        edge: S.enumOf("top", ["top", "bottom"], "Screen edge for the Flight Strip."),
        showWindowTitle: S.bool(true, "Show the focused window title."),
        telemetry: S.enumOf("alert", ["off", "alert", "always"], "CPU/memory readouts: never, only when above thresholds, or always."),
        clock: S.enumOf("24h", ["24h", "12h"], "Clock format."),
        showDate: S.bool(true, "Show the date next to the clock."),
        showSeconds: S.bool(false, "Show seconds. Costs one redraw per second."),
        workspaceCount: S.int(5, 1, 20, "Minimum number of workspace cells shown on the workspace tape."),
      },
      "The edge-mounted status strip.",
    ),
    ground: S.obj(
      {
        enabled: S.bool(true, "Draw AEROLITH's own desktop background behind all windows. Turn off to keep a wallpaper from another program such as hyprpaper or swaybg."),
      },
      "The desktop background surface.",
    ),
    welcome: S.obj({
      showOnStartup: S.bool(false, "Show Welcome on every shell start. Fresh installs show it once regardless; this does not enable shell autostart."),
    }, "Welcome startup preference."),
    tour: S.obj(
      {
        enabled: S.bool(true, "Show the first-run tour on the primary output. Completion is saved in shell state, separately from this config."),
      },
      "First-run tour.",
    ),
    commandCore: S.obj(
      {
        maxResults: S.int(40, 5, 200, "Maximum results listed."),
        historySize: S.int(100, 0, 1000, "Executed actions kept in history."),
        terminal: {
          type: "array",
          items: { type: "string", maxLength: 256 },
          default: [],
          maxItems: 16,
          description: "Terminal command used for Terminal=true applications, e.g. [\"foot\"] or [\"kitty\", \"-e\"]. Empty: detect.",
        },
        launchPrefix: {
          type: "array",
          items: { type: "string", maxLength: 256 },
          default: [],
          maxItems: 16,
          description: "Command prefix for launching apps, e.g. [\"uwsm\", \"app\", \"--\"].",
        },
      },
      "The universal command palette.",
    ),
    telemetry: S.obj(
      {
        stripIntervalMs: S.int(5000, 1000, 60000, "Sampling interval while only the Flight Strip needs data."),
        panelIntervalMs: S.int(2000, 500, 60000, "Sampling interval while the Systems Bay is open."),
        detailIntervalMs: S.int(1000, 250, 60000, "Sampling interval for the detailed process view."),
        historySamples: S.int(120, 10, 3600, "Samples kept for graphs (bounded memory)."),
        gpu: S.enumOf("auto", ["auto", "amd", "intel", "nvidia", "off"], "GPU telemetry source."),
        performanceMode: S.bool(false, "Halve sampling rates everywhere (useful while gaming)."),
        cpuCautionPercent: S.int(85, 1, 100, "CPU percentage that raises a caution."),
        memoryCautionPercent: S.int(90, 1, 100, "Memory percentage that raises a caution."),
        temperatureCautionC: S.int(85, 30, 120, "Temperature that raises a caution."),
        temperatureCriticalC: S.int(95, 30, 130, "Temperature that raises a critical alert."),
      },
      "Systems Bay sampling. Nothing is sampled while no view needs the data.",
    ),
    audio: S.obj(
      {
        volumeStep: S.int(5, 1, 25, "Volume change per step, in percent."),
        maxVolume: S.int(100, 100, 150, "Upper volume limit in percent. Above 100 amplifies."),
        showStreams: S.bool(true, "List per-application streams in the Signal Rack."),
      },
      "Signal Rack audio behaviour.",
    ),
    lock: S.obj(
      {
        enabled: S.bool(false, "Lock with AEROLITH's own lock screen (Wayland session lock and PAM). Off: the lock command asks logind, for a locker such as hyprlock."),
      },
      "Session lock.",
    ),
    navigator: S.obj(
      {
        thumbnails: S.bool(false, "Live window thumbnails (uses hyprland-toplevel-export; costs GPU memory)."),
        showEmptyWorkspaces: S.bool(true, "Show empty workspaces up to strip.workspaceCount."),
      },
      "Spatial Navigator overview.",
    ),
    routines: S.obj(
      {
        allowCommandSteps: S.bool(false, "Allow routines to run programs with 'shell.exec' steps (argument list, no shell). Each run still asks for confirmation."),
      },
      "Routine engine safety settings. Routines themselves live in routines.json.",
    ),
    notifications: S.obj(
      {
        server: S.bool(false, "Act as the desktop notification server. Leave off if mako, dunst or swaync is running."),
        doNotDisturb: S.bool(false, "Suppress notification popups (they are still counted)."),
        popupTimeoutMs: S.int(6000, 1000, 60000, "How long popups stay visible."),
      },
      "Optional built-in notification server.",
    ),
    logging: S.obj(
      {
        level: S.enumOf("info", ["debug", "info", "warn", "error"], "Minimum level written to the Quickshell log."),
      },
      "Diagnostics.",
    ),
  },
  "AEROLITH core configuration.",
);

function typeName(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v;
}

function clone(v) {
  return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

export function defaultsOf(schema) {
  if (schema.type === "object") {
    const out = {};
    for (const k in schema.props) out[k] = defaultsOf(schema.props[k]);
    return out;
  }
  return clone(schema.default);
}

function checkLeaf(schema, value) {
  switch (schema.type) {
    case "bool":
      return typeof value === "boolean" ? null : "expected true or false, got " + typeName(value);
    case "int":
    case "number":
      if (typeof value !== "number" || !Number.isFinite(value)) return "expected a number, got " + typeName(value);
      if (schema.type === "int" && !Number.isInteger(value)) return "expected a whole number";
      if (schema.min !== undefined && value < schema.min) return "must be at least " + schema.min;
      if (schema.max !== undefined && value > schema.max) return "must be at most " + schema.max;
      return null;
    case "string":
      if (typeof value !== "string") return "expected text, got " + typeName(value);
      if (schema.maxLength !== undefined && value.length > schema.maxLength) return "longer than " + schema.maxLength + " characters";
      return null;
    case "enum":
      return schema.values.indexOf(value) !== -1 ? null : "must be one of " + schema.values.join(", ");
    case "color":
      return typeof value === "string" && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value) ? null : "expected a colour like #65D9E8";
  }
  return "unsupported schema type " + schema.type;
}

function walk(schema, value, path, errors, warnings) {
  if (schema.type === "object") {
    if (value === undefined) return defaultsOf(schema);
    if (typeName(value) !== "object") {
      errors.push({ path: path || "(root)", message: "expected an object, got " + typeName(value) + "; using defaults" });
      return defaultsOf(schema);
    }
    const out = {};
    for (const k in schema.props) out[k] = walk(schema.props[k], value[k], path ? path + "." + k : k, errors, warnings);
    for (const k in value) {
      if (Object.prototype.hasOwnProperty.call(schema.props, k)) continue;
      if (k === "$schema") {
        out[k] = value[k];
        continue;
      }
      warnings.push({ path: path ? path + "." + k : k, message: "unknown setting (kept, but has no effect)" });
      out[k] = clone(value[k]);
    }
    return out;
  }
  if (value === undefined) return clone(schema.default);
  if (schema.type === "array") {
    if (!Array.isArray(value)) {
      errors.push({ path: path, message: "expected a list, got " + typeName(value) + "; using default" });
      return clone(schema.default);
    }
    if (schema.maxItems !== undefined && value.length > schema.maxItems) {
      errors.push({ path: path, message: "more than " + schema.maxItems + " entries; using default" });
      return clone(schema.default);
    }
    for (let i = 0; i < value.length; i++) {
      const e = checkLeaf(schema.items, value[i]);
      if (e) {
        errors.push({ path: path + "[" + i + "]", message: e + "; using default for " + path });
        return clone(schema.default);
      }
    }
    return clone(value);
  }
  if (schema.type === "map") {
    if (typeName(value) !== "object") {
      errors.push({ path: path, message: "expected an object, got " + typeName(value) + "; using default" });
      return clone(schema.default);
    }
    const out = {};
    for (const k in value) {
      if (schema.values.type === "object") {
        out[k] = walk(schema.values, value[k], path + "." + k, errors, warnings);
      } else {
        const e = checkLeaf(schema.values, value[k]);
        if (e) errors.push({ path: path + "." + k, message: e + "; ignored" });
        else out[k] = value[k];
      }
    }
    return out;
  }
  const e = checkLeaf(schema, value);
  if (e) {
    errors.push({ path: path, message: e + "; using default " + JSON.stringify(schema.default) });
    return clone(schema.default);
  }
  return value;
}

// Migrations from older schema versions. Each entry upgrades version n to
// n + 1 by transforming the raw object. There are none yet; the mechanism is
// exercised by tests so the first real migration has a tested path.
export const MIGRATIONS = {};

export function migrate(raw, migrations, targetVersion) {
  const steps = migrations || MIGRATIONS;
  const target = targetVersion === undefined ? SCHEMA_VERSION : targetVersion;
  const notes = [];
  if (typeName(raw) !== "object") return { raw: raw, from: null, to: null, notes: notes };
  let v = raw.schemaVersion === undefined ? target : raw.schemaVersion;
  const from = v;
  let cur = clone(raw);
  if (typeof v !== "number" || !Number.isInteger(v) || v < 1) return { raw: cur, from: v, to: v, notes: notes, error: "invalid schemaVersion" };
  while (v < target) {
    const step = steps[v];
    if (typeof step !== "function") return { raw: cur, from: from, to: v, notes: notes, error: "no migration from version " + v };
    cur = step(cur, notes);
    v += 1;
    cur.schemaVersion = v;
  }
  return { raw: cur, from: from, to: v, notes: notes };
}

// Parse and validate configuration text. Never throws.
// Returns { config, errors, warnings, notes, migrated }.
export function validateConfig(text) {
  const errors = [];
  const warnings = [];
  if (text === undefined || text === null || String(text).trim() === "") {
    return { config: defaultsOf(SCHEMA), errors: errors, warnings: warnings, notes: [], migrated: false, empty: true };
  }
  let raw;
  try {
    raw = JSON.parse(String(text));
  } catch (e) {
    errors.push({ path: "(file)", message: "invalid JSON: " + e.message + "; running with defaults" });
    return { config: defaultsOf(SCHEMA), errors: errors, warnings: warnings, notes: [], migrated: false, invalidJson: true };
  }
  let notes = [];
  let migrated = false;
  if (typeName(raw) === "object") {
    if (typeof raw.schemaVersion === "number" && raw.schemaVersion > SCHEMA_VERSION) {
      warnings.push({
        path: "schemaVersion",
        message: "written by a newer AEROLITH (" + raw.schemaVersion + " > " + SCHEMA_VERSION + "); unknown settings are ignored",
      });
      raw = Object.assign({}, raw, { schemaVersion: SCHEMA_VERSION });
    } else {
      const m = migrate(raw);
      if (m.error) errors.push({ path: "schemaVersion", message: m.error });
      else if (m.from !== m.to) migrated = true;
      raw = m.raw;
      notes = m.notes;
    }
  }
  const config = walk(SCHEMA, raw, "", errors, warnings);
  config.schemaVersion = SCHEMA_VERSION;
  return { config: config, errors: errors, warnings: warnings, notes: notes, migrated: migrated };
}

// Structured paths keep connector names containing dots intact. Dotted strings
// remain compatible with existing callers. Never traverse inherited properties.
function partsOf(path) {
  const parts = Array.isArray(path) ? path.slice() : typeof path === "string" ? path.split(".") : [];
  return parts.length && parts.every(p => typeof p === "string" && p.length > 0
    && ["__proto__", "prototype", "constructor"].indexOf(p) < 0) ? parts : [];
}

// Look up a schema leaf, including entries in dynamic maps.
export function schemaAt(path) {
  const parts = partsOf(path);
  if (!parts.length) return null;
  let s = SCHEMA;
  for (let i = 0; i < parts.length; i++) {
    if (s.type === "map") s = s.values;
    else if (s.type === "object" && Object.prototype.hasOwnProperty.call(s.props, parts[i])) s = s.props[parts[i]];
    else return null;
  }
  return s;
}

export function getPath(obj, path) {
  const parts = partsOf(path);
  if (!parts.length) return undefined;
  let cur = obj;
  for (let i = 0; i < parts.length; i++) {
    if (cur === null || typeof cur !== "object" || !Object.prototype.hasOwnProperty.call(cur, parts[i])) return undefined;
    cur = cur[parts[i]];
  }
  return cur;
}

// Return a copy of `raw` with `path` set to `value`, after validating the
// value against the schema. Unknown keys elsewhere are kept untouched.
export function setPath(raw, path, value) {
  const leaf = schemaAt(path);
  const label = partsOf(path).join(".");
  if (!leaf || leaf.type === "object") return { error: "unknown setting " + label };
  if (value === undefined) return { error: label + ": a value is required" };
  if (leaf.type === "array" || leaf.type === "map") {
    // Check only the proposed subtree: unrelated invalid values must not
    // prevent repairing a setting, and unknown keys must survive the write.
    const errors = [];
    walk(leaf, value, label, errors, []);
    if (errors.length) return { error: errors.map(e => e.path + ": " + e.message).join("; ") };
  } else {
    const e = checkLeaf(leaf, value);
    if (e) return { error: label + ": " + e };
  }
  const out = typeName(raw) === "object" ? clone(raw) : {};
  const parts = partsOf(path);
  let cur = out;
  for (let i = 0; i < parts.length - 1; i++) {
    if (typeName(cur[parts[i]]) !== "object") cur[parts[i]] = {};
    cur = cur[parts[i]];
  }
  cur[parts[parts.length - 1]] = clone(value);
  if (out.schemaVersion === undefined) out.schemaVersion = SCHEMA_VERSION;
  return { raw: out };
}

// Explicit appearance boundary. In particular strip.telemetry, workspaceCount,
// OLED idle policy, service/server settings and command execution are excluded.
export const PREVIEW_PATHS = [
  "theme.*", "strip.visible", "strip.edge", "strip.showWindowTitle",
  "strip.clock", "strip.showDate", "strip.showSeconds", "ground.enabled",
  "display.outputs.*.profile",
];

export function previewAllowed(path) {
  const parts = partsOf(path);
  if (!schemaAt(parts)) return false;
  return PREVIEW_PATHS.some(pattern => {
    const rule = pattern.split(".");
    if (pattern === "theme.*") return parts[0] === "theme" && parts.length > 1;
    return rule.length === parts.length && rule.every((p, i) => p === "*" || p === parts[i]);
  });
}

function overlaps(a, b) {
  return a.slice(0, Math.min(a.length, b.length)).every((p, i) => p === b[i]);
}

// All-or-nothing validation; the caller never receives a partial writable raw.
// Reject ambiguous duplicate/parent-child edits in a single batch.
export function prepareBatch(raw, values, previewOnly) {
  if (!Array.isArray(values)) return { error: "settings must be a list of {path, value}" };
  let next = raw;
  const changes = [];
  for (const item of values) {
    if (!item || !partsOf(item.path).length) return { error: "invalid setting path" };
    const path = partsOf(item.path);
    if (changes.some(c => overlaps(c.path, path))) return { error: "overlapping setting " + path.join(".") };
    if (previewOnly && !previewAllowed(path)) return { error: path.join(".") + ": not an appearance setting; cannot preview" };
    const r = setPath(next, path, item.value);
    if (r.error) return r;
    changes.push({ path: path, value: clone(item.value), expected: clone(getPath(raw, path)) });
    next = r.raw;
  }
  return { raw: next, changes: changes };
}

// Rebase a whole transaction against a fresh disk read, checking every path
// before constructing a replacement. Unknown and unrelated values survive.
export function mergeChanges(text, changes) {
  let fresh;
  try { fresh = String(text).trim() ? JSON.parse(text) : {}; }
  catch (e) { return { error: "configuration file is not valid JSON; fix it before saving settings" }; }
  if (typeName(fresh) !== "object")
    return { error: "configuration file must be an object; fix it before saving settings" };
  const conflicts = conflictsFor(fresh, changes);
  if (conflicts.length) return { error: "configuration changed at " + conflicts.join(", ") + "; reload/review your change", conflicts: conflicts };
  return prepareBatch(fresh, changes);
}

export function mergeChange(text, path, value, expected) {
  return mergeChanges(text, [{ path: path, value: value, expected: expected }]);
}

export function conflictsFor(raw, changes) {
  return changes.filter(c => !sameValue(getPath(raw, c.path), c.expected)).map(c => partsOf(c.path).join("."));
}

export function overlay(raw, changes) {
  return prepareBatch(raw, changes).raw;
}

export function beginPreview(raw) {
  return { base: clone(raw), changes: [] };
}

// Repeated edits replace a draft leaf, but always compare disk to the value
// captured at BEGIN, including when that leaf is first edited after a reload.
export function setPreviewValues(preview, values) {
  if (!preview) return { error: "no preview is active" };
  const checked = prepareBatch(overlay(preview.base, preview.changes), values, true);
  if (checked.error) return checked;
  let changes = preview.changes.slice();
  const starting = previewData(preview.base, null);
  for (const c of checked.changes) {
    if (changes.some(prior => !sameValue(prior.path, c.path) && overlaps(prior.path, c.path)))
      return { error: "overlapping draft setting " + c.path.join(".") };
    changes = changes.filter(prior => !sameValue(prior.path, c.path));
    const expected = clone(getPath(preview.base, c.path));
    const initial = getPath(starting, c.path);
    const effective = initial === undefined ? schemaAt(c.path).default : initial;
    if (!sameValue(effective, c.value)) changes.push({ path: c.path, value: c.value, expected: expected });
  }
  return { preview: { base: preview.base, changes: changes } };
}

// Cancel uses the current committed base, preserving external watcher edits.
export function previewData(raw, preview) {
  return validateConfig(JSON.stringify(preview ? overlay(raw, preview.changes) : raw)).config;
}

// Object key order is immaterial, including in map-valued settings.
function sameValue(a, b) {
  if (a === b) return true;
  if (typeName(a) !== typeName(b) || a === null || b === null || typeof a !== "object") return false;
  const keys = Object.keys(a);
  return keys.length === Object.keys(b).length && keys.every(k =>
    Object.prototype.hasOwnProperty.call(b, k) && sameValue(a[k], b[k]));
}

// Convert the compact schema to JSON Schema (draft 2020-12) for editors.
export function toJsonSchema(schema, root) {
  const s = schema || SCHEMA;
  const desc = s.description ? { description: s.description } : {};
  if (s.deprecated) desc.deprecated = true;
  switch (s.type) {
    case "object": {
      const props = {};
      for (const k in s.props) props[k] = toJsonSchema(s.props[k], false);
      if (root !== false) props.$schema = { type: "string" };
      const o = Object.assign({ type: "object" }, desc, { properties: props });
      if (root !== false)
        return Object.assign(
          { $schema: "https://json-schema.org/draft/2020-12/schema", $id: "https://aerolith.invalid/schema/config.schema.json", title: "AEROLITH configuration" },
          o,
        );
      return o;
    }
    case "bool":
      return Object.assign({ type: "boolean" }, desc, { default: s.default });
    case "int":
    case "number":
      return Object.assign({ type: s.type === "int" ? "integer" : "number" }, desc, { default: s.default, minimum: s.min, maximum: s.max });
    case "string":
      return Object.assign({ type: "string" }, desc, { default: s.default, maxLength: s.maxLength });
    case "enum":
      return Object.assign({ enum: s.values }, desc, { default: s.default });
    case "color":
      return Object.assign({ type: "string", pattern: "^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$" }, desc);
    case "array":
      return Object.assign({ type: "array" }, desc, { items: toJsonSchema(s.items, false), default: s.default, maxItems: s.maxItems });
    case "map":
      return Object.assign({ type: "object" }, desc, { additionalProperties: toJsonSchema(s.values, false), default: s.default });
  }
  return {};
}
