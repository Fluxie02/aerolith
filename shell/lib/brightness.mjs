// Backlight selection and level arithmetic (roadmap D02).
//
// /sys/class/backlight lists every backlight interface the kernel offers;
// a laptop often has several for the same panel. The kernel documents the
// order of preference: "firmware" (ACPI/EFI), then "platform", then "raw"
// (direct register access). Among equals the finest control wins.
//
// Supported in Qt V4 and Node.js; see docs/RESEARCH.md for the JS subset.

const TYPE_RANK = { firmware: 0, platform: 1, raw: 2 };

// devices: [{ name, type, max, value }]. Returns the device to control, or null.
export function pickDevice(devices) {
  if (!Array.isArray(devices)) return null;
  let best = null;
  for (let i = 0; i < devices.length; i++) {
    const d = devices[i];
    if (!d || typeof d.name !== "string" || !/^[\w.:-]+$/.test(d.name)) continue;
    if (!(d.max > 0)) continue;
    const rank = TYPE_RANK[d.type] === undefined ? 3 : TYPE_RANK[d.type];
    if (best === null || rank < best.rank || (rank === best.rank && d.max > best.device.max))
      best = { rank: rank, device: d };
  }
  return best ? best.device : null;
}

// Lines of "name<TAB>type<TAB>max_brightness<TAB>brightness".
export function parseDevices(text) {
  const out = [];
  const lines = String(text || "").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const f = lines[i].split("\t");
    if (f.length < 4 || !f[0]) continue;
    out.push({ name: f[0], type: f[1], max: parseInt(f[2], 10), value: parseInt(f[3], 10) });
  }
  return out;
}

export function toPercent(value, max) {
  if (!(max > 0) || !isFinite(value)) return NaN;
  return Math.round(Math.max(0, Math.min(max, value)) * 100 / max);
}

// Raw value for a percentage. Never 0: on many panels that switches the
// backlight off, which looks like a dead screen, so 1% is the floor.
export function fromPercent(percent, max) {
  if (!(max > 0) || !isFinite(percent)) return NaN;
  const p = Math.max(1, Math.min(100, percent));
  return Math.max(1, Math.round(p * max / 100));
}

// The next level for a relative step, aligned to the step so repeated key
// presses land on 5, 10, 15 ... rather than drifting.
export function stepPercent(current, delta) {
  if (!isFinite(current)) return NaN;
  const size = Math.abs(delta);
  let next = delta > 0 ? Math.floor(current / size) * size + size : Math.ceil(current / size) * size - size;
  return Math.max(1, Math.min(100, next));
}
