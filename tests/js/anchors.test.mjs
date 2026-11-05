import { suite, runAll } from "./harness.mjs";
import * as A from "../../shell/lib/anchors.mjs";
const rect = { x: 10, y: 20, width: 30, height: 40 };
const anchors = suite("anchors", test => {
    test("isolates each output and named target", a => {
        let s = A.claim({}, "DP-1", "hatch", 1);
        s = A.update(s, "DP-1", "hatch", 1, rect);
        s = A.claim(s, "DP-2", "hatch", 2);
        s = A.update(s, "DP-2", "hatch", 2, Object.assign({}, rect, { x: 50 }));
        a.deepEqual(A.lookup(s, "DP-1", "hatch"), rect);
        a.equal(A.lookup(s, "DP-2", "hatch").x, 50);
        a.equal(A.lookup(s, "DP-1", "apps"), null);
    });
    test("old Loader layout and destruction cannot affect replacement, even while hidden", a => {
        let s = A.update(A.claim({}, "DP-1", "ring", 1), "DP-1", "ring", 1, rect);
        s = A.claim(s, "DP-1", "ring", 2);
        a.equal(A.lookup(s, "DP-1", "ring"), null);
        a.equal(A.update(s, "DP-1", "ring", 1, rect), s);
        a.equal(A.release(s, "DP-1", "ring", 1), s);
        s = A.update(s, "DP-1", "ring", 2, rect);
        a.deepEqual(A.lookup(s, "DP-1", "ring"), rect);
        a.deepEqual(A.release(s, "DP-1", "ring", 2), {});
        a.equal(A.update({}, "DP-1", "ring", 2, rect)[A.key("DP-1", "ring")], undefined);
    });
    test("hidden/missing target has no rectangle; can remap with the same lease", a => {
        let s = A.update(A.claim({}, "DP-1", "apps", 1), "DP-1", "apps", 1, rect);
        s = A.update(s, "DP-1", "apps", 1, null);
        a.equal(A.lookup(s, "DP-1", "apps"), null);
        s = A.update(s, "DP-1", "apps", 1, rect);
        a.deepEqual(A.lookup(s, "DP-1", "apps"), rect);
    });
    test("maps only via explicit output-local surface origin, including bottom strip", a => {
        a.deepEqual(A.outputRect(rect, { x: 0, y: 1042 }), { x: 10, y: 1062, width: 30, height: 40 });
        a.deepEqual(A.outputRect(rect, { x: 0, y: 1402 }), { x: 10, y: 1422, width: 30, height: 40 });
        a.deepEqual(A.outputRect(rect, { x: 0, y: 0 }), rect);
    });
    test("rejects invalid or zero geometry", a => {
        for (const r of [null, {}, Object.assign({}, rect, { width: 0 }), Object.assign({}, rect, { height: -1 }), Object.assign({}, rect, { x: NaN }), Object.assign({}, rect, { y: Infinity })])
            a.equal(A.outputRect(r, { x: 0, y: 0 }), null);
        a.equal(A.outputRect(rect, { x: NaN, y: 0 }), null);
    });
    test("owns scalar copies, preserves inputs, and skips identical layout events", a => {
        const initial = A.claim({}, "DP-1", "strip", 1);
        const input = Object.assign({}, rect);
        const next = A.update(initial, "DP-1", "strip", 1, input);
        a.equal(A.lookup(initial, "DP-1", "strip"), null);
        input.x = 999;
        a.deepEqual(A.lookup(next, "DP-1", "strip"), rect);
        a.equal(A.update(next, "DP-1", "strip", 1, rect), next);
        a.ok(JSON.stringify(next).indexOf("generation") >= 0);
    });
    test("keys cannot collide through separators or prototype names", a => {
        a.ok(A.key("a/b", "c") !== A.key("a", "b/c"));
        const s = A.update(A.claim({}, "__proto__", "constructor", 1), "__proto__", "constructor", 1, rect);
        a.deepEqual(A.lookup(s, "__proto__", "constructor"), rect);
    });
});
export default anchors;
if (typeof process !== "undefined" && /(?:^|\/)anchors\.test\.mjs$/.test(process.argv[1] || ""))
    runAll([anchors], line => console.log(line)).then(r => { process.exitCode = r.failed ? 1 : 0; });
