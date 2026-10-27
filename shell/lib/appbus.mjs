// The application bus (components/AppContinuity.qml): which windows belong
// to an application, which window a click focuses, and which desktop entry
// starts the application when it is not running.

import { usageScore } from "./launch.mjs";

// The applications on the bus. `match` is checked against window classes and
// desktop entry ids; `desktopIds` are tried first when starting the app.
export const PORTS = [
  { name: "Firefox", code: "01", kind: "BROWSE", match: "firefox", query: "firefox", desktopIds: ["firefox", "org.mozilla.firefox"] },
  { name: "LibreOffice", code: "02", kind: "COMPOSE", match: "libreoffice", query: "libreoffice", desktopIds: ["libreoffice-startcenter", "org.libreoffice.LibreOffice.startcenter", "startcenter"] },
  { name: "Steam", code: "03", kind: "PLAY", match: "steam", query: "steam", desktopIds: ["steam", "com.valvesoftware.Steam"] },
  { name: "Discord", code: "04", kind: "CONNECT", match: "discord", query: "discord", desktopIds: ["vesktop", "dev.vencord.Vesktop", "discord", "com.discordapp.Discord"] },
  { name: "ArtCraft", code: "05", kind: "CREATE", match: "craft", query: "craft", desktopIds: [] },
];

function appKey(id) {
  return String(id || "").toLowerCase().replace(/\.desktop$/, "");
}

export function readableName(id) {
  const tail = String(id || "").replace(/\.desktop$/i, "").split(".").pop().replace(/[_-]+/g, " ").trim();
  return tail ? tail.charAt(0).toUpperCase() + tail.slice(1) : "Application";
}

// Quickshell exposes Desktop Entry StartupWMClass as startupClass. Prefer
// exact ids (including reverse-DNS/Flatpak ids) over advertised X11 classes.
export function entryForWindow(entries, appId) {
  const key = appKey(appId);
  if (!key) return null;
  const list = Array.from(entries || []);
  const exact = list.find(e => appKey(e.id) === key);
  if (exact) return exact;
  const startup = list.find(e => appKey(e.startupClass) === key);
  if (startup) return startup;
  // Older X11 apps may use a short class while their Flatpak uses a DNS id.
  const known = PORTS.find(p => key === p.match || p.desktopIds.some(id => appKey(id) === key));
  return known ? entryFor(list, known) : null;
}

// One entry per desktop id, with window-only apps retained. Usage wins, then
// running state and name break ties; unused installed entries fill spare slots.
// No timer: callers recompute on desktop-index, window or Store changes.
export function barApps(entries, windows, usage, now, limit) {
  const list = Array.from(entries || []);
  const byId = new Map();
  function add(id, name, icon) {
    const key = appKey(id);
    if (!byId.has(key)) byId.set(key, {
      id: String(id), name: name || readableName(id),
      icon: icon || "application-x-executable", running: false, windows: [],
      appIds: [key],
      desktopIds: [String(id)], query: name || readableName(id)
    });
    return byId.get(key);
  }
  for (const e of list) {
    if (appKey(e.id)) add(e.id, e.name, e.icon);
  }
  for (const w of windows || []) {
    const key = appKey(w.appId);
    if (!key) continue;
    const e = entryForWindow(list, w.appId);
    const app = e ? byId.get(appKey(e.id)) : add(key, readableName(w.appId), "");
    app.running = true;
    app.windows.push(w);
    if (app.appIds.indexOf(key) < 0) app.appIds.push(key);
  }
  // Store normally uses the exact desktop id. Accept suffix/case variants
  // from earlier indexes without counting the same launch history twice.
  const scores = new Map();
  for (const key of Object.keys(usage || {})) {
    if (key.indexOf("apps:") !== 0) continue;
    const id = appKey(key.slice(5));
    scores.set(id, Math.max(scores.get(id) || 0, usageScore(usage, key, now)));
  }
  const out = Array.from(byId.values()).sort((a, b) =>
    (scores.get(appKey(b.id)) || 0) - (scores.get(appKey(a.id)) || 0) ||
    Number(b.running) - Number(a.running) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  return limit === undefined ? out : out.slice(0, Math.max(0, Math.floor(limit)));
}

export function matches(appId, port) {
  // Service-produced ports use exact aliases, never substring matching.
  if (port.appIds) return port.appIds.indexOf(appKey(appId)) >= 0;
  const id = String(appId || "").toLowerCase();
  if (port.match === "craft") return /(^|[./_-])(photo|vector|film|light|pdf|effect|design|fig|word|sound|deck|cad|grid)craft($|[./_-])/.test(id);
  if (port.match === "steam") return /^(steam|com\.valvesoftware\.steam)$/.test(id);
  if (port.match === "discord") return /^(discord|discordcanary|discordptb|vesktop|com\.discordapp\.discord|dev\.vencord\.vesktop)$/.test(id);
  return id.indexOf(port.match) >= 0;
}

// windows: [{ address, appId, focusHistory }], focusHistory 0 = focused.
// A click goes to the application's most recently used window; when that
// application already has focus, it moves on to its next window (in a
// stable order, so repeated clicks visit every window).
export function windowToFocus(windows, port, activeAddress) {
  const own = (windows || []).filter((w) => matches(w.appId, port));
  if (own.length === 0) return null;
  const stable = own.slice().sort((a, b) => (a.address < b.address ? -1 : a.address > b.address ? 1 : 0));
  const at = stable.findIndex((w) => w.address === activeAddress);
  if (at >= 0) return stable.length > 1 ? stable[(at + 1) % stable.length] : null;
  return own.slice().sort((a, b) => history(a) - history(b))[0];
}

function history(w) {
  return typeof w.focusHistory === "number" && w.focusHistory >= 0 ? w.focusHistory : Number.MAX_SAFE_INTEGER;
}

// entries: desktop entries ({ id, ... }); ids are compared without
// ".desktop" and case. Known ids first, then any entry the matcher accepts.
export function entryFor(entries, port) {
  const list = Array.from(entries || []);
  const norm = appKey;
  for (const want of port.desktopIds || []) {
    const hit = list.find((e) => norm(e.id) === norm(want));
    if (hit) return hit;
  }
  return list.find((e) => matches(norm(e.id), port)) || null;
}

// What a click on the port does: { kind: "focus", address } |
// { kind: "launch", id } | { kind: "search", query }.
export function action(windows, port, activeAddress, entries) {
  const own = (windows || []).filter((w) => matches(w.appId, port));
  if (own.length > 0) {
    const target = windowToFocus(own, port, activeAddress);
    // The app's only window already has focus: nothing to switch to.
    return target ? { kind: "focus", address: target.address } : { kind: "none" };
  }
  const entry = entryFor(entries, port);
  if (entry) return { kind: "launch", id: String(entry.id) };
  return { kind: "search", query: port.query };
}
