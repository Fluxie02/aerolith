import { suite, runAll } from "./harness.mjs";
import * as G from "../../shell/lib/geometry.mjs";

const geometry = suite("geometry", test => {
    test("ground and stations exactly preserve the old equations and density rounding", a => {
        for (const [w, h] of [[1920, 1080], [3840 / 1.5, 2160 / 1.5], [1280, 720]]) {
            for (const unit of [1, .92, 1.08, 1.5, 1.38, 1.62]) {
                const du = n => Math.round(n * unit);
                for (const bottom of [false, true]) {
                    const g = G.ground(w, h, unit, 38, bottom);
                    const hw = Math.min(w * .18, du(360)), ah = Math.min(h * .34, du(380));
                    a.deepEqual(g.hatch, { x: w * .59 - hw / 2, y: h * .49 - ah / 2 - du(28),
                        width: hw, height: du(28) + ah + du(88) });
                    a.deepEqual(g.apps, { x: w * .055, y: h - du(48) - du(16) - (bottom ? 38 : 0),
                        width: w * .885, height: du(48) });
                    a.equal(g.cx, w * .27); a.equal(g.cy, h * .55);
                    a.equal(g.ringRadius, h * .34); a.equal(g.stationRadius, h * .29);
                    for (const count of [1, 5, 20]) for (let i = 0; i < count; i++) {
                        const compact = w < du(1500) || h < du(850);
                        a.deepEqual(G.station(w, h, unit, i, count), {
                            x: compact ? w * (.055 + .47 * (i + .5) / count)
                                : w * .27 + Math.sin(-.92 + i * 1.84 / Math.max(1, count - 1)) * (h * .29),
                            y: compact ? h - du(125)
                                : h * .55 + Math.cos(-.92 + i * 1.84 / Math.max(1, count - 1)) * (h * .29),
                            width: Math.min(du(76), w * .47 / count - du(6)), height: du(56)
                        });
                    }
                }
            }
        }
    });
    test("default stations retain every position and size at 1080p and scaled 4K", a => {
        for (const [w, h] of [[1920, 1080], [2560, 1440]]) {
            const stations = G.orbitStations(G.workspaceCells(5, [], 1), 5, w, h, 1);
            a.equal(stations.length, 5);
            stations.forEach((s, i) => {
                a.deepEqual(s, Object.assign({ id: i + 1 }, G.station(w, h, 1, i, 5), { overflow: [] }));
            });
        }
    });
    test("shared ordered range includes higher live ids beyond the former strip cap", a => {
        const cells = G.workspaceCells(5, [{ id: 33, windows: 2, urgent: true }, { id: -99 }, { id: 2, windows: 1 }], 33);
        a.deepEqual(cells.map(w => w.id), Array.from({ length: 33 }, (_, i) => i + 1));
        a.deepEqual(cells[32], { id: 33, windows: 2, urgent: true, focused: true });
        a.equal(cells[4].windows, 0);
        a.equal(cells[1].windows, 1);
    });
    test("overflow represents every workspace once without changing retained station spacing", a => {
        for (const [w, h] of [[1920, 1080], [2560, 1440], [800, 600]]) {
            for (const configured of [1, 5, 20]) {
                const cells = G.workspaceCells(configured, [{ id: 33, windows: 1 }], 33);
                const stations = G.orbitStations(cells, configured, w, h, 1);
                const ids = [];
                let overflow = 0;
                stations.forEach((s, i) => {
                    a.equal(s.x, G.station(w, h, 1, i, configured).x);
                    a.equal(s.y, G.station(w, h, 1, i, configured).y);
                    if (s.overflow.length) { overflow++; ids.push.apply(ids, s.overflow); }
                    else ids.push(s.id);
                });
                a.equal(overflow, 1);
                a.deepEqual(ids, cells.map(c => c.id));
                a.ok(stations[stations.length - 1].overflow.indexOf(33) >= 0);
            }
        }
    });
    test("workspace removal shrinks to configured range and ignores special/invalid ids", a => {
        a.equal(G.workspaceCells(5, [{ id: -1 }, { id: 0 }, { id: 1.5 }, { id: "40" }], 1).length, 5);
        a.equal(G.workspaceCells(5, [], 1).length, 5);
    });
    test("bounds cover actual items including negative origins and nonuniform sizes", a => {
        a.deepEqual(G.bounds([]), { x: 0, y: 0, width: 0, height: 0 });
        a.deepEqual(G.bounds([{ x: -4, y: 8, width: 10, height: 20 }, { x: 30, y: -2, width: 5, height: 7 }]),
            { x: -4, y: -2, width: 39, height: 30 });
    });
});
export default geometry;
if (typeof process !== "undefined" && /(?:^|\/)geometry\.test\.mjs$/.test(process.argv[1] || ""))
    runAll([geometry], line => console.log(line)).then(r => { process.exitCode = r.failed ? 1 : 0; });
