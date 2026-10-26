// Run the shared JS suites under Node.js: node tests/js/run-node.mjs
import { suites } from "./index.mjs";
import { runAll } from "./harness.mjs";

runAll(suites, (line) => console.log(line)).then((summary) => {
  process.exitCode = summary.failed > 0 ? 1 : 0;
});
