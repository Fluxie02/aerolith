// Plain records only; QML owns backend objects and their lifetimes.
export function stateLabel(state) {
  return state === "connected" || state === "connecting" ? state : "disconnected";
}

export function compareNetworks(a, b) {
  return Number(!!b.connected) - Number(!!a.connected)
    || Number(!!b.known) - Number(!!a.known)
    || b.signal - a.signal || a.name.localeCompare(b.name);
}

export function sortNetworks(rows) {
  const seen = Object.create(null);
  return rows.filter(n => typeof n.name === "string" && n.name.length > 0)
    .slice().sort(compareNetworks).filter(n => {
      if (seen[n.name]) return false;
      seen[n.name] = true;
      return true;
    }).map(n => ({ name: n.name, signal: n.signal, secured: !!n.secured,
      known: !!n.known, connected: !!n.connected, connecting: !!n.connecting,
      failed: !!n.failed, failReason: n.failReason || "" }));
}

export function summary(available, devices) {
  const active = devices.filter(d => d.state === "connected" || d.state === "connecting")
    .slice().sort((a, b) => Number(b.state === "connected") - Number(a.state === "connected")
      || Number(b.kind === "ethernet") - Number(a.kind === "ethernet"))[0];
  if (!available || !active)
    return { kind: "none", state: available ? "disconnected" : "unavailable", connectionName: "", signal: -1 };
  return { kind: active.kind, state: stateLabel(active.state), connectionName: active.name || "",
    signal: active.kind === "wifi" ? active.signal : -1 };
}

export function percent(value) {
  return typeof value === "number" && isFinite(value) ? Math.round(Math.max(0, Math.min(1, value)) * 100) : 0;
}
