export function stateLabel(connected, connecting) {
  return connected ? "connected" : connecting ? "connecting" : "disconnected";
}

export function sortDevices(rows) {
  return rows.slice().sort((a, b) => Number(!!b.connected) - Number(!!a.connected)
    || Number(!!b.paired) - Number(!!a.paired) || a.name.localeCompare(b.name)
    || a.address.localeCompare(b.address));
}

export function connectedCount(rows) {
  return rows.filter(d => stateLabel(d.connected, d.connecting) === "connected").length;
}

export function batteryPercent(available, value) {
  return available && typeof value === "number" && isFinite(value)
    ? Math.round(Math.max(0, Math.min(1, value)) * 100) : -1;
}
