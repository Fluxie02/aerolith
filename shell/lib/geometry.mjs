// Output-local coordinates. UI scale classifies the available work area;
// density sizes content but never supplies another compact breakpoint.
export function workArea(width, height, scale, stripHeight) {
    const w = width / scale, h = Math.max(0, height - stripHeight) / scale;
    return { width: w, height: h, compact: w < 1500 || h < 850,
        portrait: h > w, ultrawide: w > h * 2 };
}

export function ground(width, height, unit, stripHeight, bottom, scale = 1, gap = 6) {
    const du = n => Math.round(n * unit);
    const px = n => Math.round(n * scale);
    const area = workArea(width, height, scale, stripHeight);
    const hatchWidth = Math.min(width * .18, du(360));
    const apertureHeight = Math.min(height * .34, du(380));
    const apertureY = du(28);
    const hatchY = height * .49 - apertureHeight / 2 - apertureY;
    const appHeight = du(48);
    const apps = { x: width * .055, y: height - appHeight - du(16) - (bottom ? stripHeight : 0),
        width: area.ultrawide ? Math.min(width * .885, px(1120)) : width * .885, height: appHeight };
    const bearings = [
        { x: width * .055, y: height * .22, width: width * .16, height: du(11) },
        { x: width * .72, y: height * .79, width: width * .16, height: du(11) },
        { x: width * .49, y: height * .105, width: width * .12, height: du(11) }
    ];
    return {
        width: width, height: height, unit: unit,
        cx: width * .27, cy: height * .55,
        ringRadius: area.portrait ? Math.min(height * .34, width * .24) : height * .34,
        stationRadius: height * .29,
        compact: area.compact,
        // Include the station's projecting registration marks in the clearance.
        stationRowY: Math.max((bottom ? 0 : stripHeight) + 2 * gap + du(4) + du(56) / 2,
            Math.min(height - du(125), apps.y - 2 * gap - du(4) - du(56) / 2)),
        instrumentWidth: area.ultrawide ? Math.min(width * .25, px(420)) : width * .25,
        windows: { x: width * .70, y: height * .66,
            width: area.ultrawide ? Math.min(width * .24, px(420)) : width * .24,
            height: Math.max(0, bearings[1].y - 2 * gap - height * .66) },
        bearings: bearings,
        hatch: { x: width * .59 - hatchWidth / 2, y: hatchY,
            width: hatchWidth, height: apertureY + apertureHeight + du(88) },
        apertureY: apertureY, apertureHeight: apertureHeight,
        apps: apps
    };
}

export function station(g, index, count) {
    const du = n => Math.round(n * g.unit);
    const angle = -.92 + index * 1.84 / Math.max(1, count - 1);
    return {
        x: g.compact ? g.width * (.055 + .47 * (index + .5) / count) : g.cx + Math.sin(angle) * g.stationRadius,
        y: g.compact ? g.stationRowY : g.cy + Math.cos(angle) * g.stationRadius,
        width: Math.min(du(76), g.width * .47 / count - du(6)), height: du(56)
    };
}

// Preserve the configured stations' spacing within the configured arc.
// One overflow station counts every remaining id. The strip can scroll
// through the entire same ordered set.
export function orbitStations(cells, configured, geometry) {
    const base = Math.max(1, configured);
    // Keep the existing slot budget and spacing. Fit policy can reduce this
    // budget later without changing the ordered set or dropping live ids.
    const slots = Math.min(cells.length, base);
    const overflow = cells.length > slots;
    const result = [];
    for (let i = 0; i < slots; i++) {
        const first = overflow && i === slots - 1 ? i : -1;
        const cell = cells[i];
        const position = station(geometry, i, base);
        result.push({ id: first < 0 ? cell.id : 0, x: position.x, y: position.y,
            width: position.width, height: position.height,
            overflow: first < 0 ? [] : cells.slice(first).map(w => w.id) });
    }
    return result;
}

export function workspaceCells(configured, workspaces, focused) {
    const known = {};
    let highest = Math.max(1, configured);
    for (const w of workspaces) {
        if (!Number.isInteger(w.id) || w.id <= 0) continue;
        known[w.id] = w;
        highest = Math.max(highest, w.id);
    }
    const cells = [];
    for (let id = 1; id <= highest; id++) {
        const w = known[id];
        cells.push({ id: id, windows: w ? w.windows : 0,
            focused: id === focused, urgent: w ? w.urgent : false });
    }
    return cells;
}

// Bounding rectangle of actual laid-out station Items, in their common parent.
export function bounds(rects) {
    if (!rects.length) return { x: 0, y: 0, width: 0, height: 0 };
    let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
    for (const r of rects) {
        left = Math.min(left, r.x); top = Math.min(top, r.y);
        right = Math.max(right, r.x + r.width); bottom = Math.max(bottom, r.y + r.height);
    }
    return { x: left, y: top, width: right - left, height: bottom - top };
}
