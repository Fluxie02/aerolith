// Visual exposure only: consume existing logical compositor snapshots. No IPC,
// sampling, surface lifecycle changes or guessed coverage percentage.
// slack: logical pixels each window is widened by on every side before the
// check, so ordinary Hyprland gaps (gaps_in / gaps_out) between tiled
// windows count as covered; a real empty area larger than that does not.
export function desktopCovered(windows, output, workspace, slack) {
  const s = typeof slack === "number" && isFinite(slack) && slack > 0 ? slack : 0;
  if (!Array.isArray(windows) || !output || !Number.isInteger(workspace) || workspace === -1) return false;
  const x = output.x, y = output.y, width = output.width, height = output.height;
  if (![x, y, width, height].every(v => typeof v === "number" && isFinite(v)) || width <= 0 || height <= 0) return false;
  const right = x + width, bottom = y + height;
  const rects = [], cuts = [x, right];
  for (let i = 0; i < windows.length; i++) {
    const w = windows[i];
    if (!w || w.workspaceId !== workspace) continue;
    const ipc = w.ipc || {};
    if (ipc.mapped === false || ipc.hidden === true) continue;
    const maximized = typeof ipc.fullscreen === "number" ? (ipc.fullscreen & 1) !== 0
      : ipc.fullscreen === true && ipc.fullscreenMode === 1;
    if (w.floating && !maximized) continue;
    if (!Array.isArray(w.at) || !Array.isArray(w.size)) continue;
    const values = [w.at[0], w.at[1], w.size[0], w.size[1]];
    if (!values.every(v => typeof v === "number" && isFinite(v)) || w.size[0] <= 0 || w.size[1] <= 0) continue;
    const r = { left: Math.max(x, w.at[0] - s), top: Math.max(y, w.at[1] - s),
      right: Math.min(right, w.at[0] + w.size[0] + s), bottom: Math.min(bottom, w.at[1] + w.size[1] + s) };
    if (r.right <= r.left || r.bottom <= r.top) continue;
    rects.push(r);
    cuts.push(r.left, r.right);
  }
  // Sweep the union, not the sum of client areas: overlap cannot hide a gap.
  cuts.sort((a, b) => a - b);
  for (let i = 1; i < cuts.length; i++) {
    if (cuts[i] === cuts[i - 1]) continue;
    const spans = rects.filter(r => r.left <= cuts[i - 1] && r.right >= cuts[i]);
    spans.sort((a, b) => a.top - b.top);
    let coveredTo = y;
    for (let j = 0; j < spans.length; j++) {
      if (spans[j].top > coveredTo) return false;
      coveredTo = Math.max(coveredTo, spans[j].bottom);
    }
    if (coveredTo < bottom) return false;
  }
  return true;
}

// Canvas's font parser consumes a CSS family list. Do not wrap the entire
// configured name/list in quotes (Qt can treat those quotes as family data).
// Resolve against installed families once, preserving multiword names, and
// keep a generic fallback when the configured face is absent.
export function canvasFamily(requested, installed) {
  const choices = String(requested || "").split(",");
  // Qt may expose a QStringList as an array-like sequence rather than Array.
  const families = installed && typeof installed.length === "number" ? installed : [];
  for (let i = 0; i < choices.length; i++) {
    const choice = choices[i].trim().replace(/^["']|["']$/g, "");
    for (let j = 0; j < families.length; j++) {
      const family = families[j];
      if (family.toLowerCase() === choice.toLowerCase() && !/[,'";\\\n\r]/.test(family))
        return family + ", monospace";
    }
  }
  return "monospace";
}
