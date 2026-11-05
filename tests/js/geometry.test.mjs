import { suite, runAll } from "./harness.mjs";
import * as G from "../../shell/lib/geometry.mjs";

const geometry = suite("geometry", test => {
    test("workspace labels preserve IDs, empty/default labels, literal text and overflow membership", a => {
        const names = {1:"Writing",2:"",3:"<b>Plain</b>",33:"Long workspace name"};
        a.equal(G.workspaceLabel(1,names), "Writing");
        a.equal(G.workspaceLabel(2,names), "2");
        a.equal(G.workspaceLabel(2,names,true), "02");
        a.equal(G.workspaceLabel(3,names), "<b>Plain</b>");
        a.equal(G.workspaceLabel(5,{}), "5");
        a.equal(G.workspaceLabel(5,null,true), "05");
        a.equal(G.workspaceLabel(10,{},true), "10");
        const cells = G.workspaceCells(5,[{id:33,windows:1}],33);
        a.ok(cells.every(c => typeof c.id === "number"));
        const s = G.orbitStations(cells,5,G.ground(1920,1080,1,28,false));
        a.ok(s[4].overflow.indexOf(33) >= 0);
        a.equal(G.workspaceLabel(33,names), "Long workspace name");
    });
    test("text growth expands station and app containers without scaling ornament or spacing", a => {
        for (const factor of [1,1.12,1.25,1.5]) for (const unit of [.92,1,1.08,1.5]) for (const bottom of [false,true]) {
            const g = G.ground(1280,720,unit,34,bottom,1,8,factor);
            a.equal(g.apps.height,Math.round(48*unit*factor));
            a.equal(G.station(g,0,5).height,Math.round(56*unit*factor));
            a.equal(g.apps.y + g.apps.height,720-Math.round(16*unit)-(bottom?34:0));
            const s = G.station(g,0,5), mark = Math.round(4*unit);
            a.ok(s.y-s.height/2-mark >= (bottom?0:34)+16);
            a.ok(s.y+s.height/2+mark <= g.apps.y-16);
            const base = G.ground(1280,720,unit,34,bottom,1,8);
            a.deepEqual(g.hatch,base.hatch); a.deepEqual(g.bearings,base.bearings);
            a.equal(g.ringRadius,base.ringRadius); a.equal(g.instrumentWidth,base.instrumentWidth);
        }
    });
    test("one work-area classification uses UI scale and strip reservation, never density", a => {
        a.deepEqual(G.workArea(1500, 878, 1, 28),
            { width: 1500, height: 850, compact: false, portrait: false, ultrawide: false });
        a.equal(G.workArea(1499, 878, 1, 28).compact, true);
        a.equal(G.workArea(1500, 877, 1, 28).compact, true);
        a.equal(G.workArea(3000, 1756, 2, 56).compact, false);
        a.equal(G.workArea(3000, 1755, 2, 56).compact, true);
        a.equal(G.workArea(1500, 850, 1, 0).compact, false);
        for (const unit of [.92, 1, 1.08]) {
            a.equal(G.ground(1500, 878, unit, 28, false).compact, false);
            a.equal(G.ground(1499, 878, unit, 28, false).compact, true);
        }
    });
    test("16:9 hatch, app register, rings and default stations retain exact equations", a => {
        for (const [w, h] of [[1920, 1080], [3840 / 1.5, 2160 / 1.5]]) {
            for (const unit of [.92, 1, 1.08]) for (const bottom of [false, true]) {
                const du = n => Math.round(n * unit);
                const g = G.ground(w, h, unit, 28, bottom);
                const hw = Math.min(w * .18, du(360)), ah = Math.min(h * .34, du(380));
                a.deepEqual(g.hatch, { x: w * .59 - hw / 2, y: h * .49 - ah / 2 - du(28),
                    width: hw, height: du(28) + ah + du(88) });
                a.deepEqual(g.apps, { x: w * .055, y: h - du(48) - du(16) - (bottom ? 28 : 0),
                    width: w * .885, height: du(48) });
                a.equal(g.cx, w * .27); a.equal(g.cy, h * .55);
                a.equal(g.ringRadius, h * .34); a.equal(g.stationRadius, h * .29);
                a.equal(g.instrumentWidth, w * .25);
                for (let i = 0; i < 5; i++) a.deepEqual(G.station(g, i, 5), {
                    x: w * .27 + Math.sin(-.92 + i * 1.84 / 4) * (h * .29),
                    y: h * .55 + Math.cos(-.92 + i * 1.84 / 4) * (h * .29),
                    width: Math.min(du(76), w * .47 / 5 - du(6)), height: du(56)
                });
            }
        }
    });
    test("portrait uses an on-screen station row at both requested resolutions and every density", a => {
        for (const [w, h] of [[1080, 1920], [1440, 2560]]) for (const unit of [.92, 1, 1.08]) {
            const g = G.ground(w, h, unit, 34, false);
            a.equal(g.compact, true);
            a.ok(g.cx - g.ringRadius >= 0);
            a.ok(g.cx + g.ringRadius <= w);
            for (let i = 0; i < 5; i++) {
                const s = G.station(g, i, 5);
                a.equal(s.y, g.stationRowY);
                a.ok(s.x - s.width / 2 >= 0 && s.x + s.width / 2 <= w);
                a.ok(s.y - s.height / 2 >= 34 && s.y + s.height / 2 < h);
            }
        }
    });
    test("compact stations and projecting marks clear both strip edges and the app row by two gaps", a => {
        for (const [w, h] of [[1366, 768], [1280, 720], [1080, 1920], [1440, 2560]]) {
            for (const [density, strip, gap] of [[.92, 24, 4], [1, 28, 6], [1.08, 34, 8]]) {
                for (const scale of [.75, 1, 1.5, 2]) for (const bottom of [false, true]) {
                    const unit = scale * density, lane = Math.round(strip * scale), gutter = Math.round(gap * scale);
                    const g = G.ground(w, h, unit, lane, bottom, scale, gutter);
                    const s = G.station(g, 0, 5), mark = Math.round(4 * unit);
                    if (!g.compact) continue;
                    a.ok(s.y - s.height / 2 - mark >= (bottom ? 0 : lane) + 2 * gutter);
                    a.ok(s.y + s.height / 2 + mark <= h - (bottom ? lane : 0) - 2 * gutter);
                    a.ok(s.y + s.height / 2 + mark <= g.apps.y - 2 * gutter);
                }
            }
        }
    });
    test("ultrawide instruments cap before UI scale, ignore density and keep existing origins", a => {
        for (const w of [3440, 5120]) for (const scale of [.75, 1, 1.5, 2]) {
            for (const density of [.92, 1, 1.08]) {
                const g = G.ground(w, 1440, scale * density, 34, false, scale);
                a.equal(g.instrumentWidth, Math.round(420 * scale));
                a.equal(g.apps.width, Math.round(1120 * scale));
                a.equal(g.apps.x, w * .055);
                a.equal(g.windows.x, w * .70);
                a.equal(g.windows.width, Math.min(w * .24, Math.round(420 * scale)));
            }
        }
        a.equal(G.workArea(2000, 1000, 1, 0).ultrawide, false);
        a.equal(G.workArea(2001, 1000, 1, 0).ultrawide, true);
    });
    test("window register ends two gaps before the shared second bearing", a => {
        for (const [w, h] of [[1920, 1080], [2560, 1440], [3440, 1440], [5120, 1440]]) {
            for (const gap of [4, 6, 8, 12]) {
                const g = G.ground(w, h, 1, 28, false, 1, gap);
                a.equal(g.windows.y + g.windows.height, g.bearings[1].y - 2 * gap);
                a.deepEqual(g.bearings[1], { x: w * .72, y: h * .79, width: w * .16, height: 11 });
            }
        }
    });
    test("default stations retain every position and size at 1080p and scaled 4K", a => {
        for (const [w, h] of [[1920, 1080], [2560, 1440]]) {
            const g = G.ground(w, h, 1, 28, false);
            const stations = G.orbitStations(G.workspaceCells(5, [], 1), 5, g);
            a.equal(stations.length, 5);
            stations.forEach((s, i) => {
                a.deepEqual(s, Object.assign({ id: i + 1 }, G.station(g, i, 5), { overflow: [] }));
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
                const g = G.ground(w, h, 1, 28, false);
                const stations = G.orbitStations(cells, configured, g);
                const ids = [];
                let overflow = 0;
                stations.forEach((s, i) => {
                    a.equal(s.x, G.station(g, i, configured).x);
                    a.equal(s.y, G.station(g, i, configured).y);
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
