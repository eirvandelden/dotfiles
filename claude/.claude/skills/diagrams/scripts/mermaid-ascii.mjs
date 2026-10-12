// Reads one Mermaid diagram on stdin and prints it as Unicode text.
// beautiful-mermaid is ESM only and installed globally, so resolve it with `npm root -g`.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
const dir = join(root, "beautiful-mermaid");
const entry = JSON.parse(readFileSync(join(dir, "package.json"), "utf8")).exports["."].import;
const { renderMermaidASCII } = await import(pathToFileURL(join(dir, entry)).href);

console.log(renderMermaidASCII(readFileSync(0, "utf8")));
