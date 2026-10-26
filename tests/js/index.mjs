// Every JS suite, imported statically so the Node runner and the Qt runner
// execute exactly the same set.
import fuzzy from "./fuzzy.test.mjs";
import hyprdispatch from "./hyprdispatch.test.mjs";
import registry, { paramsSuite } from "./registry.test.mjs";
import telemetry from "./telemetry.test.mjs";
import config from "./config.test.mjs";
import routines from "./routines.test.mjs";
import launch, { tokensSuite } from "./launch.test.mjs";
import schemes from "./schemes.test.mjs";
import shellstate from "./shellstate.test.mjs";
import brightness from "./brightness.test.mjs";

export const suites = [fuzzy, hyprdispatch, registry, paramsSuite, telemetry, config, routines, launch, tokensSuite, schemes, shellstate, brightness];
