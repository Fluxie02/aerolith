// Fullscreen detection and the shell's lifecycle state (roadmap B01).
//
// Hyprland reports a window's fullscreen state in its IPC client object. Since
// Hyprland 0.42 `fullscreen` is a mode bitmask: 1 = maximized, 2 = fullscreen
// (3 = both); a maximized window keeps the shell visible, so only the
// fullscreen bit counts. Older releases sent a boolean `fullscreen` with
// `fullscreenMode` 0 (fullscreen) or 1 (maximized). `fullscreenClient` is what
// the application asked for and is ignored: with fake fullscreen the
// compositor does not give it the output.
//
// The controller below turns the "is the selected output fullscreen" signal
// into phases that components subscribe to, instead of each one running its own
// detection:
//   desktop    everything mapped and animated
//   suspended  a qualifying fullscreen window owns the selected output; the
//              shell's visual surfaces are released
//   restoring  fullscreen just ended; surfaces are back but ambient motion is
//              held until they have settled, so nothing flashes or replays
// Entering waits enterDelayMs so a game toggling fullscreen while it starts
// does not tear the shell down repeatedly; leaving is immediate.
//
// Supported in Qt V4 and Node.js; see docs/RESEARCH.md for the JS subset.

export const DESKTOP = "desktop";
export const SUSPENDED = "suspended";
export const RESTORING = "restoring";

const FS_FULLSCREEN = 2;

// "fullscreen", "maximized" or "none" for one Hyprland client IPC object.
export function fullscreenMode(ipc) {
  if (!ipc || typeof ipc !== "object") return "none";
  const v = ipc.fullscreen;
  if (typeof v === "number") return v & FS_FULLSCREEN ? "fullscreen" : v ? "maximized" : "none";
  if (v === true) return ipc.fullscreenMode === 1 ? "maximized" : "fullscreen";
  return "none";
}

// snapshot: {
//   output: selected output name,
//   monitors: [{ name, activeWorkspaceId, specialWorkspaceId }],
//   clients: [{ address, workspaceId, ipc }]
// }
// Returns { fullscreen, address, appClass } for the window that owns the
// selected output, or fullscreen false. A shown special workspace sits on top
// of the fullscreen window, so the output is not considered taken then.
export function outputFullscreen(snapshot) {
  const none = { fullscreen: false, address: "", appClass: "" };
  if (!snapshot || !Array.isArray(snapshot.monitors) || !Array.isArray(snapshot.clients)) return none;
  let monitor = null;
  for (let i = 0; i < snapshot.monitors.length; i++)
    if (snapshot.monitors[i].name === snapshot.output) monitor = snapshot.monitors[i];
  if (!monitor && snapshot.monitors.length === 1) monitor = snapshot.monitors[0];
  if (!monitor || !(monitor.activeWorkspaceId > 0)) return none;
  if (monitor.specialWorkspaceId && monitor.specialWorkspaceId < 0) return none;
  for (let i = 0; i < snapshot.clients.length; i++) {
    const c = snapshot.clients[i];
    if (c.workspaceId !== monitor.activeWorkspaceId) continue;
    if (c.ipc && c.ipc.mapped === false) continue;
    if (fullscreenMode(c.ipc) === "fullscreen")
      return { fullscreen: true, address: String(c.address || ""), appClass: String((c.ipc && c.ipc["class"]) || "") };
  }
  return none;
}

// createLifecycle({ scheduler, enterDelayMs, restoreMs, onChange })
//   update(fullscreen)  feed the latest detection result (idempotent)
//   phase               current phase
//   onChange(phase, previous) is called after every transition.
export function createLifecycle(options) {
  const scheduler = options.scheduler;
  const enterDelayMs = options.enterDelayMs === undefined ? 400 : options.enterDelayMs;
  const restoreMs = options.restoreMs === undefined ? 300 : options.restoreMs;
  const onChange = options.onChange || function () {};
  let phase = DESKTOP;
  let pending = null;
  let target = "";

  function cancel() {
    if (pending !== null) scheduler.clearTimeout(pending);
    pending = null;
    target = "";
  }
  function go(next) {
    if (next === phase) return;
    const previous = phase;
    phase = next;
    onChange(phase, previous);
  }
  function later(ms, next) {
    cancel();
    target = next;
    pending = scheduler.setTimeout(() => {
      pending = null;
      target = "";
      go(next);
    }, ms);
  }

  return {
    get phase() {
      return phase;
    },
    update(fullscreen) {
      if (fullscreen) {
        if (phase !== SUSPENDED && target !== SUSPENDED) later(enterDelayMs, SUSPENDED);
      } else if (phase === SUSPENDED) {
        go(RESTORING);
        later(restoreMs, DESKTOP);
      } else if (target === SUSPENDED) {
        // A fullscreen flap shorter than the enter delay: never suspend.
        if (phase === RESTORING) later(restoreMs, DESKTOP);
        else cancel();
      }
    },
    dispose() {
      cancel();
    },
  };
}
