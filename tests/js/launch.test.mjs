import { suite } from "./harness.mjs";
import { buildLaunchArgv, detectTerminal, recordUse, usageScore } from "../../shell/lib/launch.mjs";
import { PALETTE, contrast, MIN_TEXT_CONTRAST, resolvePalette, densityTokens, motionTokens, fontFamilyList } from "../../shell/lib/tokens.mjs";

export default suite("launch", (test) => {
  test("strips desktop-entry field codes", (assert) => {
    assert.deepEqual(buildLaunchArgv({ command: ["firefox", "%u"] }, {}).argv, ["firefox"]);
    assert.deepEqual(buildLaunchArgv({ command: ["gimp", "%F", "--new"] }, {}).argv, ["gimp", "--new"]);
  });

  test("terminal applications need a terminal", (assert) => {
    assert.match(buildLaunchArgv({ command: ["htop"], runInTerminal: true }, {}).error, /terminal/);
    assert.deepEqual(buildLaunchArgv({ command: ["htop"], runInTerminal: true }, { terminal: ["kitty", "-e"] }).argv, ["kitty", "-e", "htop"]);
  });

  test("launch prefix wraps everything", (assert) => {
    const r = buildLaunchArgv({ command: ["htop"], runInTerminal: true }, { terminal: ["foot"], prefix: ["uwsm", "app", "--"] });
    assert.deepEqual(r.argv, ["uwsm", "app", "--", "foot", "htop"]);
  });

  test("empty commands are an error, not a silent no-op", (assert) => {
    assert.ok(buildLaunchArgv({ command: [] }, {}).error);
    assert.ok(buildLaunchArgv(null, {}).error);
  });

  test("terminal detection respects preference order", (assert) => {
    assert.deepEqual(detectTerminal((n) => n === "kitty" || n === "xterm"), ["kitty", "-e"]);
    assert.equal(detectTerminal(() => false), null);
  });

  test("frecency rewards recent and frequent use, and decays", (assert) => {
    const day = 24 * 3600 * 1000;
    let t = {};
    t = recordUse(t, "a", 0);
    t = recordUse(t, "a", 1000);
    t = recordUse(t, "b", 1000);
    assert.ok(usageScore(t, "a", 2000) > usageScore(t, "b", 2000));
    assert.ok(usageScore(t, "a", 2000) > usageScore(t, "a", 60 * day), "decays over time");
    assert.equal(usageScore(t, "never", 0), 0);
  });

  test("usage table is pruned to a bound", (assert) => {
    let t = {};
    for (let i = 0; i < 50; i++) t = recordUse(t, "k" + i, i, 10);
    assert.equal(Object.keys(t).length, 10);
    assert.ok(t.k49, "most recent survives");
  });
});

export const tokensSuite = suite("tokens", (test) => {
  test("text colours meet WCAG AA contrast on both surfaces", (assert) => {
    const fg = ["text", "textDim", "signal", "caution", "critical", "nominal"];
    const bg = ["obsidian", "surface", "surface2"];
    for (let i = 0; i < fg.length; i++)
      for (let k = 0; k < bg.length; k++) {
        const c = contrast(PALETTE[fg[i]], PALETTE[bg[k]]);
        assert.ok(c >= MIN_TEXT_CONTRAST, fg[i] + " on " + bg[k] + " contrast " + c.toFixed(2));
      }
  });

  test("palette overrides accept only known keys and valid colours", (assert) => {
    const p = resolvePalette({ signal: "#00ff00", bogus: "#ffffff", caution: "red" });
    assert.equal(p.signal, "#00ff00");
    assert.equal(p.caution, PALETTE.caution);
    assert.equal(p.bogus, undefined);
  });

  test("unknown density and motion names fall back", (assert) => {
    assert.deepEqual(densityTokens("huge"), densityTokens("standard"));
    assert.equal(motionTokens("off").normal, 0);
    assert.equal(motionTokens("??").normal, motionTokens("full").normal);
  });

  test("font lists deduplicate", (assert) => {
    assert.deepEqual(fontFamilyList("Inter", ["Inter", "Noto Sans", ""]), ["Inter", "Noto Sans"]);
  });
});
