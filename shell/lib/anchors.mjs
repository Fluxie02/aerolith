// Immutable scalar records only. A new lease replaces the old generation even
// while hidden, so delayed layout/destruction from an old Loader cannot win.
export function key(output, name) { return JSON.stringify([output, name]); }
export function claim(state, output, name, generation) {
    const next = Object.assign({}, state);
    next[key(output, name)] = { generation: generation, rect: null };
    return next;
}
export function outputRect(rect, origin) {
    if (!rect || !origin || ![rect.x, rect.y, rect.width, rect.height, origin.x, origin.y].every(Number.isFinite)
        || rect.width <= 0 || rect.height <= 0) return null;
    return { x: rect.x + origin.x, y: rect.y + origin.y, width: rect.width, height: rect.height };
}
export function update(state, output, name, generation, rect) {
    const k = key(output, name), old = state[k];
    if (!old || old.generation !== generation) return state;
    const value = rect ? outputRect(rect, { x: 0, y: 0 }) : null;
    if (JSON.stringify(old.rect) === JSON.stringify(value)) return state;
    const next = Object.assign({}, state);
    next[k] = { generation: generation, rect: value };
    return next;
}
export function release(state, output, name, generation) {
    const k = key(output, name);
    if (!state[k] || state[k].generation !== generation) return state;
    const next = Object.assign({}, state);
    delete next[k];
    return next;
}
export function lookup(state, output, name) {
    const entry = state[key(output, name)];
    return entry ? entry.rect : null;
}
