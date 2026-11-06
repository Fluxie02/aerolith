// Presentation metadata only. Bounds, defaults and writable paths stay in Config.
import { SCHEMA, schemaAt } from "../../lib/config.mjs";
import { resolvePalette, oledPalette, contrast, MIN_TEXT_CONTRAST } from "../../lib/tokens.mjs";
import { schemeById } from "../../lib/schemes.mjs";

export const SECTIONS = ["Colour", "Text & space", "Motion", "Strip & Ground", "Displays", "Presets"];
export const ROLES = ["obsidian", "surface", "surface2", "grid", "text", "textDim", "signal", "caution", "critical", "nominal"];
// Repeater models can expose a QVariant sequence rather than a JS Array.
// Copy it without joining: a literal dot in a connector name is significant.
export function pathOf(path) {
  return typeof path === "string" ? path : Array.prototype.slice.call(path);
}
const LABELS = {
  "theme.density": "Spacing & type density", "theme.uiScale": "Overall interface scale",
  "theme.textSize": "Text size (%)",
  "theme.fontSans": "Interface font", "theme.fontMono": "Instrument font",
  "theme.motion": "Motion", "theme.intensity": "Decoration level", "theme.lowEffects": "Low effects",
  "strip.visible": "Show status strip", "strip.edge": "Status strip edge",
  "strip.showWindowTitle": "Focused window title", "strip.clock": "Clock format",
  "strip.showNetwork": "Network indicator", "strip.showBluetooth": "Bluetooth indicator",
  "strip.showMedia": "Media indicator", "strip.showAudio": "Audio indicator",
  "strip.showBattery": "Battery indicator", "strip.showNotifications": "Notifications indicator",
  "ground.showNowPlaying": "Ground · Now playing", "ground.showTelemetry": "Ground · Telemetry",
  "ground.showAppRegister": "Ground · App register",
  "strip.showDate": "Show date", "strip.showSeconds": "Show seconds", "ground.enabled": "Show Ground",
};
const GROUPS = [[], ["theme.density", "theme.uiScale", "theme.textSize", "theme.fontSans", "theme.fontMono"],
  ["theme.motion", "theme.intensity", "theme.lowEffects"],
  ["strip.visible", "strip.edge", "strip.showWindowTitle", "strip.clock", "strip.showDate", "strip.showSeconds", "strip.showNetwork", "strip.showBluetooth", "strip.showMedia", "strip.showAudio", "strip.showBattery", "strip.showNotifications", "ground.enabled", "ground.showNowPlaying", "ground.showTelemetry", "ground.showAppRegister"], []];
export function controls(section) {
  return (GROUPS[section] || []).map(path => Object.assign({values: []}, schemaAt(path), {path: path, label: LABELS[path]}));
}
export function outputControls(name) {
  return ["profile", "blackBackground", "strip", "ground"].map(key => Object.assign({values: []}, SCHEMA.props.display.props.outputs.values.props[key], {
    path: ["display", "outputs", name, key], label: key === "profile" ? "Display profile" : key === "blackBackground" ? "Black background" : key === "strip" ? "Allow status strip on this output" : "Allow Ground on this output",
  }));
}
export function step(row, value, direction) {
  if (row.type === "bool") return !value;
  if (row.type === "enum") return row.values[(row.values.indexOf(value) + direction + row.values.length) % row.values.length];
  return Math.round(Math.max(row.min, Math.min(row.max, value + direction * .05)) * 100) / 100;
}
export function safetyPath(path) {
  const p = Array.isArray(path) ? path.join(".") : path;
  return p === "theme.uiScale" || p === "strip.visible" || p === "ground.enabled";
}
// The compositor composites these existing transient tints over the housing.
function tint(fg, bg, alpha) {
  return "#" + [1, 3, 5].map(i => {
    const channel = Math.round(parseInt(fg.slice(i, i + 2), 16) * alpha + parseInt(bg.slice(i, i + 2), 16) * (1 - alpha)).toString(16);
    return channel.length === 1 ? "0" + channel : channel;
  }).join("");
}
export function paletteError(overrides, scheme, integratedApps) {
  for (const key in overrides) {
    if (ROLES.indexOf(key) < 0) return "Unknown palette role: " + key;
    if (!/^#[0-9a-fA-F]{6}$/.test(overrides[key])) return key + ": use opaque #RRGGBB";
  }
  const standard = resolvePalette(overrides, scheme);
  const black = Object.assign({}, standard, {obsidian: "#000000"});
  const oled = oledPalette(standard, {appLink: schemeById(scheme).link});
  const profiles = [{name: "standard", p: standard}, {name: "black", p: black}, {name: "OLED", p: oled}];
  for (let i = 0; i < profiles.length; i++) {
    const p = profiles[i].p;
    const fills = [{name: "normal / surface", color: p.surface}, {name: "background / obsidian", color: p.obsidian},
      {name: "selected / surface2", color: p.surface2},
      {name: "tinted / signal 15%", color: i === 2 ? p.surface2 : tint(p.signal, p.surface, .15)},
      {name: "navigator selected / signal 15%", color: i === 2 ? p.surface2 : tint(p.signal, p.obsidian, .15)},
      {name: "tinted / caution 12%", color: i === 2 ? p.surface2 : tint(p.caution, p.surface, .12)},
      {name: "strip urgent / caution 18%", color: i === 2 ? p.surface2 : tint(p.caution, p.obsidian, .18)}];
    const roles = ["text", "textDim", "signal", "caution", "critical", "nominal"];
    // THEARS derives appLink from signal, which is already checked above.
    if (integratedApps !== false) roles.push("appLink");
    for (let r = 0; r < roles.length; r++) {
      const role = roles[r];
      const fg = p[role] || schemeById(scheme).link;
      for (let f = 0; f < fills.length; f++) {
        const ratio = contrast(fg, fills[f].color);
        if (ratio < MIN_TEXT_CONTRAST)
          return profiles[i].name + ": " + role + " on " + fills[f].name + " = " + ratio.toFixed(2) + ":1; requires " + MIN_TEXT_CONTRAST.toFixed(1) + ":1";
      }
    }
  }
  return "";
}
