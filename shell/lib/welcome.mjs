// Welcome policy and reporting. Pure JavaScript shared by QML and both runners.
export const VERSION = 1;
export const DOCS = [
  { id: "readme", title: "Getting started", relative: "README.md" },
  { id: "alpha", title: "Troubleshooting", relative: "docs/ALPHA.md" },
  { id: "configuration", title: "Configuration", relative: "docs/CONFIGURATION.md" },
  { id: "commands", title: "Commands", relative: "docs/COMMANDS.md" },
];
export function readRecord(record) {
  const r = record && record.version === VERSION ? record : {};
  return { version: VERSION, tourFinished: typeof r.tourFinished === "boolean" ? r.tourFinished : null, seen: r.seen === true, handedOff: r.handedOff === true,
    tourStep: Number.isInteger(r.tourStep) && r.tourStep >= 0 && r.tourStep < 5 ? r.tourStep : 0 };
}
export function firstRunPending(ready, hadState, record, tour) {
  return !!ready && !hadState && !readRecord(record).seen && !(tour && tour.completed === true);
}
export function mayShow(context) {
  return !!(context.ready && context.output && !context.locked && !context.fullscreen);
}
export function checklist(context) {
  const c = context;
  return [
    { id: "config", label: "Configuration", state: !c.configLoaded ? "unknown"
      : c.fileBroken || c.configErrors.length ? "attention" : c.fileMissing ? "unknown" : "passed",
      detail: !c.configLoaded ? "Unavailable" : c.fileBroken || c.configErrors.length ? "Fix configuration errors"
        : c.fileMissing ? "No config file; using defaults" : "Configuration parses without errors", action: "shell.open.settings" },
    { id: "output", label: "Primary display", state: !c.outputsReady ? "unknown" : c.primary ? "passed" : "attention",
      detail: !c.outputsReady ? "Unavailable" : c.primary ? c.primary.name : "No resolved primary display", action: "shell.open.settings" },
    { id: "startup", label: "Launch on startup", state: c.startup.enabled === true && !!c.startup.method ? "passed"
      : c.startup.enabled === false ? "attention" : "unknown",
      detail: c.startup.error || (c.startup.enabled === true ? "Enabled via " + c.startup.method
        : c.startup.enabled === false ? "Disabled" : "Unavailable"), action: "startup" },
    { id: "tour", label: "Desktop tour", state: c.tourCompleted === null ? "unknown" : c.tourCompleted ? "passed" : "attention",
      detail: c.tourCompleted === null ? "Legacy completion does not distinguish finishing from skipping" : c.tourCompleted ? "Finished" : "Not finished", action: "tour.start" },
  ];
}
export function diagnosticsResult(result) {
  try {
    const d = JSON.parse(result.stdout);
    if (!d || !Array.isArray(d.checks) || d.checks.some(c => !c || typeof c.name !== "string"
        || ["ok", "warn", "fail", "info"].indexOf(c.status) < 0 || typeof c.detail !== "string"))
      throw new Error("Invalid diagnostic response");
    if (result.timedOut || (result.code !== 0 && result.code !== 1)) throw new Error(result.stderr || "Diagnostics failed");
    return { running: false, ok: result.code === 0 && !d.checks.some(c => c.status === "fail"), checks: d.checks, error: null };
  } catch (e) {
    return { running: false, ok: null, checks: [], error: result.timedOut ? "Diagnostics timed out" : result.stderr || String(e) };
  }
}
export function report(info, diagnostics) {
  const value = v => v === null || v === undefined || v === "" ? "Unavailable" : String(v);
  const lines = ["AEROLITH report", "Installed AEROLITH: " + value(info.version.aerolith),
    "Quickshell: " + value(info.version.quickshell), "Hyprland: " + value(info.version.hyprland),
    "Dialect: " + value(info.dialect), "GPU: " + value(info.gpu), "Outputs:"];
  for (const o of info.outputs) lines.push("  " + o.name + ": " + value(o.mode) + ", scale " + value(o.scale) + ", " + value(o.profile));
  lines.push("Configuration errors: " + info.configErrors.length);
  for (const e of info.configErrors) lines.push("  " + e.path + ": " + e.message);
  lines.push("Configuration warnings: " + info.configWarnings.length);
  for (const w of info.configWarnings) lines.push("  " + w.path + ": " + w.message);
  lines.push("Diagnostics: " + (diagnostics.running ? "Running" : diagnostics.error || (diagnostics.ok === null ? "Not run" : diagnostics.ok ? "Passed" : "Attention")));
  for (const c of diagnostics.checks) lines.push("  " + c.status + " " + c.name + ": " + c.detail);
  return lines.join("\n") + "\n";
}
