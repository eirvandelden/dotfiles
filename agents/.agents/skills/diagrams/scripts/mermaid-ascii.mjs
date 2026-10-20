// Reads one Mermaid diagram on stdin and prints it as Unicode text.
// beautiful-mermaid is ESM only and installed globally, so resolve it with `npm root -g`.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
const dir = join(root, "beautiful-mermaid");
// Exit 3 tells mermaid-show the package is missing, as opposed to a diagram it cannot render.
if (!existsSync(join(dir, "package.json"))) process.exit(3);
const entry = JSON.parse(readFileSync(join(dir, "package.json"), "utf8")).exports["."].import;
const { renderMermaidASCII } = await import(pathToFileURL(join(dir, entry)).href);

console.log(renderMermaidASCII(readFileSync(0, "utf8")));
