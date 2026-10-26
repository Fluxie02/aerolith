// Telemetry parsing and arithmetic for the Systems Bay and Flight Strip.
//
// Every function here is pure: the QML Telemetry service reads files and
// processes, passes the text in, and gets numbers back. Metrics that the
// system does not provide are represented as null, never as 0, so the UI can
// show "N/A" instead of a misleading zero.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

const CPU_FIELDS = ["user", "nice", "system", "idle", "iowait", "irq", "softirq", "steal"];

// /proc/stat -> { total: jiffies, cpus: [jiffies...] }
// where jiffies = { busy, idle, all }.
export function parseProcStat(text) {
  const lines = String(text || "").split("\n");
  let total = null;
  const cpus = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.indexOf("cpu") !== 0) continue;
    const parts = line.trim().split(/\s+/);
    const label = parts[0];
    const vals = {};
    for (let k = 0; k < CPU_FIELDS.length; k++) vals[CPU_FIELDS[k]] = Number(parts[k + 1] || 0);
    const idle = vals.idle + vals.iowait;
    const all = CPU_FIELDS.reduce((s, f) => s + vals[f], 0);
    const j = { busy: all - idle, idle: idle, all: all };
    if (label === "cpu") total = j;
    else if (/^cpu\d+$/.test(label)) cpus[Number(label.slice(3))] = j;
  }
  if (total === null) return null;
  return { total: total, cpus: cpus };
}

function utilisation(prev, cur) {
  if (!prev || !cur) return null;
  const dAll = cur.all - prev.all;
  const dBusy = cur.busy - prev.busy;
  if (dAll <= 0) return null;
  return clamp((dBusy / dAll) * 100, 0, 100);
}

// Percent busy between two parseProcStat() snapshots.
export function cpuUsage(prev, cur) {
  if (!prev || !cur) return { total: null, cores: [] };
  const cores = [];
  for (let i = 0; i < cur.cpus.length; i++) cores.push(utilisation(prev.cpus[i], cur.cpus[i]));
  return { total: utilisation(prev.total, cur.total), cores: cores };
}

// /proc/meminfo -> map of field -> bytes (values in kB are converted).
export function parseMeminfo(text) {
  const out = {};
  const lines = String(text || "").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const m = /^([A-Za-z0-9_()]+):\s+(\d+)(\s+kB)?/.exec(lines[i]);
    if (m) out[m[1]] = Number(m[2]) * (m[3] ? 1024 : 1);
  }
  return out;
}

export function memoryUsage(info) {
  const total = info.MemTotal;
  if (!total) return null;
  // MemAvailable exists since Linux 3.14; fall back to the classic estimate.
  const avail =
    info.MemAvailable !== undefined ? info.MemAvailable : (info.MemFree || 0) + (info.Buffers || 0) + (info.Cached || 0);
  const used = total - avail;
  const swapTotal = info.SwapTotal === undefined ? null : info.SwapTotal;
  const swapUsed = swapTotal === null ? null : swapTotal - (info.SwapFree || 0);
  return {
    totalBytes: total,
    usedBytes: used,
    availableBytes: avail,
    percent: clamp((used / total) * 100, 0, 100),
    swapTotalBytes: swapTotal,
    swapUsedBytes: swapUsed,
    swapPercent: swapTotal ? clamp((swapUsed / swapTotal) * 100, 0, 100) : null,
  };
}

// /proc/pressure/{cpu,memory,io} -> { some: {avg10, avg60, avg300}, full: {...} | null }
export function parsePressure(text) {
  const out = { some: null, full: null };
  const lines = String(text || "").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const m = /^(some|full)\s+avg10=([\d.]+)\s+avg60=([\d.]+)\s+avg300=([\d.]+)/.exec(lines[i].trim());
    if (m) out[m[1]] = { avg10: Number(m[2]), avg60: Number(m[3]), avg300: Number(m[4]) };
  }
  return out.some === null && out.full === null ? null : out;
}

// /proc/net/dev -> { iface: { rx, tx } } in bytes.
export function parseNetDev(text) {
  const out = {};
  const lines = String(text || "").split("\n");
  for (let i = 2; i < lines.length; i++) {
    const idx = lines[i].indexOf(":");
    if (idx === -1) continue;
    const name = lines[i].slice(0, idx).trim();
    const f = lines[i].slice(idx + 1).trim().split(/\s+/);
    if (f.length < 9) continue;
    out[name] = { rx: Number(f[0]), tx: Number(f[8]) };
  }
  return out;
}

const VIRTUAL_IFACE = /^(lo|docker\d*|veth|br-|virbr|vnet|tun|tap|wg-mullvad)/;

// Network rates between two parseNetDev() snapshots taken dtMs apart.
// Loopback and common virtual bridges are excluded from the total.
export function netRates(prev, cur, dtMs) {
  if (!prev || !cur || !(dtMs > 0)) return null;
  let rx = 0;
  let tx = 0;
  const ifaces = {};
  for (const name in cur) {
    if (!prev[name]) continue;
    // Counters can reset when an interface is re-created.
    const dRx = Math.max(0, cur[name].rx - prev[name].rx);
    const dTx = Math.max(0, cur[name].tx - prev[name].tx);
    const r = { rxBps: (dRx * 1000) / dtMs, txBps: (dTx * 1000) / dtMs };
    ifaces[name] = r;
    if (!VIRTUAL_IFACE.test(name)) {
      rx += r.rxBps;
      tx += r.txBps;
    }
  }
  return { rxBps: rx, txBps: tx, ifaces: ifaces };
}

// `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr
//  --format=csv,noheader,nounits` -> one object per GPU line.
export const NVIDIA_QUERY = ["utilization.gpu", "memory.used", "memory.total", "temperature.gpu", "power.draw", "clocks.gr", "name"];

export function parseNvidiaSmi(line) {
  const parts = String(line || "").split(",").map((s) => s.trim());
  if (parts.length < NVIDIA_QUERY.length) return null;
  const num = (s) => {
    if (s === "" || /N\/A|Not Supported|\[/i.test(s)) return null;
    const n = Number(s);
    return Number.isFinite(n) ? n : null;
  };
  return {
    vendor: "nvidia",
    name: parts.slice(6).join(", "),
    utilPercent: num(parts[0]),
    vramUsedBytes: num(parts[1]) === null ? null : num(parts[1]) * 1024 * 1024,
    vramTotalBytes: num(parts[2]) === null ? null : num(parts[2]) * 1024 * 1024,
    tempC: num(parts[3]),
    powerW: num(parts[4]),
    clockMHz: num(parts[5]),
  };
}

// Parse a sysfs integer file ("123\n"); returns null for empty/invalid.
export function parseSysfsInt(text) {
  const s = String(text === undefined || text === null ? "" : text).trim();
  if (!/^-?\d+$/.test(s)) return null;
  return Number(s);
}

// `ps -eo pid=,times=,rss=,comm=` -> [{ pid, cpuSeconds, rssBytes, comm }]
export function parsePs(text) {
  const out = [];
  const lines = String(text || "").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const m = /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.+?)\s*$/.exec(lines[i]);
    if (!m) continue;
    out.push({ pid: Number(m[1]), cpuSeconds: Number(m[2]), rssBytes: Number(m[3]) * 1024, comm: m[4] });
  }
  return out;
}

// Instantaneous per-process CPU from two parsePs() snapshots dtMs apart.
// Percent is of one logical CPU (like top), so it can exceed 100.
// `times` has one-second resolution, so short windows are noisy; callers
// should sample no faster than every 2 s.
export function topProcesses(prev, cur, dtMs, limit, sortBy) {
  if (!cur) return [];
  const before = {};
  if (prev) for (let i = 0; i < prev.length; i++) before[prev[i].pid] = prev[i];
  const rows = [];
  for (let i = 0; i < cur.length; i++) {
    const p = cur[i];
    const b = before[p.pid];
    let cpu = null;
    if (b && b.comm === p.comm && dtMs > 0) cpu = Math.max(0, ((p.cpuSeconds - b.cpuSeconds) * 1000 * 100) / dtMs);
    rows.push({ pid: p.pid, comm: p.comm, rssBytes: p.rssBytes, cpuPercent: cpu });
  }
  const key = sortBy === "memory" ? (r) => r.rssBytes : (r) => (r.cpuPercent === null ? -1 : r.cpuPercent);
  rows.sort((a, b) => key(b) - key(a) || b.rssBytes - a.rssBytes);
  return rows.slice(0, limit === undefined ? 10 : limit);
}

// `df -P -B1 -x tmpfs -x devtmpfs -x efivarfs -x overlay` output.
export function parseDf(text) {
  const out = [];
  const lines = String(text || "").split("\n");
  for (let i = 1; i < lines.length; i++) {
    const f = lines[i].trim().split(/\s+/);
    if (f.length < 6 || !/^\d+$/.test(f[1])) continue;
    const size = Number(f[1]);
    const used = Number(f[2]);
    out.push({
      device: f[0],
      mount: f.slice(5).join(" "),
      sizeBytes: size,
      usedBytes: used,
      availBytes: Number(f[3]),
      percent: size > 0 ? clamp((used / size) * 100, 0, 100) : null,
    });
  }
  return out;
}

// Choose the temperature sensors that matter from hwmon names.
// sensors: [{ name, label, path }] -> { cpu: path|null, gpu: path|null, nvme: path|null }
export function pickHwmon(sensors) {
  const pick = { cpu: null, gpu: null, nvme: null };
  // Labels are in priority order; the first label any matching chip
  // provides wins, then any sensor from a matching chip.
  const prefer = (names, labels) => {
    for (let l = 0; l < labels.length; l++)
      for (let i = 0; i < sensors.length; i++)
        if (names.indexOf(sensors[i].name) !== -1 && sensors[i].label === labels[l]) return sensors[i].path;
    for (let i = 0; i < sensors.length; i++) if (names.indexOf(sensors[i].name) !== -1) return sensors[i].path;
    return null;
  };
  pick.cpu = prefer(["k10temp", "zenpower", "coretemp", "cpu_thermal", "acpitz"], ["Tctl", "Tdie", "Package id 0"]);
  pick.gpu = prefer(["amdgpu", "nouveau", "i915", "xe"], ["edge", "junction"]);
  pick.nvme = prefer(["nvme"], ["Composite"]);
  return pick;
}

// Fixed-capacity numeric history. Memory use is bounded by capacity.
export function createHistory(capacity) {
  const cap = Math.max(1, capacity | 0);
  const buf = [];
  return {
    push(v) {
      buf.push(v === undefined ? null : v);
      if (buf.length > cap) buf.shift();
    },
    values() {
      return buf.slice();
    },
    last() {
      return buf.length ? buf[buf.length - 1] : null;
    },
    size() {
      return buf.length;
    },
    capacity() {
      return cap;
    },
    clear() {
      buf.length = 0;
    },
  };
}

// Adaptive sampling: pick an interval from who is watching.
// demand: { strip: bool, panel: bool, detail: bool }, intervals from config.
export function samplingInterval(demand, intervals, performanceMode) {
  const iv = intervals || {};
  let ms = 0;
  if (demand && demand.detail) ms = iv.detailMs || 1000;
  else if (demand && demand.panel) ms = iv.panelMs || 2000;
  else if (demand && demand.strip) ms = iv.stripMs || 5000;
  if (ms > 0 && performanceMode) ms = Math.max(ms * 2, 2000);
  return ms;
}

export function classify(value, caution, critical) {
  if (value === null || value === undefined || !Number.isFinite(value)) return "unknown";
  if (critical !== undefined && value >= critical) return "critical";
  if (caution !== undefined && value >= caution) return "caution";
  return "nominal";
}

export function clamp(v, lo, hi) {
  return v < lo ? lo : v > hi ? hi : v;
}

const UNITS = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"];

export function formatBytes(n, digits) {
  if (n === null || n === undefined || !Number.isFinite(n)) return "N/A";
  let v = Math.abs(n);
  let u = 0;
  while (v >= 1024 && u < UNITS.length - 1) {
    v /= 1024;
    u++;
  }
  const d = digits === undefined ? (v >= 100 || u === 0 ? 0 : 1) : digits;
  return (n < 0 ? "-" : "") + v.toFixed(d) + " " + UNITS[u];
}

export function formatRate(bps) {
  if (bps === null || bps === undefined || !Number.isFinite(bps)) return "N/A";
  return formatBytes(bps) + "/s";
}

export function formatPercent(p, digits) {
  if (p === null || p === undefined || !Number.isFinite(p)) return "N/A";
  return p.toFixed(digits === undefined ? 0 : digits) + "%";
}

export function formatTemp(c) {
  if (c === null || c === undefined || !Number.isFinite(c)) return "N/A";
  return Math.round(c) + "°C";
}

export function formatDuration(seconds) {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds) || seconds <= 0) return "N/A";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m";
}
