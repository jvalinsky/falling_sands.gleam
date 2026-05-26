/**
 * Lucy Game - Simulation Web Worker
 * Offloads Margolus neighbourhood simulation from the UI thread.
 *
 * Request-driven: responds to "init", "step", "draw", "config", "reset" messages.
 * No internal loop — the main thread controls pacing.
 *
 * Message protocol:
 *   Main → Worker:
 *     { type: "init", width: Int, height: Int }
 *     { type: "step", stepsPerFrame: Int }
 *     { type: "draw", x: Int, y: Int, cellType: String }
 *     { type: "config", stepsPerFrame: Int }
 *     { type: "reset", width: Int, height: Int }
 *
 *   Worker → Main:
 *     { type: "ready", activeCells: Int, width: Int, height: Int }
 *     { type: "grid", cells: Array, activeCount: Int, step: Int, phase: Int, width: Int, height: Int }
 */

import * as grid from "./lucy_game/grid.mjs";
import * as simulation from "./lucy_game/simulation.mjs";

// ── Worker State ────────────────────────────────────────────────────

let simState = null;
let stepsPerFrame = 4;
let _lastSimMs = 0;

// ── Cell Type Mapping ───────────────────────────────────────────────

const cellTypeToConstructor = {
  "Air": grid.air,
  "Sand": grid.sand,
  "Water": grid.water,
  "Stone": grid.stone,
  "Lava": grid.lava,
  "Steam": grid.steam,
  "Oil": grid.oil,
  "Acid": grid.acid,
  "Ice": grid.ice,
};

// ── Grid Serialization ──────────────────────────────────────────────

function sendGridState() {
  const serializationStart = performance.now();
  const g = simulation.grid(simState);
  const cells = grid.to_list(g);
  const activeCount = grid.active_cell_count(g);

  // Serialize cells as a flat array of [x, y, typeIndex]
  const cellArray = [];
  for (const entry of cells) {
    const [pos, cell] = entry;
    const [x, y] = pos;
    const cellType = grid.cell_type(cell);
    // Convert Gleam custom type to simple index
    let typeIndex;
    if (cellType instanceof grid.CellType$Sand) typeIndex = 1;
    else if (cellType instanceof grid.CellType$Water) typeIndex = 2;
    else if (cellType instanceof grid.CellType$Stone) typeIndex = 3;
    else if (cellType instanceof grid.CellType$Lava) typeIndex = 4;
    else if (cellType instanceof grid.CellType$Steam) typeIndex = 5;
    else if (cellType instanceof grid.CellType$Oil) typeIndex = 6;
    else if (cellType instanceof grid.CellType$Acid) typeIndex = 7;
    else if (cellType instanceof grid.CellType$Ice) typeIndex = 8;
    else typeIndex = 0; // Air

    cellArray.push(x, y, typeIndex);
  }
  const serializationMs = Math.round((performance.now() - serializationStart) * 100) / 100;

  self.postMessage({
    type: "grid",
    cells: cellArray,
    activeCount: activeCount,
    step: simulation.step_count(simState),
    phase: simulation.phase(simState),
    width: grid.width(g),
    height: grid.height(g),
    timing: {
      simMs: _lastSimMs,
      serialMs: serializationMs,
    },
  });
}

// ── Message Handler ─────────────────────────────────────────────────

self.onmessage = (event) => {
  const msg = event.data;

  switch (msg.type) {
    case "init": {
      const g = grid.filled_with_air(msg.width, msg.height);
      simState = simulation.new$(g);
      self.postMessage({
        type: "ready",
        activeCells: 0,
        width: msg.width,
        height: msg.height,
      });
      break;
    }

    case "step": {
      if (!simState) break;
      stepsPerFrame = msg.stepsPerFrame || 4;
      const simStart = performance.now();
      simState = simulation.steps(simState, stepsPerFrame);
      _lastSimMs = Math.round((performance.now() - simStart) * 100) / 100;
      sendGridState();
      break;
    }

    case "draw": {
      if (!simState) break;
      const cellFn = cellTypeToConstructor[msg.cellType];
      if (!cellFn) break;
      const cell = cellFn();
      simState = simulation.set_cell(simState, msg.x, msg.y, cell);
      break;
    }

    case "config": {
      if (msg.stepsPerFrame) stepsPerFrame = msg.stepsPerFrame;
      break;
    }

    case "reset": {
      const g = grid.filled_with_air(msg.width || 160, msg.height || 100);
      simState = simulation.new$(g);
      self.postMessage({
        type: "ready",
        activeCells: 0,
        width: msg.width || 160,
        height: msg.height || 100,
      });
      break;
    }

    default: {
      console.warn("[SimWorker] Unknown message type:", msg.type);
    }
  }
};
