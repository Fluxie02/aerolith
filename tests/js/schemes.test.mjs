import { suite } from "./harness.mjs";
import { SCHEMES, DEFAULT_SCHEME, schemeById, paletteForScheme } from "../../shell/lib/schemes.mjs";
import { contrast, resolvePalette, OPACITY } from "../../shell/lib/tokens.mjs";
import { schemaAt, defaultsOf, SCHEMA, setPath, validateConfig } from "../../shell/lib/config.mjs";

export function composite(fg, bg, alpha) {
  let out = "#";
  for (let i = 1; i < 7; i += 2) {
    const n = Math.round(parseInt(fg.slice(i, i + 2), 16) * alpha + parseInt(bg.slice(i, i + 2), 16) * (1 - alpha)).toString(16);
    out += n.length === 1 ? "0" + n : n;
  }
  return out;
}

// Actual opaque, translucent and selected shell surfaces; also PIYTI's edge,
// inverse selection specimen and the independently drawn keyboard cursor.
export function contrastCases(scheme) {
  const p = scheme.palette;
  const surfaces = [
    ["field", p.obsidian], ["plane", p.surface], ["selection", p.surface2],
    ["plane over white desktop", composite(p.surface, "#ffffff", OPACITY.panel)],
    ["confirmation", composite(p.caution, p.surface, .12)],
    ["navigator selection", composite(p.signal, p.obsidian, .15)]
  ];
  const roles = ["text", "textDim", "signal", "caution", "critical", "nominal"];
  const out = [];
  for (let i = 0; i < roles.length; i++)
    for (let j = 0; j < surfaces.length; j++)
      out.push({ pair: roles[i] + " / " + surfaces[j][0], ratio: contrast(p[roles[i]], surfaces[j][1]), minimum: 4.5 });
  for (let i = 0; i < surfaces.length; i++)
    out.push({ pair: "PIYTI edge / " + surfaces[i][0], ratio: contrast(scheme.link, surfaces[i][1]), minimum: 4.5 });
  out.push({ pair: "inverse selection", ratio: contrast(p.obsidian, p.signal), minimum: 4.5 });
  out.push({ pair: "focus rim / selection", ratio: contrast(p.signal, p.surface2), minimum: 3 });
  out.push({ pair: "cursor / field", ratio: contrast(p.text, p.obsidian), minimum: 3 });
  return out;
}

export default suite("schemes", test => {
  test("schema accepts exactly the catalog, defaults safely and persists choices", assert => {
    const ids = SCHEMES.map(s => s.id);
    assert.deepEqual(schemaAt("theme.scheme").values, ids);
    assert.equal(defaultsOf(SCHEMA).theme.scheme, DEFAULT_SCHEME);
    assert.equal(validateConfig('{"theme":{"scheme":"missing"}}').config.theme.scheme, DEFAULT_SCHEME);
    for (let i = 0; i < ids.length; i++) {
      const saved = setPath({ theme: { intensity: "insane", palette: { signal: "#ffffff" } } }, "theme.scheme", ids[i]);
      assert.ok(!saved.error);
      const loaded = validateConfig(JSON.stringify(saved.raw));
      assert.equal(loaded.config.theme.scheme, ids[i]);
      assert.equal(loaded.config.theme.intensity, "insane");
      assert.equal(loaded.config.theme.palette.signal, "#ffffff");
    }
  });
  test("unknown schemes fall back and overrides preserve known role semantics", assert => {
    assert.equal(schemeById("missing").id, DEFAULT_SCHEME);
    const copy = paletteForScheme("iris");
    copy.signal = "#000000";
    assert.ok(paletteForScheme("iris").signal !== copy.signal);
    const p = resolvePalette({ signal: "#ffffff", grid: "invalid", unknown: "#ffffff" }, "iris");
    assert.equal(p.signal, "#ffffff");
    assert.equal(p.grid, schemeById("iris").palette.grid);
    assert.equal(p.unknown, undefined);
    assert.equal(p.critical, schemeById("limb").palette.critical);
  });
  for (let i = 0; i < SCHEMES.length; i++) {
    const s = SCHEMES[i];
    test(s.name + ": readable text, selection, PIYTI edges and focus", assert => {
      const cases = contrastCases(s);
      for (let j = 0; j < cases.length; j++) {
        const c = cases[j];
        assert.ok(c.ratio >= c.minimum, s.name + ": " + c.pair + " = " + c.ratio.toFixed(3));
      }
    });
  }
});
