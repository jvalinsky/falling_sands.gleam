//// Bridge module for Web Worker communication (JS target only).
//// Delegates simulation to a worker thread via FFI, with sync fallback.

import grid.{type Grid}

@external(javascript, "./sim_bridge_ffi.mjs", "initGrid")
pub fn init_grid(width: Int, height: Int) -> Grid

@external(javascript, "./sim_bridge_ffi.mjs", "tickSimulation")
pub fn tick_simulation(steps_per_frame: Int) -> Grid

@external(javascript, "./sim_bridge_ffi.mjs", "getStepCount")
pub fn get_step_count() -> Int

@external(javascript, "./sim_bridge_ffi.mjs", "getPhase")
pub fn get_phase() -> Int

@external(javascript, "./sim_bridge_ffi.mjs", "drawCell")
pub fn draw_cell(x: Int, y: Int, type_index: Int) -> Grid

@external(javascript, "./sim_bridge_ffi.mjs", "resetGrid")
pub fn reset_grid(width: Int, height: Int) -> Grid

@external(javascript, "./sim_bridge_ffi.mjs", "setWorkerConfig")
pub fn set_worker_config(steps_per_frame: Int) -> Nil

@external(javascript, "./sim_bridge_ffi.mjs", "getWorkerTimingStr")
pub fn get_worker_timing() -> String
