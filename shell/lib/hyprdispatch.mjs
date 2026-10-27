// Builds Hyprland dispatch requests for both configuration dialects.
//
// Hyprland 0.55+ in Lua mode evaluates dispatch requests as Lua
// (`hl.dsp.focus({ workspace = "3" })`); hyprlang mode uses the legacy text
// form (`workspace 3`). In Lua mode any value interpolated into the request is
// executable code, so every input is validated against a strict shape before
// it is used, and every string is emitted through luaString(). Nothing in this
// module ever concatenates an unvalidated value into a request.
//
// Supported in Qt V4 and Node.js; see docs/RESEARCH.md for the JS subset.

export const DIALECT_LUA = "lua";
export const DIALECT_LEGACY = "hyprlang";

export class DispatchError extends Error {
  constructor(message) {
    super(message);
    this.name = "DispatchError";
  }
}

// Encode an arbitrary string as a double-quoted Lua string literal.
// Escapes backslash, quote and every control character, and encodes any
// non-ASCII code unit as a decimal byte escape of its UTF-8 form so the
// literal is plain printable ASCII.
export function luaString(value) {
  const s = String(value);
  let out = '"';
  const bytes = utf8Bytes(s);
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    if (b === 0x5c) out += "\\\\";
    else if (b === 0x22) out += '\\"';
    else if (b === 0x0a) out += "\\n";
    else if (b === 0x09) out += "\\t";
    else if (b >= 0x20 && b < 0x7f) out += String.fromCharCode(b);
    else out += "\\" + padDecimal(b);
  }
  return out + '"';
}

function padDecimal(n) {
  const s = String(n);
  return s.length >= 3 ? s : "000".slice(s.length) + s;
}

function utf8Bytes(s) {
  const out = [];
  for (let i = 0; i < s.length; i++) {
    let cp = s.charCodeAt(i);
    if (cp >= 0xd800 && cp <= 0xdbff && i + 1 < s.length) {
      const lo = s.charCodeAt(i + 1);
      if (lo >= 0xdc00 && lo <= 0xdfff) {
        cp = 0x10000 + ((cp - 0xd800) << 10) + (lo - 0xdc00);
        i++;
      }
    }
    if (cp < 0x80) out.push(cp);
    else if (cp < 0x800) out.push(0xc0 | (cp >> 6), 0x80 | (cp & 0x3f));
    else if (cp < 0x10000) out.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
    else
      out.push(
        0xf0 | (cp >> 18),
        0x80 | ((cp >> 12) & 0x3f),
        0x80 | ((cp >> 6) & 0x3f),
        0x80 | (cp & 0x3f),
      );
  }
  return out;
}

// Window addresses are hexadecimal. Quickshell reports them without the 0x
// prefix (HyprlandToplevel.address); Hyprland's JSON uses the prefix.
export function normalizeAddress(address) {
  const s = String(address === undefined || address === null ? "" : address).trim().toLowerCase();
  const hex = s.indexOf("0x") === 0 ? s.slice(2) : s;
  if (!/^[0-9a-f]{1,16}$/.test(hex)) throw new DispatchError("invalid window address: " + JSON.stringify(address));
  return "0x" + hex;
}

const WORKSPACE_NAME = /^[A-Za-z0-9_.+-][A-Za-z0-9 _.+-]{0,63}$/;
const SPECIAL_NAME = /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$/;

export function specialWorkspaceSelector(name) {
  if (typeof name !== "string" || !SPECIAL_NAME.test(name))
    throw new DispatchError("invalid special workspace name: " + JSON.stringify(name));
  return "special:" + name;
}

// Accepts a workspace id (integer, 1..9999 or negative special ids are not
// accepted) or { name } for a named workspace. Returns the selector string
// Hyprland understands in both dialects: "3" or "name:web". An explicit
// { special: name } selects a special workspace for window parking.
export function workspaceSelector(ws) {
  if (ws && typeof ws === "object" && "special" in ws) return specialWorkspaceSelector(ws.special);
  if (typeof ws === "number" || (typeof ws === "string" && /^\d+$/.test(ws))) {
    const n = Number(ws);
    if (!Number.isInteger(n) || n < 1 || n > 9999) throw new DispatchError("workspace id out of range: " + ws);
    return String(n);
  }
  if (ws && typeof ws === "object" && typeof ws.name === "string") {
    if (!WORKSPACE_NAME.test(ws.name) || /\s$/.test(ws.name))
      throw new DispatchError("unsupported workspace name: " + JSON.stringify(ws.name));
    return "name:" + ws.name;
  }
  throw new DispatchError("invalid workspace: " + JSON.stringify(ws));
}

function dialectOf(d) {
  if (d === DIALECT_LUA || d === DIALECT_LEGACY) return d;
  throw new DispatchError("unknown dispatch dialect: " + d);
}

export function focusWorkspace(dialect, workspace) {
  const sel = workspaceSelector(workspace);
  if (dialectOf(dialect) === DIALECT_LUA) return "hl.dsp.focus({ workspace = " + luaString(sel) + " })";
  return "workspace " + sel;
}

export function focusWindow(dialect, address) {
  const addr = normalizeAddress(address);
  if (dialectOf(dialect) === DIALECT_LUA) return "hl.dsp.focus({ window = " + luaString("address:" + addr) + " })";
  return "focuswindow address:" + addr;
}

export function focusMonitor(dialect, name) {
  if (typeof name !== "string" || !/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(name))
    throw new DispatchError("invalid monitor name: " + JSON.stringify(name));
  if (dialectOf(dialect) === DIALECT_LUA) return "hl.dsp.focus({ monitor = " + luaString(name) + " })";
  return "focusmonitor " + name;
}

// Lua API: https://wiki.hypr.land/0.55.0/Configuring/Basics/Dispatchers/#workspace-1
export function toggleSpecialWorkspace(dialect, name) {
  specialWorkspaceSelector(name);
  if (dialectOf(dialect) === DIALECT_LUA) return "hl.dsp.workspace.toggle_special(" + luaString(name) + ")";
  return "togglespecialworkspace " + name;
}

export function moveWindowToWorkspace(dialect, address, workspace, follow) {
  const addr = normalizeAddress(address);
  const sel = workspaceSelector(workspace);
  const f = follow === true;
  if (dialectOf(dialect) === DIALECT_LUA)
    return (
      "hl.dsp.window.move({ workspace = " +
      luaString(sel) +
      ", follow = " +
      (f ? "true" : "false") +
      ", window = " +
      luaString("address:" + addr) +
      " })"
    );
  return (f ? "movetoworkspace " : "movetoworkspacesilent ") + sel + ",address:" + addr;
}

export function closeWindow(dialect, address) {
  const addr = normalizeAddress(address);
  if (dialectOf(dialect) === DIALECT_LUA) return "hl.dsp.window.close({ window = " + luaString("address:" + addr) + " })";
  return "closewindow address:" + addr;
}

// End the Hyprland session. Hyprland's documentation recommends
// hyprshutdown for a graceful exit; this is the compositor's own exit.
export function exitSession(dialect) {
  return dialectOf(dialect) === DIALECT_LUA ? "hl.dsp.exit()" : "exit";
}

// Interpret Hyprland's reply to a dispatch request.
export function interpretReply(reply) {
  const text = String(reply === undefined || reply === null ? "" : reply).trim();
  if (text === "ok") return { ok: true, message: "ok" };
  if (text.length === 0) return { ok: false, message: "no reply from Hyprland" };
  return { ok: false, message: text.length > 300 ? text.slice(0, 300) + "…" : text };
}

// Hyprland reports a monitor's mode in physical pixels, while its position
// and every window's `at`/`size` are logical layout coordinates. The logical
// size divides by the scale and swaps width and height for the 90/270 degree
// transforms (1, 3, 5, 7). Invalid input gives null.
export function logicalMonitorSize(width, height, scale, transform) {
  if (!(width > 0) || !(height > 0)) return null;
  const s = scale > 0 ? scale : 1;
  const rotated = transform === 1 || transform === 3 || transform === 5 || transform === 7;
  const w = Math.round(width / s);
  const h = Math.round(height / s);
  return rotated ? { width: h, height: w } : { width: w, height: h };
}
