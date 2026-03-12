/// Falling sands simulation using Margolus neighbourhoods
/// Each iteration is divided into 4 phases to ensure parallelizable 2x2 blocks
import gleam/int
import gleam/io
import gleam/list
import grid.{type Grid, type Cell}

/// Simulation state including history for parallelization
pub opaque type SimState {
  SimState(
    grid: Grid,
    phase: Int,
    step: Int,
  )
}

/// Initialize simulation
pub fn new(grid: Grid) -> SimState {
  SimState(grid, 0, 0)
}

/// Get the current grid
pub fn grid(state: SimState) -> Grid {
  state.grid
}

/// Get current phase (0-3 for Margolus)
pub fn phase(state: SimState) -> Int {
  state.phase
}

/// Get current step count
pub fn step_count(state: SimState) -> Int {
  state.step
}

/// Single simulation step using Margolus neighbourhoods
/// Each step processes one Margolus phase
pub fn step(state: SimState) -> SimState {
  let current_phase = state.phase
  let old_cell_count = grid.active_cell_count(state.grid)
  let new_grid = process_phase(state.grid, current_phase)
  let new_cell_count = grid.active_cell_count(new_grid)

  let _ = case old_cell_count != new_cell_count {
    True -> io.println("📋 Cell count changed: " <> int.to_string(old_cell_count) <> " → " <> int.to_string(new_cell_count) <> " in phase " <> int.to_string(current_phase))
    False -> Nil
  }

  let next_phase = case current_phase {
    3 -> 0
    _ -> current_phase + 1
  }
  let new_step = case next_phase == 0 {
    True -> {
      let iteration = state.step + 1
      let _ = io.println("✅ Margolus Iteration " <> int.to_string(iteration) <> " complete (phases 0→1→2→3 finished)")
      iteration
    }
    False -> state.step
  }
  SimState(new_grid, next_phase, new_step)
}

/// Process a single Margolus phase
/// Phase determines which blocks to process based on (x + offset_x, y + offset_y) alignment
fn process_phase(grid: Grid, phase: Int) -> Grid {
  let offset_x = case phase {
    0 | 1 -> 0
    2 | 3 -> 1
    _ -> 0
  }
  let offset_y = case phase {
    0 | 2 -> 0
    1 | 3 -> 1
    _ -> 0
  }

  let width = grid.width(grid)
  let height = grid.height(grid)

  // Generate all block positions for this phase (every 2 cells with the given offset)
  let is_valid_block_y = fn(y) {
    let offset = y - offset_y
    offset >= 0 && offset % 2 == 0 && y + 1 < height
  }
  let is_valid_block_x = fn(x) {
    let offset = x - offset_x
    offset >= 0 && offset % 2 == 0 && x + 1 < width
  }

  let ys = list.range(offset_y, height) |> list.filter(is_valid_block_y)
  let xs = list.range(offset_x, width) |> list.filter(is_valid_block_x)

  // Process blocks by folding over y coordinates then x coordinates
  list.fold(ys, grid, fn(grid_y, y) {
    list.fold(xs, grid_y, fn(grid_xy, x) {
      process_block(grid_xy, x, y)
    })
  })
}

/// Process a single 2x2 block
/// Apply particle physics rules independently for this block
fn process_block(grid: Grid, x: Int, y: Int) -> Grid {
  let nw = grid.get(grid, x, y)
  let ne = grid.get(grid, x + 1, y)
  let sw = grid.get(grid, x, y + 1)
  let se = grid.get(grid, x + 1, y + 1)

  // Apply gravity and settling rules
  let #(new_nw, new_ne, new_sw, new_se) = apply_block_physics(
    nw, ne, sw, se,
  )

  grid
  |> grid.set(x, y, new_nw)
  |> grid.set(x + 1, y, new_ne)
  |> grid.set(x, y + 1, new_sw)
  |> grid.set(x + 1, y + 1, new_se)
}

/// Apply physics rules to a 2x2 block
/// Returns new cell values for (nw, ne, sw, se) positions
/// CRITICAL: Rules must SWAP cells, never CREATE or DESTROY them!
/// Each 2x2 block is a closed system - particles move within it.
fn apply_block_physics(
  nw: Cell,
  ne: Cell,
  sw: Cell,
  se: Cell,
) -> #(Cell, Cell, Cell, Cell) {
  // Margolus neighborhood rules with proper priority:
  // 1. Vertical falling (gravity)
  // 2. Diagonal falling (when blocked vertically)
  // 3. Water horizontal spreading (when fully blocked)
  // Particles SWAP positions, they don't duplicate!

  let nw_type = grid.cell_type(nw)
  let ne_type = grid.cell_type(ne)
  let sw_type = grid.cell_type(sw)
  let se_type = grid.cell_type(se)

  case nw_type, ne_type, sw_type, se_type {
    // ========================================
    // PRIORITY 1: VERTICAL FALLING
    // ========================================
    // Sand falls down left (NW → SW)
    grid.Sand, _, grid.Air, _ -> #(grid.air(), ne, nw, se)
    // Sand falls down right (NE → SE)
    _, grid.Sand, _, grid.Air -> #(nw, grid.air(), sw, ne)
    // Water flows down left (NW → SW)
    grid.Water, _, grid.Air, _ -> #(grid.air(), ne, nw, se)
    // Water flows down right (NE → SE)
    _, grid.Water, _, grid.Air -> #(nw, grid.air(), sw, ne)

    // ========================================
    // PRIORITY 2: DIAGONAL FALLING
    // (Particles escape when blocked vertically)
    // ========================================
    // Sand diagonal right (NW → SE, blocked by sand below)
    grid.Sand, grid.Air, grid.Sand, grid.Air -> #(grid.air(), ne, sw, nw)
    // Sand diagonal left (NE → SW, blocked by sand below)
    grid.Air, grid.Sand, grid.Air, grid.Sand -> #(ne, grid.air(), nw, se)
    // Sand diagonal right (NW → SE, blocked by stone below)
    grid.Sand, grid.Air, grid.Stone, grid.Air -> #(grid.air(), ne, sw, nw)
    // Sand diagonal left (NE → SW, blocked by stone below)
    grid.Air, grid.Sand, grid.Air, grid.Stone -> #(ne, grid.air(), nw, se)
    // Water diagonal right (NW → SE, blocked by water below)
    grid.Water, grid.Air, grid.Water, grid.Air -> #(grid.air(), ne, sw, nw)
    // Water diagonal left (NE → SW, blocked by water below)
    grid.Air, grid.Water, grid.Air, grid.Water -> #(ne, grid.air(), nw, se)
    // Water diagonal right (NW → SE, blocked by stone below)
    grid.Water, grid.Air, grid.Stone, grid.Air -> #(grid.air(), ne, sw, nw)
    // Water diagonal left (NE → SW, blocked by stone below)
    grid.Air, grid.Water, grid.Air, grid.Stone -> #(ne, grid.air(), nw, se)

    // ========================================
    // PRIORITY 3: WATER HORIZONTAL SPREADING
    // (Water is fluid - spreads when it has an exit)
    // ========================================
    // Water spreads right when NE is air and below is solid (sand/stone/water)
    grid.Water, grid.Air, grid.Sand, _ -> #(grid.air(), nw, sw, se)
    grid.Water, grid.Air, grid.Stone, _ -> #(grid.air(), nw, sw, se)
    grid.Water, grid.Air, grid.Water, _ -> #(grid.air(), nw, sw, se)
    // Water spreads left when NW is air and below is solid (sand/stone/water)
    grid.Air, grid.Water, _, grid.Sand -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Water, _, grid.Stone -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Water, _, grid.Water -> #(ne, grid.air(), sw, se)

    // ========================================
    // PRIORITY 4: LAVA INTERACTIONS
    // (Hot liquid that transforms materials)
    // ========================================
    // Lava + Water → Steam + Stone (vaporization + cooling)
    grid.Lava, grid.Water, _, _ -> #(grid.steam(), grid.stone(), sw, se)
    grid.Water, grid.Lava, _, _ -> #(grid.stone(), grid.steam(), sw, se)
    // Sand + Lava → Lava + Lava (melting - sand converts to lava)
    grid.Lava, _, grid.Sand, _ -> #(grid.lava(), ne, grid.lava(), se)
    _, grid.Lava, _, grid.Sand -> #(nw, grid.lava(), sw, grid.lava())
    // Lava + Oil → Steam + Steam (burning)
    grid.Lava, grid.Oil, _, _ -> #(grid.steam(), grid.steam(), sw, se)
    grid.Oil, grid.Lava, _, _ -> #(grid.steam(), grid.steam(), sw, se)
    // Lava falls like heavy water
    grid.Lava, _, grid.Air, _ -> #(grid.air(), ne, grid.lava(), se)
    _, grid.Lava, _, grid.Air -> #(nw, grid.air(), sw, grid.lava())

    // ========================================
    // PRIORITY 5: STEAM INTERACTIONS
    // (Rising gas - anti-gravity)
    // ========================================
    // Steam rises (swaps with particles below to go up)
    grid.Steam, _, grid.Air, _ -> #(grid.air(), ne, grid.steam(), se)
    _, grid.Steam, _, grid.Air -> #(nw, grid.air(), sw, grid.steam())
    // Steam + Stone → Water + Stone (condensation on cold surface)
    grid.Steam, grid.Stone, _, _ -> #(grid.water(), grid.stone(), sw, se)
    grid.Stone, grid.Steam, _, _ -> #(grid.stone(), grid.water(), sw, se)

    // ========================================
    // PRIORITY 6: OIL INTERACTIONS
    // (Floats on water - density sorting)
    // ========================================
    // Oil + Water → Oil rises, Water sinks (density separation)
    grid.Oil, grid.Water, _, _ -> #(grid.water(), grid.oil(), sw, se)
    grid.Water, grid.Oil, _, _ -> #(grid.oil(), grid.water(), sw, se)
    // Oil falls through air like water
    grid.Oil, _, grid.Air, _ -> #(grid.air(), ne, grid.oil(), se)
    _, grid.Oil, _, grid.Air -> #(nw, grid.air(), sw, grid.oil())
    // Oil spreads horizontally like water
    grid.Oil, grid.Air, grid.Sand, _ -> #(grid.air(), grid.oil(), sw, se)
    grid.Oil, grid.Air, grid.Water, _ -> #(grid.air(), grid.oil(), sw, se)
    grid.Air, grid.Oil, _, grid.Sand -> #(grid.oil(), grid.air(), sw, se)
    grid.Air, grid.Oil, _, grid.Water -> #(grid.oil(), grid.air(), sw, se)

    // ========================================
    // PRIORITY 7: ACID INTERACTIONS
    // (Corrosive liquid that dissolves solids)
    // ========================================
    // Acid + Sand → Acid + Air (dissolution)
    grid.Acid, _, grid.Sand, _ -> #(grid.acid(), ne, grid.air(), se)
    _, grid.Acid, _, grid.Sand -> #(nw, grid.acid(), sw, grid.air())
    // Acid + Stone → Acid + Air (slower dissolution - takes multiple passes)
    grid.Acid, _, grid.Stone, _ -> #(grid.acid(), ne, grid.air(), se)
    _, grid.Acid, _, grid.Stone -> #(nw, grid.acid(), sw, grid.air())
    // Acid + Water → Water + Water (neutralization)
    grid.Acid, grid.Water, _, _ -> #(grid.water(), grid.water(), sw, se)
    grid.Water, grid.Acid, _, _ -> #(grid.water(), grid.water(), sw, se)
    // Acid falls like water
    grid.Acid, _, grid.Air, _ -> #(grid.air(), ne, grid.acid(), se)
    _, grid.Acid, _, grid.Air -> #(nw, grid.air(), sw, grid.acid())

    // ========================================
    // PRIORITY 8: ICE INTERACTIONS
    // (Frozen water - solid like stone)
    // ========================================
    // Ice + Lava → Water + Stone (rapid melting)
    grid.Ice, grid.Lava, _, _ -> #(grid.water(), grid.stone(), sw, se)
    grid.Lava, grid.Ice, _, _ -> #(grid.stone(), grid.water(), sw, se)
    // Ice + Steam → Water + Water (melting from heat)
    grid.Ice, grid.Steam, _, _ -> #(grid.water(), grid.water(), sw, se)
    grid.Steam, grid.Ice, _, _ -> #(grid.water(), grid.water(), sw, se)
    // Water + Ice → Ice + Ice (freezing - water converts to ice)
    grid.Water, grid.Ice, _, _ -> #(grid.ice(), grid.ice(), sw, se)
    grid.Ice, _, grid.Water, _ -> #(grid.ice(), ne, grid.ice(), se)

    // ========================================
    // DEFAULT: No change
    // ========================================
    _, _, _, _ -> #(nw, ne, sw, se)
  }
}

/// Run multiple steps
pub fn steps(state: SimState, count: Int) -> SimState {
  list.fold(list.range(0, count), state, fn(acc_state, _) {
    step(acc_state)
  })
}

/// Set a cell in the grid during simulation
pub fn set_cell(state: SimState, x: Int, y: Int, cell: Cell) -> SimState {
  let cell_type = case grid.cell_type(cell) {
    grid.Sand -> "Sand"
    grid.Water -> "Water"
    grid.Stone -> "Stone"
    grid.Air -> "Air"
    grid.Lava -> "Lava"
    grid.Steam -> "Steam"
    grid.Oil -> "Oil"
    grid.Acid -> "Acid"
    grid.Ice -> "Ice"
  }
  let _ = io.println("📍 Setting " <> cell_type <> " at (" <> int.to_string(x) <> ", " <> int.to_string(y) <> ")")
  SimState(grid.set(state.grid, x, y, cell), state.phase, state.step)
}
