// Run the shared JS suites under Node.js: node tests/js/run-node.mjs
import { suites } from "./index.mjs";
import { runAll } from "./harness.mjs";
// QML JavaScript with mocked services; the Qt runner exercises the real types.
import runtimeQml from "./runtime-qml.test.mjs";

runAll(suites.concat([runtimeQml]), (line) => console.log(line)).then((summary) => {
  process.exitCode = summary.failed > 0 ? 1 : 0;
});
