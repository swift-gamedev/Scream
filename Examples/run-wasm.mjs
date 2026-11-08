// Runs a WASI build of an example under Node:
//
//   node Examples/run-wasm.mjs .build/wasm32-unknown-wasip1/debug/HelloWorld.wasm
//
// Needs Node 20 or newer for the stable node:wasi module.
import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

const [, , path, ...args] = process.argv;
if (!path) {
  console.error("usage: node run-wasm.mjs <program.wasm> [args...]");
  process.exit(2);
}

const wasi = new WASI({ version: "preview1", args: [path, ...args], env: {} });
const module = await WebAssembly.compile(await readFile(path));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
process.exit(wasi.start(instance));
