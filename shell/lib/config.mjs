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
        output: S.str("", 64, "Output (monitor) name to run on, e.g. \"DP-1\". Empty selects automatically."),
        warnOnMultipleDisplays: S.bool(true, "Show a caution annunciator when more than one display is connected."),
      },
      "AEROLITH supports exactly one display. These settings choose which one.",
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
      const e = checkLeaf(schema.values, value[k]);
      if (e) errors.push({ path: path + "." + k, message: e + "; ignored" });
      else out[k] = value[k];
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

// Look up a dotted path in the schema: "strip.edge" -> leaf schema or null.
export function schemaAt(path) {
  const parts = String(path).split(".");
  let s = SCHEMA;
  for (let i = 0; i < parts.length; i++) {
    if (!s || s.type !== "object" || !s.props[parts[i]]) return null;
    s = s.props[parts[i]];
  }
  return s;
}

export function getPath(obj, path) {
  const parts = String(path).split(".");
  let cur = obj;
  for (let i = 0; i < parts.length; i++) {
    if (cur === null || typeof cur !== "object") return undefined;
    cur = cur[parts[i]];
  }
  return cur;
}

// Return a copy of `raw` with `path` set to `value`, after validating the
// value against the schema. Unknown keys elsewhere are kept untouched.
export function setPath(raw, path, value) {
  const leaf = schemaAt(path);
  if (!leaf || leaf.type === "object") return { error: "unknown setting " + path };
  const e = leaf.type === "array" || leaf.type === "map" ? null : checkLeaf(leaf, value);
  if (e) return { error: path + ": " + e };
  const out = typeName(raw) === "object" ? clone(raw) : {};
  const parts = String(path).split(".");
  let cur = out;
  for (let i = 0; i < parts.length - 1; i++) {
    if (typeName(cur[parts[i]]) !== "object") cur[parts[i]] = {};
    cur = cur[parts[i]];
  }
  cur[parts[parts.length - 1]] = value;
  if (out.schemaVersion === undefined) out.schemaVersion = SCHEMA_VERSION;
  return { raw: out };
}

// Convert the compact schema to JSON Schema (draft 2020-12) for editors.
export function toJsonSchema(schema, root) {
  const s = schema || SCHEMA;
  const desc = s.description ? { description: s.description } : {};
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
