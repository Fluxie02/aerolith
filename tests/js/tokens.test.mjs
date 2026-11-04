import { suite } from "./harness.mjs";
import { SCHEMES, paletteForScheme } from "../../shell/lib/schemes.mjs";
import { PALETTE, MIN_TEXT_CONTRAST, contrast, luminance, oledPalette, resolvePalette } from "../../shell/lib/tokens.mjs";

const foregrounds = ["text", "textDim", "signal", "caution", "critical", "nominal"];
const backgrounds = ["obsidian", "surface", "surface2"];

function assertReadable(assert, p) {
  for (let i = 0; i < foregrounds.length; i++)
    for (let j = 0; j < backgrounds.length; j++) {
      const ratio = contrast(p[foregrounds[i]], p[backgrounds[j]]);
      assert.ok(ratio >= MIN_TEXT_CONTRAST, foregrounds[i] + " / " + backgrounds[j] + " = " + ratio);
    }
}

// Call from a Quickshell scratch harness with a real DisplayProfile and Idle.
// Kept here so the QML binding assertions can be reused after OLED-2 wiring.
export function checkQmlProfiles(assert, profile, other, theme, idle, config) {
  function standard() {
    assert.equal(profile.background.toString(), theme.bg.toString());
    const roles = ["surface", "surface2", "grid"].concat(foregrounds);
    for (let i = 0; i < roles.length; i++)
      assert.equal(profile[roles[i]].toString(), theme[roles[i]].toString(), roles[i]);
    assert.equal(profile.decorationOpacity, 1);
    assert.equal(profile.idleDim, 1);
    assert.equal(profile.palette, theme.palette);
  }
  assert.equal(profile.profile, "standard");
  standard();
  profile.output = "OLED-1";
  other.output = "LCD-1";
  profile.profile = "oled";
  const expected = oledPalette(theme.palette);
  assert.equal(profile.background.toString(), "#000000");
  assert.equal(profile.bg.toString(), profile.background.toString());
  const roles = ["surface", "surface2", "grid"].concat(foregrounds);
  for (let i = 0; i < roles.length; i++)
    assert.equal(profile[roles[i]].toString(), expected[roles[i]], roles[i]);
  assert.equal(profile.decorationOpacity, expected.decorationOpacity);
  assert.equal(profile.idleDim, expected.idleDim);
  assert.equal(other.background.toString(), theme.bg.toString(), "LCD remains standard");
  assert.equal(other.output, "LCD-1");
  const saved = config.data;
  const changed = JSON.parse(JSON.stringify(saved));
  changed.theme.scheme = "glacial";
  changed.theme.palette = { signal: "#ffffff", surface: "#112233" };
  config.data = changed;
  assert.equal(profile.surface.toString(), oledPalette(theme.palette).surface, "live theme update");
  assert.equal(profile.signal.toString(), oledPalette(theme.palette).signal, "live accent update");
  assert.equal(other.surface.toString(), theme.surface.toString(), "LCD follows standard theme");
  config.data = saved;
  profile.profile = "standard";
  standard();
  profile.profile = "invalid";
  standard();
  profile.profile = "standard";
  assert.equal(idle.timeout, 0, "monitoring defaults off");
  assert.equal(idle.idle, false);
  const disabled = [-1, NaN, Infinity];
  for (let i = 0; i < disabled.length; i++) {
    idle.timeout = disabled[i];
    assert.equal(idle.idle, false, "invalid timeout disables idle");
  }
  idle.timeout = 0;
}

export const oledTokensSuite = suite("oled tokens", test => {
  for (let i = 0; i < SCHEMES.length; i++) {
    const scheme = SCHEMES[i];
    test(scheme.id + ": black fill, separate planes, dimmer accents and AA contrast", assert => {
      const standard = resolvePalette({}, scheme.id);
      const snapshot = JSON.stringify(standard);
      const p = oledPalette(standard);
      assert.equal(p.obsidian, "#000000");
      assert.equal(p.background, "#000000");
      assert.ok(luminance(p.surface) > 0);
      assert.ok(luminance(p.surface2) > luminance(p.surface));
      assert.ok(luminance(p.surface) < luminance(standard.surface));
      assert.ok(luminance(p.surface2) < luminance(standard.surface2));
      assert.ok(luminance(p.grid) < luminance(standard.grid));
      for (let k = 2; k < foregrounds.length; k++)
        assert.ok(luminance(p[foregrounds[k]]) < luminance(standard[foregrounds[k]]), foregrounds[k] + " dims");
      assert.ok(p.decorationOpacity > 0 && p.decorationOpacity < 1);
      assert.ok(p.idleDim > 0 && p.idleDim < 1);
      assert.equal(p.text, standard.text);
      assert.equal(p.textDim, standard.textDim);
      assertReadable(assert, p);
      assert.equal(JSON.stringify(standard), snapshot, "input not mutated");
      assert.deepEqual(resolvePalette({}, scheme.id), paletteForScheme(scheme.id));
    });
  }

  test("custom dark foregrounds and black/bright/alpha fills remain readable and separate", assert => {
    const fills = ["#000000", "#ffffff", "#80ffffff"];
    for (let i = 0; i < fills.length; i++) {
      const overrides = { surface: fills[i], surface2: fills[i], grid: "#80ffffff" };
      for (let j = 0; j < foregrounds.length; j++) overrides[foregrounds[j]] = "#80000000";
      const standard = resolvePalette(overrides);
      const snapshot = JSON.stringify(standard);
      const p = oledPalette(standard);
      assertReadable(assert, p);
      assert.ok(luminance(p.surface) > 0);
      assert.ok(luminance(p.surface2) > luminance(p.surface));
      for (const role in p)
        if (typeof p[role] === "string") assert.match(p[role], /^#[0-9a-f]{6}$/);
      assert.equal(JSON.stringify(standard), snapshot);
    }
  });

  test("options bound opacity multipliers and do not change standard resolution", assert => {
    const before = JSON.stringify(PALETTE);
    const defaults = oledPalette(PALETTE);
    const custom = oledPalette(PALETTE, { decorationOpacity: 0.2, idleDim: 0.4 });
    assert.equal(custom.decorationOpacity, 0.2);
    assert.equal(custom.idleDim, 0.4);
    const bounded = oledPalette(PALETTE, { decorationOpacity: -1, idleDim: 2 });
    assert.equal(bounded.decorationOpacity, 0);
    assert.equal(bounded.idleDim, 1);
    const invalid = oledPalette(PALETTE, { decorationOpacity: NaN, idleDim: "0.4" });
    assert.equal(invalid.decorationOpacity, defaults.decorationOpacity);
    assert.equal(invalid.idleDim, defaults.idleDim);
    assert.equal(oledPalette(PALETTE, { idleDim: Infinity }).idleDim, defaults.idleDim);
    assert.deepEqual(resolvePalette(), PALETTE);
    assert.equal(JSON.stringify(PALETTE), before);
  });
});

export default oledTokensSuite;
