/**
 * sim_bridge_ffi.mjs — Bridge between Web Worker and Gleam-compiled code
 *
 * Stores a shared Grid object. Gleam calls sync functions here; this module
 * delegates simulation to the Web Worker (async) and falls back to sync
 * simulation when no worker is available.
 *
 * Flow:
 *   Gleam update(Tick) → tickSimulation(steps) → returns current Grid (sync)
 *                       └→ posts "step" to worker (async)
 *   Worker responds      → _onWorkerMessage: reconstructs Grid from serialized data
 *   Next Tick            → Gleam reads updated Grid
 */

import * as grid from "./grid.mjs";
import * as simulation from "./simulation.mjs";

// ── State ───────────────────────────────────────────────────────────

let _worker = null;
let _ready = false;
let _sharedGrid = null;
let _simState = null; // Fallback sync simulation state
let _sharedStep = 0;
let _sharedPhase = 0;
let _pendingStep = false;
let _stepsPerFrame = 4;
let _gridWidth = 160;
let _gridHeight = 100;
let _useWorker = false;
let _lastSimMs = 0;
let _lastSerialMs = 0;

// Cell type factory: index → constructor
const _cellFns = [
  grid.air,   // 0
  grid.sand,  // 1
  grid.water, // 2
  grid.stone, // 3
  grid.lava,  // 4
  grid.steam, // 5
  grid.oil,   // 6
  grid.acid,  // 7
  grid.ice,   // 8
];

const _typeNames = [
  "Air", "Sand", "Water", "Stone", "Lava", "Steam", "Oil", "Acid", "Ice",
];

// ── Public API (called by Gleam via @external) ──────────────────────

/**
 * Called by the entry point to inject a Worker instance.
 * If no worker is provided, the bridge runs simulation synchronously.
 */
export function initBridge(worker) {
  if (worker) {
    _worker = worker;
    _useWorker = true;
    _worker.onmessage = _onWorkerMessage;
    _worker.onerror = (e) => {
      console.warn(
        "[Bridge] Worker error, falling back to sync mode",
        "message:", e.message,
        "filename:", e.filename,
        "lineno:", e.lineno,
        "colno:", e.colno
      );
      _useWorker = false;
      _ready = false;
      // Sync the sync fallback state to current grid so we don't lose progress
      _simState = simulation.new$(_sharedGrid);
    };
    _worker.onmessageerror = (e) => {
      console.warn("[Bridge] Worker message error:", e);
    };
    _worker.postMessage({ type: "init", width: _gridWidth, height: _gridHeight });
    _worker.postMessage({ type: "config", stepsPerFrame: _stepsPerFrame });
  }
}

/**
 * Create initial empty grid. Called once during Gleam init().
 */
export function initGrid(width, height) {
  _gridWidth = width;
  _gridHeight = height;
  _sharedGrid = grid.filled_with_air(width, height);
  _simState = simulation.new$(_sharedGrid);
  _sharedStep = 0;
  _sharedPhase = 0;
  return _sharedGrid;
}

/**
 * Request a simulation step. Called by Gleam on every Tick.
 * Returns the current grid immediately (sync).
 * The worker updates _sharedGrid asynchronously for the next frame.
 */
export function tickSimulation(stepsPerFrame) {
  _stepsPerFrame = stepsPerFrame;

  if (_useWorker && _ready && !_pendingStep && _sharedGrid) {
    _pendingStep = true;
    _worker.postMessage({ type: "step", stepsPerFrame });
  } else if (!_useWorker && _simState) {
    // Fallback: run synchronously in the main thread
    _simState = simulation.steps(_simState, stepsPerFrame);
    _sharedGrid = simulation.grid(_simState);
    _sharedStep = simulation.step_count(_simState);
    _sharedPhase = simulation.phase(_simState);
  }

  return _sharedGrid;
}

/**
 * Get current iteration step count (for HUD).
 */
export function getStepCount() {
  return _sharedStep;
}

/**
 * Get current Margolus phase (for HUD).
 */
export function getPhase() {
  return _sharedPhase;
}

/**
 * Draw a cell at (x, y). Called by Gleam on mouse drag.
 * Updates shared grid immediately and notifies the worker.
 */
export function drawCell(x, y, typeIndex) {
  if (typeIndex < 0 || typeIndex >= _cellFns.length) return _sharedGrid;

  const cell = _cellFns[typeIndex]();
  _sharedGrid = grid.set(_sharedGrid, x, y, cell);

  // Keep sync fallback state in sync
  if (!_useWorker && _simState) {
    _simState = simulation.set_cell(_simState, x, y, cell);
  }

  // Notify worker so its state stays in sync
  if (_worker && _ready) {
    _worker.postMessage({
      type: "draw",
      x,
      y,
      cellType: _typeNames[typeIndex],
    });
  }

  return _sharedGrid;
}

/**
 * Reset to an empty grid.
 */
export function resetGrid(width, height) {
  _gridWidth = width;
  _gridHeight = height;
  _sharedGrid = grid.filled_with_air(width, height);
  _simState = simulation.new$(_sharedGrid);
  _sharedStep = 0;
  _sharedPhase = 0;
  _pendingStep = false;

  if (_worker) {
    _worker.postMessage({ type: "reset", width, height });
    _worker.postMessage({ type: "config", stepsPerFrame: _stepsPerFrame });
  }

  return _sharedGrid;
}

/**
 * Update steps per frame (for speed control).
 */
export function setWorkerConfig(stepsPerFrame) {
  _stepsPerFrame = stepsPerFrame;
  if (_worker) {
    _worker.postMessage({ type: "config", stepsPerFrame });
  }
}

/**
 * Get the latest worker timing as a formatted string for HUD display.
 * Returns empty string if no timing data is available yet.
 */
export function getWorkerTimingStr() {
  if (!_useWorker || !_ready) return "";
  if (_lastSimMs === 0 && _lastSerialMs === 0) return "";
  return `W: sim=${_lastSimMs} ser=${_lastSerialMs}ms`;
}

// ── Internal Helpers ────────────────────────────────────────────────

/** Flush current grid state to the worker (called when worker becomes ready). */
function _flushGridToWorker() {
  if (!_sharedGrid || !_worker) return;
  const cells = grid.to_list(_sharedGrid);
  for (const entry of cells) {
    const [pos, cell] = entry;
    const [x, y] = pos;
    const cellType = grid.cell_type(cell);
    let typeIdx = 0;
    if (cellType instanceof grid.CellType$Sand) typeIdx = 1;
    else if (cellType instanceof grid.CellType$Water) typeIdx = 2;
    else if (cellType instanceof grid.CellType$Stone) typeIdx = 3;
    else if (cellType instanceof grid.CellType$Lava) typeIdx = 4;
    else if (cellType instanceof grid.CellType$Steam) typeIdx = 5;
    else if (cellType instanceof grid.CellType$Oil) typeIdx = 6;
    else if (cellType instanceof grid.CellType$Acid) typeIdx = 7;
    else if (cellType instanceof grid.CellType$Ice) typeIdx = 8;
    if (typeIdx > 0) {
      _worker.postMessage({ type: "draw", x, y, cellType: _typeNames[typeIdx] });
    }
  }
}

// ── Worker Message Handler ──────────────────────────────────────────

function _onWorkerMessage(e) {
  const msg = e.data;

  if (msg.type === "ready") {
    _ready = true;
    _gridWidth = msg.width || _gridWidth;
    _gridHeight = msg.height || _gridHeight;
    console.log(
      "[Bridge] Worker ready — grid " + _gridWidth + "×" + _gridHeight,
    );
    // Flush current grid to worker so drawn cells aren't lost
    _flushGridToWorker();
  } else if (msg.type === "grid") {
    // Reconstruct Grid from serialized flat array [x1, y1, type1, x2, y2, type2, ...]
    _sharedGrid = grid.filled_with_air(
      msg.width || _gridWidth,
      msg.height || _gridHeight,
    );
    const cells = msg.cells;
    if (cells && cells.length > 0) {
      for (let i = 0; i < cells.length; i += 3) {
        const x = cells[i];
        const y = cells[i + 1];
        const typeIdx = cells[i + 2];
        if (typeIdx > 0 && typeIdx < _cellFns.length) {
          // Skip Air (type 0) — grid is sparse
          const cell = _cellFns[typeIdx]();
          _sharedGrid = grid.set(_sharedGrid, x, y, cell);
        }
      }
    }
    _sharedStep = msg.step || 0;
    _sharedPhase = msg.phase || 0;
    _pendingStep = false;

    // Store latest timing for HUD display
    if (msg.timing) {
      _lastSimMs = msg.timing.simMs;
      _lastSerialMs = msg.timing.serialMs;
    }

    // Log worker timing breakdown (every 30 frames to avoid spam)
    if (_sharedStep % 30 === 0 && msg.timing) {
      const t = msg.timing;
      const total = t.simMs + t.serialMs;
      console.log(
        `[Bridge] Step ${_sharedStep} | sim=${t.simMs}ms ser=${t.serialMs}ms total=${total}ms ` +
        `(${msg.activeCount} cells)`,
      );
    }
  }
}
