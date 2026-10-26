// Application launch helpers and usage ranking.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

// Desktop Entry Exec field codes that must not reach the program as literal
// arguments when launching without files/URLs.
const FIELD_CODE = /%%|%[fFuUdDnNickvm]/g;

// Terminals tried in order when commandCore.terminal is empty.
export const KNOWN_TERMINALS = [
  ["foot"],
  ["kitty", "-e"],
  ["alacritty", "-e"],
  ["wezterm", "start", "--"],
  ["ghostty", "-e"],
  ["konsole", "-e"],
  ["gnome-terminal", "--"],
  ["xterm", "-e"],
];

// Build the argv for launching a desktop entry.
//   entry: { command: [..], runInTerminal: bool }
//   options: { terminal: [..] | null, prefix: [..] }
// Returns { argv } or { error }.
export function buildLaunchArgv(entry, options) {
  const opts = options || {};
  const cmd = [];
  for (const arg of entry && Array.isArray(entry.command) ? entry.command : []) {
    if (typeof arg !== "string") continue;
    // One pass: %%u becomes literal %u, never another field-code expansion.
    const expanded = arg.replace(FIELD_CODE, code => code === "%%" ? "%" : "");
    if (expanded !== "" || arg === "") cmd.push(expanded);
  }
  if (cmd.length === 0) return { error: "application has no command" };
  let argv = cmd.slice();
  if (entry.runInTerminal) {
    const term = Array.isArray(opts.terminal) && opts.terminal.length > 0 ? opts.terminal : null;
    if (!term) return { error: "application needs a terminal; set commandCore.terminal" };
    argv = term.concat(argv);
  }
  const prefix = Array.isArray(opts.prefix) ? opts.prefix : [];
  return { argv: prefix.concat(argv) };
}

// Pick the first terminal whose binary is present. `exists(name)` is
// provided by the caller (it knows how to look at PATH).
export function detectTerminal(exists) {
  for (let i = 0; i < KNOWN_TERMINALS.length; i++) if (exists(KNOWN_TERMINALS[i][0])) return KNOWN_TERMINALS[i].slice();
  return null;
}

// Frecency: launches decay with a 14-day half-life. The usage table is
// { key: { count, last } } and is pruned to `limit` entries.
const HALF_LIFE_MS = 14 * 24 * 3600 * 1000;

export function recordUse(table, key, now, limit) {
  const t = table && typeof table === "object" ? table : {};
  const cur = t[key] || { count: 0, last: 0 };
  t[key] = { count: decayed(cur, now) + 1, last: now };
  prune(t, limit === undefined ? 300 : limit, now);
  return t;
}

function decayed(entry, now) {
  if (!entry || typeof entry.last !== "number" || typeof entry.count !== "number") return 0;
  const age = Math.max(0, now - entry.last);
  return entry.count * Math.pow(0.5, age / HALF_LIFE_MS);
}

export function usageScore(table, key, now) {
  const e = table ? table[key] : null;
  if (!e) return 0;
  // Logarithmic so a habit helps ranking without drowning a good match.
  return Math.log(1 + decayed(e, now)) * 18;
}

function prune(t, limit, now) {
  const keys = Object.keys(t);
  if (keys.length <= limit) return;
  keys.sort((a, b) => decayed(t[a], now) - decayed(t[b], now));
  for (let i = 0; i < keys.length - limit; i++) delete t[keys[i]];
}
