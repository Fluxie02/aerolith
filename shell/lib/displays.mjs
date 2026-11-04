// Pure output policy. Screen objects stay opaque (and retain their identity).
// Only Qt screens can host surfaces: stale/unmatched Hyprland monitors never
// create outputs. A one-screen/one-monitor name mismatch remains compatible
// with older compositors and the single-output harness.
export function settingsFor(display, name, globals) {
  const map = display && display.outputs;
  const cfg = map && Object.prototype.hasOwnProperty.call(map, name) ? map[name] : null;
  const c = cfg && typeof cfg === "object" ? cfg : {};
  return {
    strip: (!globals || !globals.strip || globals.strip.visible !== false) && c.strip !== false,
    ground: (!globals || !globals.ground || globals.ground.enabled !== false) && c.ground !== false,
    profile: c.profile === "oled" ? "oled" : "standard",
  };
}

export function joinOutputs(screens, monitors, display, globals) {
  const list = screens || [];
  const mons = monitors || [];
  return list.map(screen => {
    let monitor = null;
    for (let i = 0; i < mons.length; i++)
      if (mons[i].name === screen.name) { monitor = mons[i]; break; }
    if (!monitor && list.length === 1 && mons.length === 1) monitor = mons[0];
    return Object.assign({
      name: screen.name, screen: screen,
      monitorName: monitor ? monitor.name : "",
      id: monitor && typeof monitor.id === "number" ? monitor.id : null,
      scale: monitor ? monitor.scale : screen.devicePixelRatio,
      refresh: monitor && typeof monitor.refreshRate === "number" ? monitor.refreshRate : null,
      focused: !!(monitor && monitor.focused),
    }, settingsFor(display, screen.name, globals));
  });
}

export function namedOutput(outputs, name) {
  if (!name) return null;
  for (let i = 0; i < outputs.length; i++)
    if (outputs[i].name === name || outputs[i].monitorName === name) return outputs[i];
  return null;
}

export function pickPrimary(outputs, display) {
  const cfg = display || {};
  const configured = namedOutput(outputs, cfg.primary) || namedOutput(outputs, cfg.output);
  if (configured) return configured;
  let first = null;
  for (let i = 0; i < outputs.length; i++)
    if (outputs[i].id !== null && (!first || outputs[i].id < first.id)) first = outputs[i];
  return first || outputs[0] || null;
}

export function resolveDisplays(screens, monitors, display, globals) {
  const cfg = display || {};
  const outputs = joinOutputs(screens, monitors, cfg, globals);
  const primary = pickPrimary(outputs, cfg);
  let focused = null;
  for (let i = 0; i < outputs.length; i++) if (outputs[i].focused) { focused = outputs[i]; break; }
  focused = focused || primary;
  const overlay = cfg.overlayOn === "primary" ? primary : focused;
  const notices = cfg.noticesOn === "focused" ? focused
    : cfg.noticesOn === "primary" || !cfg.noticesOn ? primary
    : namedOutput(outputs, cfg.noticesOn) || primary;
  return { outputs: outputs, primary: primary, focused: focused, overlay: overlay, notices: notices };
}

// Screen identity matters across unplug/replug; do not dereference a stale
// Qt wrapper, even when its replacement has the same connector name.
export function liveScreen(screens, screen) {
  return (screens || []).indexOf(screen) >= 0 ? screen : null;
}
