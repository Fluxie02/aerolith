// Generate shell/schema/config.schema.json from shell/lib/config.mjs, the
// single source of truth for configuration. Run: node tools/gen-schema.mjs
// tests/py/test_schema.py fails if the committed file is out of date.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { toJsonSchema } from "../shell/lib/config.mjs";

const out = fileURLToPath(new URL("../shell/schema/config.schema.json", import.meta.url));
writeFileSync(out, JSON.stringify(toJsonSchema(), null, 2) + "\n");
console.log("wrote " + out);
