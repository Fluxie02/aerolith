import { suite } from "./harness.mjs";
import { validateConfig, defaultsOf, SCHEMA, SCHEMA_VERSION, migrate, setPath, getPath, toJsonSchema } from "../../shell/lib/config.mjs";

export default suite("config", (test) => {
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

  test("no AI settings in the core schema", (assert) => {
    assert.equal(SCHEMA.props.ai, undefined);
    assert.equal(JSON.stringify(SCHEMA).toLowerCase().indexOf("claude"), -1);
    assert.equal(JSON.stringify(SCHEMA).toLowerCase().indexOf("codex"), -1);
  });
});
