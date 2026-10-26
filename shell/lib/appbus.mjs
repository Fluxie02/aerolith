// The application bus (components/AppContinuity.qml): which windows belong
// to an application, which window a click focuses, and which desktop entry
// starts the application when it is not running.

// The applications on the bus. `match` is checked against window classes and
// desktop entry ids; `desktopIds` are tried first when starting the app.
export const PORTS = [
  { name: "Firefox", code: "01", kind: "BROWSE", match: "firefox", query: "firefox", desktopIds: ["firefox", "org.mozilla.firefox"] },
  { name: "LibreOffice", code: "02", kind: "COMPOSE", match: "libreoffice", query: "libreoffice", desktopIds: ["libreoffice-startcenter", "org.libreoffice.LibreOffice.startcenter", "startcenter"] },
  { name: "Steam", code: "03", kind: "PLAY", match: "steam", query: "steam", desktopIds: ["steam", "com.valvesoftware.Steam"] },
  { name: "Discord", code: "04", kind: "CONNECT", match: "discord", query: "discord", desktopIds: ["vesktop", "dev.vencord.Vesktop", "discord", "com.discordapp.Discord"] },
  { name: "ArtCraft", code: "05", kind: "CREATE", match: "craft", query: "craft", desktopIds: [] },
];

export function matches(appId, port) {
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
  const norm = (id) => String(id || "").replace(/\.desktop$/, "").toLowerCase();
  for (const want of port.desktopIds || []) {
    const hit = list.find((e) => norm(e.id) === want.toLowerCase());
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
