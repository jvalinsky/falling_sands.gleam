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

// Patch gleeunit to discover test_ prefix (Gleam convention) instead of _test suffix
// This needs to be done in both the build dir (for gleam test) and dist dir (for browser)
function patchGleeunit(dir) {
  const gleeunitFfiPath = path.join(dir, "gleeunit", "gleeunit_ffi.mjs");
  if (fs.existsSync(gleeunitFfiPath)) {
    let content = fs.readFileSync(gleeunitFfiPath, "utf8");
    content = content.replace(
      'if (!fnName.endsWith("_test")) continue;',
      'if (!fnName.startsWith("test_")) continue;'
    );
    fs.writeFileSync(gleeunitFfiPath, content);
    return true;
  }
  return false;
}

patchGleeunit(BUILD_DIR);

// Copy entire build directory (includes all dependencies)
console.log("Copying build artifacts...");
copyDir(BUILD_DIR, DIST_DIR, ["_gleam_artefacts", "priv"]);

patchGleeunit(DIST_DIR);
console.log("✓ Patched gleeunit test discovery for JS target");

// Copy web worker file to dist
const workerSrc = path.join(__dirname, "sim_worker.mjs");
if (fs.existsSync(workerSrc)) {
  fs.copyFileSync(workerSrc, path.join(DIST_DIR, "sim_worker.mjs"));
  console.log("✓ Copied simulation Web Worker");
}

// Create entry point with Web Worker integration
const entryCode = `import { main } from './lucy_game/lucy_game.mjs';
import { initBridge } from './lucy_game/sim_bridge_ffi.mjs';

// ── Web Worker Setup (offloads simulation from UI thread) ──────────
(async function setupWorker() {
  if (typeof Worker === 'undefined') {
    console.warn('[Main] Web Workers not supported — using sync fallback');
    initBridge(null);  // No worker → bridge runs simulation synchronously
    return;
  }

  try {
    const worker = new Worker('./sim_worker.mjs', { type: 'module' });
    initBridge(worker);
    console.log('[Main] Simulation Web Worker started');
  } catch (e) {
    console.warn('[Main] Worker init failed — using sync fallback', e);
    initBridge(null);
  }
})();

// ── Launch Paint game ───────────────────────────────────────────────
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', main);
} else {
  main();
}`;

fs.writeFileSync(path.join(DIST_DIR, "index.mjs"), entryCode);

console.log("✓ Build complete! Generated files in", DIST_DIR);
console.log("✓ Open index.html in a browser to run the game");
