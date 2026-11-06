import assert from "node:assert/strict";
import { paletteError, pathOf } from "../../../shell/modules/settings/personalize.mjs";
import { SCHEMES } from "../../../shell/lib/schemes.mjs";
import { contrast, MIN_TEXT_CONTRAST } from "../../../shell/lib/tokens.mjs";

for (const scheme of SCHEMES) assert.equal(paletteError({}, scheme.id), "", scheme.id);
assert.match(paletteError({text: "#222222"}, "limb"), /text on normal.*requires 4\.5:1/);
// Sector's selected tile composites 15% white over #101010, yielding #343434.
// A guard checking only the housing's black surface misses this actual fill.
const raisedBackground = {obsidian: "#101010", surface: "#000000", surface2: "#000000",
  text: "#999999", textDim: "#959595", signal: "#ffffff", caution: "#959595",
  critical: "#959595", nominal: "#959595"};
assert.ok(contrast(raisedBackground.textDim, "#343434") < MIN_TEXT_CONTRAST);
const before = JSON.stringify(raisedBackground);
assert.match(paletteError(raisedBackground, "limb"), /navigator selected.*[0-9]+\.[0-9]{2}:1; requires 4\.5:1/);
assert.equal(JSON.stringify(raisedBackground), before);
const whiteSignal = {obsidian: "#000000", surface: "#555555", surface2: "#000000",
  text: "#ffffff", textDim: "#ffffff", signal: "#ffffff", caution: "#ffffff",
  critical: "#ffffff", nominal: "#ffffff"};
assert.equal(paletteError(whiteSignal, "limb", false), "");
assert.match(paletteError(whiteSignal, "limb", true), /appLink on tinted/);
assert.match(paletteError({appLink: "#ffffff"}, "limb"), /Unknown palette role/);
assert.match(paletteError({text: "#80ffffff"}, "limb"), /opaque #RRGGBB/);
assert.deepEqual(pathOf({0: "display", 1: "outputs", 2: "DP.1", 3: "profile", length: 4}),
  ["display", "outputs", "DP.1", "profile"]);
console.log("contrast-audit: ok (12 schemes, actual navigator tint, both app-link derivations, invalid role/alpha, no mutation, literal-dot output path)");
