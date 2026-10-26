// Regenerate the settings reference in docs/CONFIGURATION.md from
// shell/lib/config.mjs (the single source of truth). Only the text between
// the GENERATED markers is replaced. Run: node tools/gen-config-doc.mjs
// With --check, exit 1 if the file is out of date instead of writing it.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { SCHEMA } from "../shell/lib/config.mjs";

const BEGIN = "<!-- BEGIN GENERATED: tools/gen-config-doc.mjs -->";
const END = "<!-- END GENERATED -->";
const file = fileURLToPath(new URL("../docs/CONFIGURATION.md", import.meta.url));

function typeOf(spec) {
  switch (spec.type) {
    case "int":
    case "number":
      return (spec.type === "int" ? "integer" : "number") + " " + spec.min + "–" + spec.max;
    case "enum":
      return spec.values.map((v) => "`" + v + "`").join(" \\| ");
    case "string":
      return "string (≤ " + spec.maxLength + ")";
    case "array":
      return "list of strings";
    case "map":
      return "object of colours";
    default:
      return spec.type;
  }
}

function def(spec) {
  return "`" + JSON.stringify(spec.default) + "`";
}

const out = [BEGIN, ""];
for (const [section, spec] of Object.entries(SCHEMA.props)) {
  if (spec.type !== "object") continue;
  out.push("### `" + section + "`", "", spec.description, "", "| Key | Type | Default | Meaning |", "|---|---|---|---|");
  for (const [key, s] of Object.entries(spec.props)) {
    out.push("| `" + section + "." + key + "` | " + typeOf(s) + " | " + def(s) + " | " + s.description.replace(/\|/g, "\\|") + " |");
  }
  out.push("");
}
out.push(END);
const generated = out.join("\n");

const text = readFileSync(file, "utf8");
const a = text.indexOf(BEGIN);
const b = text.indexOf(END);
if (a < 0 || b < a) throw new Error("markers not found in " + file);
const next = text.slice(0, a) + generated + text.slice(b + END.length);
if (process.argv.includes("--check")) {
  if (next !== text) {
    console.error("docs/CONFIGURATION.md is out of date: run node tools/gen-config-doc.mjs");
    process.exit(1);
  }
  console.log("docs/CONFIGURATION.md is up to date");
} else {
  writeFileSync(file, next);
  console.log("wrote " + file);
}
