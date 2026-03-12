#!/usr/bin/env node

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const BUILD_DIR = path.join(__dirname, "build", "dev", "javascript");
const DIST_DIR = path.join(__dirname, "priv", "javascript");

// Recursively copy directory (skip priv directory to avoid infinite recursion)
function copyDir(src, dest, skipPatterns = []) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }

  const files = fs.readdirSync(src);
  for (const file of files) {
    // Skip certain patterns
    if (skipPatterns.some((pattern) => file.includes(pattern))) {
      continue;
    }

    const srcFile = path.join(src, file);
    const destFile = path.join(dest, file);

    // Resolve to absolute path to avoid issues
    const srcAbsolute = fs.realpathSync(srcFile);
    const destAbsolute = path.resolve(destFile);

    // Avoid copying priv directory (would create recursion)
    if (srcAbsolute.includes("/priv/")) {
      continue;
    }

    const stat = fs.statSync(srcFile);

    if (stat.isDirectory()) {
      copyDir(srcFile, destFile, skipPatterns);
    } else {
      fs.copyFileSync(srcFile, destFile);
    }
  }
}

// Ensure dist directory exists and is clean
if (fs.existsSync(DIST_DIR)) {
  fs.rmSync(DIST_DIR, { recursive: true });
}
fs.mkdirSync(DIST_DIR, { recursive: true });

// Copy entire build directory (includes all dependencies)
console.log("Copying build artifacts...");
copyDir(BUILD_DIR, DIST_DIR, ["_gleam_artefacts", "priv"]);

// Create entry point
const entryCode = `import { main } from './lucy_game/lucy_game.mjs';

// Call main when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', main);
} else {
  main();
}`;

fs.writeFileSync(path.join(DIST_DIR, "index.mjs"), entryCode);

console.log("✓ Build complete! Generated files in", DIST_DIR);
console.log("✓ Open index.html in a browser to run the game");
