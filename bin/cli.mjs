#!/usr/bin/env node
// asyncapi-cable CLI: load a cable.config file and generate every target.
//
//   asyncapi-cable [-c cable.config.mjs]
//
// Mirrors `orval -c orval.config.ts`. Config paths are resolved from the
// current working directory.

import path from "node:path";
import { pathToFileURL } from "node:url";

import { generateAll } from "../src/index.mjs";

function parseArgs(argv) {
  let config = "cable.config.mjs";
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "-c" || arg === "--config") {
      config = argv[++i];
    } else if (arg === "-h" || arg === "--help") {
      console.log("Usage: asyncapi-cable [-c cable.config.mjs]");
      process.exit(0);
    }
  }
  if (!config) {
    console.error("asyncapi-cable: missing config path after -c/--config");
    process.exit(1);
  }
  return { config };
}

async function main() {
  const { config } = parseArgs(process.argv.slice(2));
  const cwd = process.cwd();
  const configUrl = pathToFileURL(path.resolve(cwd, config)).href;
  const module = await import(configUrl);
  const cableConfig = module.default ?? module.config;
  if (!cableConfig) {
    throw new Error(`${config} must default-export a cable config object`);
  }
  await generateAll(cableConfig, cwd);
}

main().catch((error) => {
  console.error(`[asyncapi-cable] ${error.message}`);
  process.exitCode = 1;
});
