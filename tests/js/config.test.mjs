import { suite } from "./harness.mjs";
import { validateConfig, defaultsOf, SCHEMA, SCHEMA_VERSION, migrate, mergeChange, mergeChanges, prepareBatch, beginPreview, setPreviewValues, previewData, previewAllowed, conflictsFor, setPath, getPath, toJsonSchema } from "../../shell/lib/config.mjs";

import { textTokens, DENSITY, backgroundPalette, resolvePalette, profileState } from "../../shell/lib/tokens.mjs";

export default suite("config", (test) => {
  test("Personalize keys default to the previous appearance and validate strictly", a => {
    const d = defaultsOf(SCHEMA);
    a.equal(d.theme.textSize, 100);
    a.deepEqual(d.workspaces.names, {});
    for (const key of ["showNetwork", "showBluetooth", "showMedia", "showAudio", "showBattery", "showNotifications"])
      a.equal(d.strip[key], true);
    for (const key of ["showNowPlaying", "showTelemetry", "showAppRegister"]) a.equal(d.ground[key], true);
    const paths = ["theme.textSize", "workspaces.names", "workspaces.names.1", ["display", "outputs", "DP.1", "blackBackground"]];
    for (const section of ["strip", "ground"])
      for (const key in d[section]) if (/^show/.test(key) && key !== "showWindowTitle" && key !== "showDate" && key !== "showSeconds") paths.push(section + "." + key);
    const json = toJsonSchema();
    a.equal(json.properties.theme.properties.textSize.preview, true);
    a.equal(json.properties.workspaces.properties.names.maxProperties, 64);
    a.equal(json.properties.workspaces.properties.names.propertyNames.pattern, "^[1-9][0-9]{0,8}$");
    for (const path of paths) a.equal(previewAllowed(path), true, String(path));
    for (const size of [100, 112, 125, 150]) a.equal(setPath({}, "theme.textSize", size).raw.theme.textSize, size);
    for (const size of [99, 113, 151, "125", null]) a.ok(setPath({}, "theme.textSize", size).error);
    for (const section of ["strip", "ground"]) for (const key in d[section]) {
      if (!/^show/.test(key)) continue;
      a.equal(setPath({}, section + "." + key, false).raw[section][key], false);
      a.ok(setPath({}, section + "." + key, "false").error);
    }
    const output = ["display", "outputs", "DP.1", "blackBackground"];
    a.equal(getPath(previewData({}, setPreviewValues(beginPreview({}), [{path: output, value: true}]).preview), output), true);
    a.equal(getPath(validateConfig('{"display":{"outputs":{"DP.1":{}}}}').config, output), false);
    a.ok(setPath({}, output, 1).error);
    a.equal(previewData({}, null).theme.textSize, 100);
    a.equal(SCHEMA.props.display.props.outputs.values.props.textSize, undefined);
    a.equal(SCHEMA.props.display.props.outputs.values.props.density, undefined);
  });

  test("workspace names are bounded for files, whole maps, individual writes and previews", a => {
    const names = {}; for (let i = 1; i <= 64; i++) names[i] = "Label " + i;
    a.ok(setPath({}, "workspaces.names", names).raw);
    a.ok(setPath({workspaces: {names}}, "workspaces.names.65", "Overflow").error);
    names[65] = "Overflow";
    a.ok(setPath({}, "workspaces.names", names).error);
    a.equal(Object.keys(validateConfig(JSON.stringify({workspaces: {names}})).config.workspaces.names).length, 0);
    for (const key of ["0", "-1", "01", "1.5", "1000000000", "__proto__", "constructor"]) {
      a.ok(setPath({}, ["workspaces", "names", key], "Bad").error, key);
      a.ok(setPath({}, "workspaces.names", JSON.parse('{"' + key + '":"Bad"}')).error, key);
    }
    a.ok(setPath({}, "workspaces.names.1", "x".repeat(49)).error);
    a.ok(setPath({}, "workspaces.names.1", 12).error);
    a.equal(setPath({}, "workspaces.names.1", "x".repeat(48)).raw.workspaces.names[1].length, 48);
    const p = setPreviewValues(beginPreview({}), [{path:"workspaces.names", value:{1:"Writing",2:""}}]).preview;
    a.equal(previewData({}, p).workspaces.names[1], "Writing");
    a.deepEqual(previewData({}, null).workspaces.names, {});
    a.ok(setPreviewValues(p, [{path:"workspaces.names",value:{bad:"No"}}]).error);
    a.equal(previewData({}, p).workspaces.names[1], "Writing");
  });

  test("each derived text token scales independently and preserves 100 percent rounding", a => {
    for (const density of ["compact", "standard", "comfortable"]) for (const scale of [.75, 1, 1.25, 1.5, 2]) {
      const d = DENSITY[density], unit = scale * (density === "compact" ? .92 : density === "comfortable" ? 1.08 : 1);
      for (const percent of [100, 112, 125, 150]) {
        const t = textTokens(density, percent, scale);
        a.equal(t.factor, percent / 100);
        for (const key of ["fontXs", "fontSm", "fontMd", "fontLg", "fontXl", "stripHeight", "rowHeight"])
          a.equal(t[key], Math.round(d[key] * scale * percent / 100), key);
        const sizes = {titleSize:36,inputSize:28,resultSize:16,resultHeight:68,headerHeight:56,inputHeight:76};
        for (const key in sizes) a.equal(t[key], Math.round(sizes[key] * unit * percent / 100), key);
      }
    }
    a.deepEqual(textTokens("invalid", undefined), textTokens("standard", 100));
  });

  test("black backing changes only the background and never enables OLED idle policy", a => {
    const palette = resolvePalette({});
    a.equal(backgroundPalette(palette, false), palette);
    const black = backgroundPalette(palette, true);
    a.equal(black.obsidian, "#000000");
    for (const key in palette) if (key !== "obsidian") a.equal(black[key], palette[key]);
    a.ok(palette.obsidian !== "#000000");
    a.deepEqual(profileState("standard", {idleDimAfter:1}, true), {idleDimmed:false,opacity:1,hideContent:false,decorationOpacity:1});
  });

  test("batch validates every leaf before returning a writable result", a => {
    const raw = { theme: { scheme: "limb" }, unknown: { keep: true } };
    const bad = prepareBatch(raw, [{path: "theme.scheme", value: "iris"}, {path: "strip.edge", value: "left"}]);
    a.match(bad.error, /strip/);
    a.equal(bad.raw, undefined);
    a.equal(raw.theme.scheme, "limb");
    const good = prepareBatch(raw, [{path: "theme.scheme", value: "iris"}, {path: "strip.edge", value: "bottom"}]);
    a.equal(good.changes.length, 2);
    a.equal(good.changes[0].expected, "limb");
    a.equal(good.raw.strip.edge, "bottom");
    a.deepEqual(good.raw.unknown, raw.unknown);
    a.match(prepareBatch(raw, [{path: "theme.palette", value: {}}, {path: "theme.palette.text", value: "#ffffff"}]).error, /overlapping/);
    a.match(prepareBatch(raw, [{path: "strip.edge", value: "top"}, {path: "strip.edge", value: "bottom"}]).error, /overlapping/);
    a.match(prepareBatch(raw, null).error, /list/);
    a.match(prepareBatch(raw, [null]).error, /path/);
    a.match(prepareBatch(raw, [{path: "theme.palette", value: undefined}]).error, /required/);
  });

  test("appearance allowlist cannot smuggle service changes through containers", a => {
    for (const path of ["theme.scheme", "theme.palette", "theme.palette.signal", "strip.visible", "strip.edge", "strip.showWindowTitle", "strip.clock", "strip.showDate", "strip.showSeconds", "ground.enabled", ["display", "outputs", "DP.1", "profile"]])
      a.equal(previewAllowed(path), true, String(path));
    for (const path of ["theme", "theme.unknown", "strip", "strip.telemetry", "strip.workspaceCount", "telemetry.gpu", "notifications.server", "lock.enabled", "display.outputs", "display.oled.idleDimAfter", "display.outputs.DP-1.strip", "commandCore.terminal", "theme.__proto__.x", ["display", "outputs", "constructor", "profile"]])
      a.equal(previewAllowed(path), false, String(path));
    a.match(setPath({}, "__proto__.polluted", true).error, /unknown/);
    a.match(setPath({}, "theme.constructor", true).error, /unknown/);
  });

  test("draft overlay is immutable, retains last valid edit, and cancel uses latest base", a => {
    const raw = { theme: { scheme: "limb" }, future: 7 };
    const initial = beginPreview(raw);
    a.equal(setPreviewValues(beginPreview({}), [{path: "theme.scheme", value: "limb"}]).preview.changes.length, 0);
    a.equal(setPreviewValues(beginPreview({}), [{path: ["display", "outputs", "DP-1", "profile"], value: "standard"}]).preview.changes.length, 0);
    const p = setPreviewValues(initial, [{path: "theme.scheme", value: "iris"}, {path: "strip.edge", value: "bottom"}]).preview;
    a.equal(previewData(raw, p).theme.scheme, "iris");
    a.equal(previewData(raw, p).strip.edge, "bottom");
    a.equal(raw.theme.scheme, "limb");
    a.equal(initial.changes.length, 0);
    a.match(setPreviewValues(p, [{path: "theme.scheme", value: "invalid"}]).error, /must be one/);
    a.match(setPreviewValues(p, [{path: "notifications.server", value: true}]).error, /not an appearance/);
    a.equal(previewData(raw, p).theme.scheme, "iris");
    const fresh = {theme: {scheme: "limb", density: "compact"}, future: 8};
    a.equal(previewData(fresh, p).theme.density, "compact");
    a.equal(previewData(fresh, null).theme.scheme, "limb");
    a.equal(previewData(fresh, null).future, 8);
    const reset = setPreviewValues(p, [{path: "theme.scheme", value: "limb"}]).preview;
    a.deepEqual(reset.changes.map(c => c.path.join(".")), ["strip.edge"]);
    a.equal(p.changes.length, 2);
  });

  test("transaction rebases unrelated changes but compares all paths to BEGIN", a => {
    const raw = {theme: {scheme: "limb", density: "standard"}};
    let p = setPreviewValues(beginPreview(raw), [{path: "theme.scheme", value: "iris"}]).preview;
    p = setPreviewValues(p, [{path: "theme.scheme", value: "corona"}]).preview;
    const external = {theme: {scheme: "limb", density: "compact"}, future: {keep: [1]}};
    const applied = mergeChanges(JSON.stringify(external), p.changes);
    a.deepEqual(applied.raw.theme, {scheme: "corona", density: "compact"});
    a.deepEqual(applied.raw.future, external.future);
    const conflict = {theme: {scheme: "bathyal", density: "compact"}};
    a.deepEqual(conflictsFor(conflict, p.changes), ["theme.scheme"]);
    a.equal(mergeChanges(JSON.stringify(conflict), p.changes).raw, undefined);
    // First editing density after a watcher update still uses BEGIN's value.
    p = setPreviewValues(p, [{path: "theme.density", value: "comfortable"}]).preview;
    a.deepEqual(conflictsFor(external, p.changes), ["theme.density"]);
    a.equal(mergeChanges(JSON.stringify(external), p.changes).raw, undefined);
    a.match(mergeChanges("{broken", p.changes).error, /valid JSON/);
  });

  test("structured output paths preserve literal dots, siblings and disconnected outputs", a => {
    const raw = {display: {outputs: {"DP.1": {profile: "standard", strip: false}, "DP-2": {ground: false}}}};
    const path = ["display", "outputs", "DP.1", "profile"];
    const p = setPreviewValues(beginPreview(raw), [{path, value: "oled"}]).preview;
    const data = previewData(raw, p);
    a.equal(data.display.outputs["DP.1"].profile, "oled");
    a.equal(data.display.outputs["DP.1"].strip, false);
    a.equal(data.display.outputs["DP-2"].ground, false);
    const applied = mergeChanges(JSON.stringify(raw), p.changes);
    a.equal(getPath(applied.raw, path), "oled");
    a.equal(raw.display.outputs["DP.1"].profile, "standard");
  });

  test("queued batch projection supports rapid stepping without exposing drafts to disk", a => {
    const raw = {};
    const first = prepareBatch(raw, [{path: "theme.density", value: "compact"}]);
    const next = prepareBatch(first.raw, [{path: "theme.density", value: "comfortable"}]);
    const saved = mergeChanges("{}", first.changes);
    a.equal(mergeChanges(JSON.stringify(saved.raw), next.changes).raw.theme.density, "comfortable");
    a.deepEqual(raw, {});
    const values = [{path: "theme.palette", value: {signal: "#ffffff"}}];
    const draft = setPreviewValues(beginPreview(raw), values).preview;
    values[0].value.signal = "orange";
    a.equal(previewData(raw, draft).theme.palette.signal, "#ffffff");
  });

  test("fresh saves preserve unrelated CLI edits and unknown keys", a => {
    const fresh = { theme: { scheme: "cinder", density: "standard" }, future: { keep: [1, 2] } };
    const r = mergeChange(JSON.stringify(fresh), "theme.density", "compact", "standard");
    a.equal(r.error, undefined);
    a.deepEqual(r.raw.theme, { scheme: "cinder", density: "compact" });
    a.deepEqual(r.raw.future, fresh.future);
    a.equal(fresh.theme.density, "standard");
    a.equal(mergeChange("", "strip.edge", "bottom", undefined).raw.strip.edge, "bottom");
  });

  test("fresh saves refuse conflicts and broken/non-object files", a => {
    a.match(mergeChange('{"theme":{"density":"comfortable"}}', "theme.density", "compact", "standard").error,
      /configuration changed at theme.density/);
    a.match(mergeChange('{}', "theme.density", "compact", "standard").error, /configuration changed/);
    for (const text of ['{bad', '[]', 'null', 'false', '42', '"text"'])
      a.match(mergeChange(text, "strip.edge", "bottom", undefined).error, /fix it before saving settings/);
    a.match(mergeChange('{}', "strip.edge", "bad", undefined).error, /strip.edge/);
  });

  test("map conflicts compare contents regardless of key order", a => {
    const expected = { text: "#ffffff", signal: "#123456" };
    const text = '{"theme":{"palette":{"signal":"#123456","text":"#ffffff"}}}';
    a.equal(mergeChange(text, "theme.palette", {}, expected).error, undefined);
    a.match(mergeChange(text, "theme.palette", {}, { text: "#ffffff" }).error, /configuration changed/);
  });

  test("OLED defaults preserve old configs, validate bounds and retain output profiles", assert => {
    const parse = value => validateConfig(JSON.stringify(value));
    const old = parse({ display: { output: "DP-1" } });
    assert.equal(old.errors.length, 0);
    assert.deepEqual(old.config.display.oled, { idleDimAfter: 300, idleDimLevel: 0.65, hideDecorationWhenIdle: true });
    const custom = parse({ display: { outputs: { "DP-2": { profile: "oled" } }, oled: { idleDimAfter: 0, idleDimLevel: 0, hideDecorationWhenIdle: false } } });
    assert.equal(custom.errors.length, 0);
    assert.equal(custom.config.display.outputs["DP-2"].profile, "oled");
    assert.equal(custom.config.display.oled.idleDimAfter, 0);
    assert.equal(custom.config.display.oled.idleDimLevel, 0);
    assert.equal(custom.config.display.oled.hideDecorationWhenIdle, false);
    const bad = parse({ display: { oled: { idleDimAfter: -1, idleDimLevel: 2, hideDecorationWhenIdle: "no" } } });
    assert.equal(bad.errors.length, 3);
    assert.deepEqual(bad.config.display.oled, old.config.display.oled);
    assert.ok(parse({ display: { oled: { idleDimAfter: 0.5 } } }).errors.length > 0);
    const schema = toJsonSchema();
    assert.equal(schema.properties.display.properties.oled.properties.idleDimAfter.default, 300);
  });
  test("empty or missing config yields complete defaults without errors", (assert) => {
    const r = validateConfig("");
    assert.equal(r.errors.length, 0);
    assert.equal(r.config.strip.edge, "top");
    assert.equal(r.config.telemetry.historySamples, 120);
    assert.equal(r.config.schemaVersion, SCHEMA_VERSION);
  });

  test("malformed JSON is reported and defaults are used", (assert) => {
    const r = validateConfig("{ strip: ");
    assert.equal(r.errors.length, 1);
    assert.match(r.errors[0].message, /invalid JSON/);
    assert.deepEqual(r.config, defaultsOf(SCHEMA));
    // Flagged so the shell can keep its last good settings instead.
    assert.equal(r.invalidJson, true);
  });

  test("only unparsable text is flagged as invalid JSON", (assert) => {
    assert.ok(!validateConfig(JSON.stringify({ strip: { edge: "left" } })).invalidJson);
    assert.ok(!validateConfig("").invalidJson);
    assert.ok(!validateConfig("[1, 2]").invalidJson);
  });

  test("a bad value falls back to its default without affecting siblings", (assert) => {
    const r = validateConfig(JSON.stringify({ strip: { edge: "left", showDate: false } }));
    assert.equal(r.config.strip.edge, "top");
    assert.equal(r.config.strip.showDate, false);
    assert.equal(r.errors.length, 1);
    assert.equal(r.errors[0].path, "strip.edge");
  });

  test("range and type checks", (assert) => {
    const r = validateConfig(JSON.stringify({ telemetry: { stripIntervalMs: 10, historySamples: "lots" }, theme: { uiScale: 3 } }));
    const paths = r.errors.map((e) => e.path).sort();
    assert.deepEqual(paths, ["telemetry.historySamples", "telemetry.stripIntervalMs", "theme.uiScale"]);
  });

  test("unknown keys are preserved and warned about", (assert) => {
    const r = validateConfig(JSON.stringify({ $schema: "x", strip: { glow: true }, futureSection: { a: 1 } }));
    assert.equal(r.errors.length, 0);
    assert.equal(r.warnings.length, 2);
    assert.equal(r.config.futureSection.a, 1);
    assert.equal(r.config.strip.glow, true);
    assert.equal(r.config.$schema, "x");
  });

  test("palette overrides only accept colours", (assert) => {
    const r = validateConfig(JSON.stringify({ theme: { palette: { signal: "#00FF00", caution: "orange" } } }));
    assert.deepEqual(r.config.theme.palette, { signal: "#00FF00" });
    assert.equal(r.errors[0].path, "theme.palette.caution");
  });

  test("list settings validate their items", (assert) => {
    assert.deepEqual(validateConfig(JSON.stringify({ commandCore: { terminal: ["kitty", "-e"] } })).config.commandCore.terminal, ["kitty", "-e"]);
    const bad = validateConfig(JSON.stringify({ commandCore: { terminal: ["kitty", 3] } }));
    assert.deepEqual(bad.config.commandCore.terminal, []);
    assert.equal(bad.errors.length, 1);
  });

  test("a non-object document is rejected with defaults", (assert) => {
    const r = validateConfig("[1,2,3]");
    assert.equal(r.errors.length, 1);
    assert.equal(r.config.strip.visible, true);
  });

  test("newer schema versions are accepted with a warning", (assert) => {
    const r = validateConfig(JSON.stringify({ schemaVersion: SCHEMA_VERSION + 1 }));
    assert.equal(r.errors.length, 0);
    assert.match(r.warnings[0].message, /newer AEROLITH/);
  });

  test("migration runs registered steps in order", (assert) => {
    // Simulate a future schema version 2 that renamed a section.
    const steps = {
      1: (raw, notes) => {
        notes.push("renamed bar -> strip");
        raw.strip = raw.bar;
        delete raw.bar;
        return raw;
      },
    };
    const m = migrate({ schemaVersion: 1, bar: { edge: "bottom" } }, steps, 2);
    assert.equal(m.error, undefined);
    assert.equal(m.from, 1);
    assert.equal(m.to, 2);
    assert.equal(m.raw.schemaVersion, 2);
    assert.deepEqual(m.raw.strip, { edge: "bottom" });
    assert.deepEqual(m.notes, ["renamed bar -> strip"]);
  });

  test("migration reports a missing step instead of guessing", (assert) => {
    assert.match(migrate({ schemaVersion: 1 }, {}, 3).error, /no migration from version 1/);
    assert.match(migrate({ schemaVersion: 0 }, {}, 1).error, /invalid schemaVersion/);
    assert.match(migrate({ schemaVersion: "1" }, {}, 1).error, /invalid schemaVersion/);
  });

  test("setPath validates and preserves unrelated keys", (assert) => {
    const raw = { strip: { edge: "top" }, custom: { keep: 1 } };
    const r = setPath(raw, "strip.edge", "bottom");
    assert.equal(r.raw.strip.edge, "bottom");
    assert.equal(r.raw.custom.keep, 1);
    assert.equal(raw.strip.edge, "top", "input is not mutated");
    assert.match(setPath(raw, "strip.edge", "left").error, /must be one of/);
    assert.match(setPath(raw, "strip.nope", 1).error, /unknown setting/);
    assert.equal(getPath(r.raw, "strip.edge"), "bottom");
  });

  test("JSON Schema export covers every section with defaults", (assert) => {
    const js = toJsonSchema();
    assert.equal(js.type, "object");
    assert.equal(js.properties.strip.properties.edge.default, "top");
    assert.deepEqual(js.properties.strip.properties.edge.enum, ["top", "bottom"]);
    assert.equal(js.properties.theme.properties.palette.additionalProperties.pattern, "^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$");
  });

  test("retired display keys are hidden metadata but remain readable for compatibility", assert => {
    const display = SCHEMA.props.display.props;
    const jsonDisplay = toJsonSchema().properties.display.properties;
    for (const key of ["output", "warnOnMultipleDisplays"]) {
      assert.equal(display[key].hidden, true);
      assert.equal(display[key].deprecated, true);
      assert.equal(jsonDisplay[key].deprecated, true);
    }
    assert.ok(!display.primary.hidden);
    const result = validateConfig('{"display":{"output":"DP-2","warnOnMultipleDisplays":false}}');
    assert.equal(result.errors.length, 0);
    assert.equal(result.config.display.output, "DP-2");
    assert.equal(result.config.display.warnOnMultipleDisplays, false);
  });

  test("setPath rejects invalid array items, types and limits without mutating input", assert => {
    const raw = { commandCore: { terminal: ["foot"] }, custom: { keep: 1 } };
    const tooMany = [];
    for (let i = 0; i < 17; i++) tooMany.push("arg");
    for (const value of [[1], "foot", null, tooMany, ["x".repeat(257)]]) {
      const result = setPath(raw, "commandCore.terminal", value);
      assert.match(result.error, /commandCore\.terminal/);
      assert.equal(result.raw, undefined, "invalid arrays must not produce a writable config");
    }
    assert.deepEqual(raw, { commandCore: { terminal: ["foot"] }, custom: { keep: 1 } });
    const result = setPath(raw, "commandCore.terminal", ["kitty", "-e"]);
    assert.equal(result.error, undefined);
    assert.deepEqual(result.raw.commandCore.terminal, ["kitty", "-e"]);
    assert.deepEqual(result.raw.custom, raw.custom);
  });

  test("setPath validates nested output profiles and map values", assert => {
    const raw = { display: { outputs: { "DP-1": { profile: "standard" } } } };
    for (const value of [{ "DP-1": { profile: "invalid" } }, { "DP-1": { strip: 1 } }, { "DP-1": [] }, [], null]) {
      const result = setPath(raw, "display.outputs", value);
      assert.match(result.error, /display\.outputs/);
      assert.equal(result.raw, undefined);
    }
    assert.match(setPath(raw, "display.outputs", { "DP-1": { profile: "invalid" } }).error, /display\.outputs\.DP-1\.profile/);
    assert.match(setPath(raw, "theme.palette", { signal: "orange" }).error, /theme\.palette\.signal/);
    assert.deepEqual(raw.display.outputs, { "DP-1": { profile: "standard" } });
    const outputs = { "DP-1": { profile: "oled", strip: false }, "DP-2": {} };
    const result = setPath(raw, "display.outputs", outputs);
    assert.equal(result.error, undefined);
    assert.deepEqual(result.raw.display.outputs, outputs);
    assert.equal(validateConfig(JSON.stringify(result.raw)).errors.length, 0);
  });

  test("setPath repairs a subtree despite unrelated errors and preserves unknown keys", assert => {
    const raw = {
      commandCore: { terminal: [1], future: "keep" },
      display: { outputs: { "DP-1": { profile: "bad" } } },
      strip: { edge: "left", future: true },
      custom: { keep: [1, 2] }
    };
    const terminal = setPath(raw, "commandCore.terminal", ["foot"]);
    assert.equal(terminal.error, undefined);
    assert.equal(terminal.raw.commandCore.future, "keep");
    assert.equal(terminal.raw.display.outputs["DP-1"].profile, "bad");
    const outputs = { "DP-1": { profile: "oled", future: "kept" } };
    const result = setPath(terminal.raw, "display.outputs", outputs);
    assert.equal(result.error, undefined);
    assert.deepEqual(result.raw.display.outputs, outputs);
    assert.deepEqual(result.raw.strip, raw.strip);
    assert.deepEqual(result.raw.custom, raw.custom);
    assert.deepEqual(raw.commandCore.terminal, [1]);
  });

  test("no AI settings in the core schema", (assert) => {
    assert.equal(SCHEMA.props.ai, undefined);
    assert.equal(JSON.stringify(SCHEMA).toLowerCase().indexOf("claude"), -1);
    assert.equal(JSON.stringify(SCHEMA).toLowerCase().indexOf("codex"), -1);
  });

  test("intensity defaults to saturated and accepts only known levels", (assert) => {
    assert.equal(validateConfig("").config.theme.intensity, "saturated");
    assert.equal(validateConfig('{"theme":{"intensity":"insane"}}').config.theme.intensity, "insane");
    const r = validateConfig('{"theme":{"intensity":"dense"}}');
    assert.equal(r.config.theme.intensity, "saturated");
    assert.equal(r.errors.length, 1);
  });
});
