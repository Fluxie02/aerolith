import { suite } from "./harness.mjs";
import * as P from "../../shell/lib/presets.mjs";
import * as C from "../../shell/lib/config.mjs";

export default suite("presets", test => {
  test("built-ins are valid fresh copies and omit output assignments", a => {
    const presets = P.builtins();
    a.deepEqual(presets.map(p => p.id), ["default", "readable"]);
    for (const p of presets) {
      a.ok(!P.validate(JSON.stringify(p.values)).error);
      a.equal(p.values.display, undefined);
    }
    a.equal(presets[1].values.theme.density, "comfortable");
    presets[0].values.theme.density = "compact";
    a.equal(P.builtins()[0].values.theme.density, "standard");
  });
  test("supplied leaves merge while omitted settings and exact connector names survive", a => {
    const raw = {theme: {scheme: "iris"}, display: {outputs: {"DP.1": {profile: "standard", strip: false}, DP: {profile: "standard"}, gone: {profile: "oled"}}}};
    const before = JSON.stringify(raw);
    const checked = P.validate('{"display":{"outputs":{"DP.1":{"profile":"oled"}}},"theme":{"density":"compact"}}');
    a.ok(!checked.error, checked.error);
    const draft = C.setPreviewValues(C.beginPreview(raw), checked.values);
    a.ok(!draft.error, draft.error);
    const data = C.previewData(raw, draft.preview);
    a.equal(data.display.outputs["DP.1"].profile, "oled");
    a.equal(data.display.outputs["DP.1"].strip, false);
    a.equal(data.display.outputs.DP.profile, "standard");
    a.equal(data.display.outputs.gone.profile, "oled");
    a.equal(data.theme.scheme, "iris");
    a.equal(JSON.stringify(raw), before);
  });
  test("strict import refuses invalid values, unknown keys and every nonappearance domain", a => {
    for (const values of [
      {ai: {}}, {routines: {}}, {binds: []}, {direction: "thears"}, {startup: {}},
      {welcome: {showOnStartup: true}}, {commandCore: {terminal: ["sh"]}},
      {display: {primary: "DP-1"}}, {display: {outputs: {"*": {profile: "oled"}}}},
      {theme: {uiScale: 9}}, {theme: {motion: "fast"}}, {theme: {lowEffects: "yes"}},
      {theme: {typo: true}}, {ground: {unexpected: true}}, {strip: {telemetry: "off"}},
      {theme: {palette: {signal: "red"}}}, {theme: {palette: {unknownRole: "#ffffff"}}}, {theme: []}, {theme: null}
    ]) a.ok(P.validate(JSON.stringify(values)).error, JSON.stringify(values));
    a.match(P.validate('{"theme":{"typo":true}}').error, /Unknown.*theme.typo/);
    a.match(P.validate('{"theme":{"uiScale":9}}').error, /theme.uiScale.*at most/);
    a.ok(P.validate('{broken').error);
    a.ok(P.validate('[]').error);
    a.ok(P.validate('{}').error);
  });
  test("versioned envelopes validate name/version and report unknown metadata", a => {
    a.equal(P.validate('{"formatVersion":1,"name":"Mine","values":{"theme":{"motion":"off"}}}').preset.name, "Mine");
    a.match(P.validate('{"formatVersion":2,"name":"Mine","values":{}}').error, /Unsupported/);
    a.match(P.validate('{"formatVersion":1,"name":"Mine","values":{},"extra":0}').error, /Unknown/);
    a.ok(P.validateName("")); a.ok(P.validateName("a\nb")); a.ok(P.validateName("x".repeat(81)));
  });
  test("bounds cover bytes, Unicode bytes, depth, entries, finite values and unsafe properties", a => {
    for (const key of ["__proto__", "constructor", "prototype"])
      a.match(P.validate('{"theme":{"palette":{"' + key + '":"#ffffff"}}}').error, /Forbidden property/);
    a.match(P.validate(" ".repeat(P.MAX_BYTES + 1)).error, /bytes/);
    a.match(P.validate(JSON.stringify({x: "é".repeat(P.MAX_BYTES / 2)})).error, /bytes/);
    // An overflowing literal must be refused. Node parses it to Infinity and
    // the bound check refuses it; Qt's V4 (the shell's engine) refuses it in
    // JSON.parse itself. Either way nothing non-finite reaches the config.
    const overflow = P.validate('{"theme":{"uiScale":1e999}}');
    a.ok(!overflow.value, "overflowing number accepted");
    a.match(overflow.error, /must be finite|Invalid preset JSON/);
    let deep = true;
    for (let i = 0; i < 15; i++) deep = {x: deep};
    a.match(P.validate(JSON.stringify(deep)).error, /nesting/);
    const many = {}; for (let i = 0; i < 1100; i++) many["k" + i] = 0;
    a.match(P.validate(JSON.stringify(many)).error, /entries/);
  });
  test("export includes only allowlisted schema keys and output overrides require opt-in", a => {
    const config = C.validateConfig('{"theme":{"scheme":"iris","future":true},"display":{"primary":"DP.1","outputs":{"DP.1":{"profile":"oled","strip":false}}},"routines":{"allowCommandSteps":true},"ai":{"command":"bad"},"direction":"thears"}').config;
    const before = JSON.stringify(config);
    const encoded = P.encode(config, "Mine");
    a.ok(!encoded.error, encoded.error);
    const values = encoded.preset.values;
    a.equal(values.ai, undefined); a.equal(values.routines, undefined); a.equal(values.direction, undefined);
    a.equal(values.theme.future, undefined); a.equal(values.display, undefined);
    for (const leaf of P.validate(encoded.text).values) a.ok(C.previewAllowed(leaf.path));
    const specific = P.encode(config, "Specific", true);
    a.ok(!specific.error, specific.error);
    a.equal(specific.preset.values.display.primary, undefined);
    a.equal(specific.preset.values.display.outputs["DP.1"].profile, "oled");
    a.equal(JSON.stringify(config), before);
  });
  test("empty palette replaces overrides and Cancel restores the saved configuration", a => {
    const raw = {theme: {palette: {signal: "#ffffff"}, density: "compact"}};
    const checked = P.validate(JSON.stringify(P.builtins()[0].values));
    const draft = C.setPreviewValues(C.beginPreview(raw), checked.values);
    a.ok(!draft.error, draft.error);
    a.deepEqual(C.previewData(raw, draft.preview).theme.palette, {});
    a.equal(C.previewData(raw, null).theme.palette.signal, "#ffffff");
    a.equal(C.previewData(raw, null).theme.density, "compact");
  });
  test("store round-trips user presets and refuses corruption, duplicates and limits", a => {
    const users = [{id: "user-abc", name: "Mine", values: {theme: {motion: "off"}}}];
    const encoded = P.writeStore(users);
    a.deepEqual(P.readStore(encoded.text).presets, users);
    a.ok(P.writeStore(users.concat(users)).error);
    a.ok(P.writeStore([{id: "default", name: "Bad", values: users[0].values}]).error);
    a.ok(P.readStore('{"formatVersion":9,"presets":[]}').error);
    a.ok(P.readStore('{"formatVersion":1,"presets":[],"extra":true}').error);
    a.ok(P.writeStore(Array.from({length: P.MAX_PRESETS + 1}, (_, i) => ({id: "user-" + i, name: "M", values: {theme: {motion: "off"}}}))).error);
  });
});
