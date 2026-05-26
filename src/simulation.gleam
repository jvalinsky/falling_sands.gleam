/// Falling sands simulation using Margolus neighbourhoods
/// Each iteration is divided into 4 phases to ensure parallelizable 2x2 blocks
import gleam/dict
import gleam/list
import gleam/set
import grid.{type Cell, type Grid}

/// Simulation state including history for parallelization
pub opaque type SimState {
  SimState(grid: Grid, phase: Int, step: Int)
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
  let new_grid = process_phase(state.grid, current_phase)

  let next_phase = case current_phase {
    3 -> 0
    _ -> current_phase + 1
  }
  let new_step = case next_phase == 0 {
    True -> state.step + 1
    False -> state.step
  }
  SimState(new_grid, next_phase, new_step)
}

/// Process a single Margolus phase.
/// Uses active-block iteration for sparse grids (< 35% density) —
/// skipping thousands of empty blocks per phase.
/// Falls back to O(W×H) naive iteration for dense grids where
/// the set/dict overhead of active-block mode exceeds the savings.
pub fn process_phase(grid: Grid, phase: Int) -> Grid {
  let width = grid.width(grid)
  let height = grid.height(grid)
  let cells = grid.get_cells(grid)
  let active_cells = dict.size(cells)
  let total_cells = width * height

  // Density threshold: at ~35%+, nearly all blocks contain particles.
  // The set.insert + set.fold overhead overtakes empty-block savings.
  case active_cells * 100 >= total_cells * 35 {
    True -> process_phase_naive(grid, phase)
    False -> {
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

      // Build set of active block origins from active cells (O(active_cells))
      let active_blocks =
        dict.fold(cells, set.new(), fn(blocks, pos, _cell) {
          let #(x, y) = pos
          // Compute the 2×2 block origin for this cell based on phase offset
          let dx = x - offset_x
          let bx = case dx % 2 {
            0 -> x
            _ -> x - 1
          }
          let dy = y - offset_y
          let by = case dy % 2 {
            0 -> y
            _ -> y - 1
          }
          case bx >= 0 && bx + 1 < width && by >= 0 && by + 1 < height {
            True -> set.insert(blocks, #(bx, by))
            False -> blocks
          }
        })

      // Process only blocks that contain at least one active particle
      set.fold(active_blocks, grid, fn(acc_grid, block_pos) {
        let #(bx, by) = block_pos
        process_block(acc_grid, bx, by)
      })
    }
  }
}

/// Process a single 2x2 block
/// Apply particle physics rules independently for this block
fn process_block(grid: Grid, x: Int, y: Int) -> Grid {
  let nw = grid.get(grid, x, y)
  let ne = grid.get(grid, x + 1, y)
  let sw = grid.get(grid, x, y + 1)
  let se = grid.get(grid, x + 1, y + 1)

  // Apply gravity and settling rules
  let #(new_nw, new_ne, new_sw, new_se) =
    apply_block_physics(nw, ne, sw, se, x, y)

  // Only call dict.insert/delete when a cell actually changed.
  // This prevents HAMT churn on cells that stayed the same type.
  let g = grid
  let g = case nw == new_nw {
    True -> g
    False -> grid.set(g, x, y, new_nw)
  }
  let g = case ne == new_ne {
    True -> g
    False -> grid.set(g, x + 1, y, new_ne)
  }
  let g = case sw == new_sw {
    True -> g
    False -> grid.set(g, x, y + 1, new_sw)
  }
  case se == new_se {
    True -> g
    False -> grid.set(g, x + 1, y + 1, new_se)
  }
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
  x: Int,
  y: Int,
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

  // Pseudo-random choice for this block: 50/50 left vs right
  // Uses spatial position as seed for organic, non-repeating patterns
  let go_right = pseudo_random_bool(x, y)

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
    // PRIORITY 2: DIAGONAL FALLING (w/ randomness)
    // (Particles escape when blocked vertically)
    // ========================================
    // Sand diagonal with random direction (both diagonals open)
    grid.Sand, grid.Air, grid.Sand, grid.Air ->
      case go_right {
        True -> #(grid.air(), ne, sw, nw)
        // NW → SE (diagonal right)
        False -> #(grid.air(), nw, sw, se)
        // NW → NE (spread right)
      }
    grid.Air, grid.Sand, grid.Air, grid.Sand ->
      case go_right {
        True -> #(grid.air(), grid.air(), ne, se)
        // NE → SW (diagonal left)
        False -> #(ne, grid.air(), nw, se)
        // NE → NW (spread left)
      }
    // Sand diagonal (NW → SE, blocked by stone below)
    grid.Sand, grid.Air, grid.Stone, grid.Air -> #(grid.air(), ne, sw, nw)
    // Sand diagonal (NE → SW, blocked by stone below)
    grid.Air, grid.Sand, grid.Air, grid.Stone -> #(ne, grid.air(), nw, se)
    // Water diagonal with random direction (both diagonals open)
    grid.Water, grid.Air, grid.Water, grid.Air ->
      case go_right {
        True -> #(grid.air(), ne, sw, nw)
        // NW → SE
        False -> #(grid.air(), nw, sw, se)
        // NW → NE
      }
    grid.Air, grid.Water, grid.Air, grid.Water ->
      case go_right {
        True -> #(grid.air(), grid.air(), ne, se)
        // NE → SE
        False -> #(ne, grid.air(), nw, se)
        // NE → SW
      }
    // Water diagonal (NW → SE, blocked by stone below)
    grid.Water, grid.Air, grid.Stone, grid.Air -> #(grid.air(), ne, sw, nw)
    // Water diagonal (NE → SW, blocked by stone below)
    grid.Air, grid.Water, grid.Air, grid.Stone -> #(ne, grid.air(), nw, se)

    // ========================================
    // PRIORITY 3: WATER HORIZONTAL SPREADING
    // (Water is fluid - spreads when it has an exit)
    // ========================================
    // Water spreads right when both sides available, randomize direction
    grid.Water, grid.Air, grid.Sand, grid.Air ->
      case go_right {
        True -> #(grid.air(), nw, sw, grid.air())
        False -> #(grid.air(), grid.air(), sw, nw)
      }
    // Water random spread right (standard, NE blocked)
    grid.Water, grid.Air, grid.Sand, _ -> #(grid.air(), nw, sw, se)
    grid.Water, grid.Air, grid.Stone, _ -> #(grid.air(), nw, sw, se)
    grid.Water, grid.Air, grid.Water, _ -> #(grid.air(), nw, sw, se)
    // Water spreads left when both sides available, randomize direction
    grid.Air, grid.Water, grid.Air, grid.Sand ->
      case go_right {
        True -> #(nw, grid.air(), sw, ne)
        // NE → SE (diagonal right)
        False -> #(ne, grid.air(), sw, se)
        // NE → NW (spread left)
      }
    // Water random spread left (standard, NW blocked)
    grid.Air, grid.Water, _, grid.Sand -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Water, _, grid.Stone -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Water, _, grid.Water -> #(ne, grid.air(), sw, se)

    // ========================================
    // PRIORITY 4: LAVA INTERACTIONS
    // (Molasses-like: high viscosity, gradual melting)
    // ========================================
    // Lava + Water → Steam + Stone (vaporization + cooling)
    grid.Lava, grid.Water, _, _ -> #(grid.steam(), grid.stone(), sw, se)
    grid.Water, grid.Lava, _, _ -> #(grid.stone(), grid.steam(), sw, se)
    // Lava + Ice → Water + Stone (melting ice)
    grid.Lava, grid.Ice, _, _ -> #(grid.stone(), grid.water(), sw, se)
    grid.Ice, grid.Lava, _, _ -> #(grid.water(), grid.stone(), sw, se)
    // Lava + Oil → Steam + Steam (burning)
    grid.Lava, grid.Oil, _, _ -> #(grid.steam(), grid.steam(), sw, se)
    grid.Oil, grid.Lava, _, _ -> #(grid.steam(), grid.steam(), sw, se)
    // Lava vertical falling with high viscosity (~10% chance)
    grid.Lava, _, grid.Air, _ ->
      case pseudo_random_chance(x, y, 2, 10) {
        True -> #(grid.air(), ne, grid.lava(), se)
        False -> #(nw, ne, sw, se)
      }
    _, grid.Lava, _, grid.Air ->
      case pseudo_random_chance(x, y, 2, 10) {
        True -> #(nw, grid.air(), sw, grid.lava())
        False -> #(nw, ne, sw, se)
      }
    // Lava diagonal sliding with high viscosity (~6% chance)
    grid.Lava, grid.Air, grid.Sand, grid.Air ->
      case pseudo_random_chance(x, y, 3, 6) {
        True -> #(grid.air(), ne, sw, grid.lava())
        False -> #(nw, ne, sw, se)
      }
    grid.Air, grid.Lava, grid.Air, grid.Sand ->
      case pseudo_random_chance(x, y, 3, 6) {
        True -> #(grid.lava(), grid.air(), nw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Lava, grid.Air, grid.Stone, grid.Air ->
      case pseudo_random_chance(x, y, 3, 6) {
        True -> #(grid.air(), ne, sw, grid.lava())
        False -> #(nw, ne, sw, se)
      }
    grid.Air, grid.Lava, grid.Air, grid.Stone ->
      case pseudo_random_chance(x, y, 3, 6) {
        True -> #(grid.lava(), grid.air(), nw, se)
        False -> #(nw, ne, sw, se)
      }
    // Lava horizontal spreading with very high viscosity (~4% chance)
    grid.Lava, grid.Air, grid.Sand, _ ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(grid.air(), nw, sw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Lava, grid.Air, grid.Stone, _ ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(grid.air(), nw, sw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Lava, grid.Air, grid.Water, _ ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(grid.air(), nw, sw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Air, grid.Lava, _, grid.Sand ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(ne, grid.air(), sw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Air, grid.Lava, _, grid.Stone ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(ne, grid.air(), sw, se)
        False -> #(nw, ne, sw, se)
      }
    grid.Air, grid.Lava, _, grid.Water ->
      case pseudo_random_chance(x, y, 4, 4) {
        True -> #(ne, grid.air(), sw, se)
        False -> #(nw, ne, sw, se)
      }
    // Lava + Sand → gradual melting (~30% chance per tick)
    // (only triggers when lava can't move — stuck on top of sand)
    grid.Lava, _, grid.Sand, _ ->
      case pseudo_random_chance(x, y, 1, 30) {
        True -> #(grid.lava(), ne, grid.lava(), se)
        False -> #(nw, ne, sw, se)
      }
    _, grid.Lava, _, grid.Sand ->
      case pseudo_random_chance(x, y, 1, 30) {
        True -> #(nw, grid.lava(), sw, grid.lava())
        False -> #(nw, ne, sw, se)
      }

    // ========================================
    // PRIORITY 5: STEAM INTERACTIONS
    // (Rising gas — anti-gravity, spreads under surfaces)
    // ========================================
    // Steam + Stone → Water + Stone (condensation on cold surface)
    grid.Steam, grid.Stone, _, _ -> #(grid.water(), grid.stone(), sw, se)
    grid.Stone, grid.Steam, _, _ -> #(grid.stone(), grid.water(), sw, se)
    // Steam + Ice → Water + Water (condensation + melting)
    grid.Steam, grid.Ice, _, _ -> #(grid.water(), grid.water(), sw, se)
    grid.Ice, grid.Steam, _, _ -> #(grid.water(), grid.water(), sw, se)
    // Steam vertical rising (anti-gravity: bottom → top)
    grid.Air, _, grid.Steam, _ -> #(grid.steam(), ne, grid.air(), se)
    _, grid.Air, _, grid.Steam -> #(nw, grid.steam(), sw, grid.air())
    // Steam diagonal rising (when blocked straight up by another steam)
    grid.Steam, grid.Air, grid.Steam, grid.Air -> #(
      nw,
      grid.steam(),
      grid.air(),
      se,
    )
    grid.Air, grid.Steam, grid.Air, grid.Steam -> #(
      grid.steam(),
      ne,
      sw,
      grid.air(),
    )
    // Steam horizontal spreading (trapped under solid ceiling)
    grid.Stone, grid.Air, grid.Steam, _ -> #(
      grid.stone(),
      grid.steam(),
      grid.air(),
      se,
    )
    grid.Air, grid.Stone, _, grid.Steam -> #(
      grid.steam(),
      grid.stone(),
      sw,
      grid.air(),
    )
    grid.Ice, grid.Air, grid.Steam, _ -> #(
      grid.ice(),
      grid.steam(),
      grid.air(),
      se,
    )
    grid.Air, grid.Ice, _, grid.Steam -> #(
      grid.steam(),
      grid.ice(),
      sw,
      grid.air(),
    )

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
    // Oil spreads horizontally with randomness
    grid.Oil, grid.Air, grid.Sand, grid.Air ->
      case go_right {
        True -> #(grid.air(), nw, sw, grid.air())
        // NW → NE
        False -> #(grid.air(), grid.air(), sw, nw)
        // NW → SE
      }
    grid.Oil, grid.Air, grid.Sand, _ -> #(grid.air(), nw, sw, se)
    grid.Oil, grid.Air, grid.Water, grid.Air ->
      case go_right {
        True -> #(grid.air(), nw, sw, grid.air())
        // NW → NE
        False -> #(grid.air(), grid.air(), sw, nw)
        // NW → SE
      }
    grid.Oil, grid.Air, grid.Water, _ -> #(grid.air(), nw, sw, se)
    grid.Air, grid.Oil, grid.Air, grid.Sand ->
      case go_right {
        True -> #(nw, grid.air(), sw, ne)
        // NE → SE (diagonal right)
        False -> #(ne, grid.air(), sw, se)
        // NE → NW (spread left)
      }
    grid.Air, grid.Oil, _, grid.Sand -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Oil, grid.Air, grid.Water ->
      case go_right {
        True -> #(nw, grid.air(), sw, ne)
        // NE → SE (diagonal right)
        False -> #(ne, grid.air(), sw, se)
        // NE → NW (spread left)
      }
    grid.Air, grid.Oil, _, grid.Water -> #(ne, grid.air(), sw, se)

    // ========================================
    // PRIORITY 7: ACID INTERACTIONS
    // (Corrosive liquid — flows like water, dissolves gradually)
    // ========================================
    // Acid + Water → Water + Water (instant neutralization)
    grid.Acid, grid.Water, _, _ -> #(grid.water(), grid.water(), sw, se)
    grid.Water, grid.Acid, _, _ -> #(grid.water(), grid.water(), sw, se)
    // Acid vertical falling (instant, thin liquid)
    grid.Acid, _, grid.Air, _ -> #(grid.air(), ne, grid.acid(), se)
    _, grid.Acid, _, grid.Air -> #(nw, grid.air(), sw, grid.acid())
    // Acid diagonal sliding (like water over acid/stone)
    grid.Acid, grid.Air, grid.Acid, grid.Air ->
      case go_right {
        True -> #(grid.air(), ne, sw, nw)
        // NW → SE
        False -> #(grid.air(), nw, sw, se)
        // NW → NE
      }
    grid.Air, grid.Acid, grid.Air, grid.Acid ->
      case go_right {
        True -> #(grid.air(), grid.air(), ne, se)
        // NE → SW
        False -> #(ne, grid.air(), nw, se)
        // NE → NW
      }
    grid.Acid, grid.Air, grid.Stone, grid.Air -> #(grid.air(), ne, sw, nw)
    grid.Air, grid.Acid, grid.Air, grid.Stone -> #(ne, grid.air(), nw, se)
    // Acid horizontal spreading (flows over sand/stone surfaces)
    grid.Acid, grid.Air, grid.Sand, _ -> #(grid.air(), nw, sw, se)
    grid.Acid, grid.Air, grid.Stone, _ -> #(grid.air(), nw, sw, se)
    grid.Air, grid.Acid, _, grid.Sand -> #(ne, grid.air(), sw, se)
    grid.Air, grid.Acid, _, grid.Stone -> #(ne, grid.air(), sw, se)
    // Acid + Sand → gradual dissolution (~25% chance per tick)
    // (only triggers when acid is stuck — can't fall, slide, or spread)
    // Different from lava: acid dissolves into air, lava melts sand into more lava
    grid.Acid, _, grid.Sand, _ ->
      case pseudo_random_chance(x, y, 5, 25) {
        True -> #(grid.acid(), ne, grid.air(), se)
        False -> #(nw, ne, sw, se)
      }
    _, grid.Acid, _, grid.Sand ->
      case pseudo_random_chance(x, y, 5, 25) {
        True -> #(nw, grid.acid(), sw, grid.air())
        False -> #(nw, ne, sw, se)
      }
    // Acid + Stone → slower dissolution (~10% chance per tick)
    grid.Acid, _, grid.Stone, _ ->
      case pseudo_random_chance(x, y, 6, 10) {
        True -> #(grid.acid(), ne, grid.air(), se)
        False -> #(nw, ne, sw, se)
      }
    _, grid.Acid, _, grid.Stone ->
      case pseudo_random_chance(x, y, 6, 10) {
        True -> #(nw, grid.acid(), sw, grid.air())
        False -> #(nw, ne, sw, se)
      }

    // ========================================
    // PRIORITY 8: ICE INTERACTIONS
    // (Frozen water - solid like stone)
    // ========================================
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
  list.fold(list.range(0, count), state, fn(acc_state, _) { step(acc_state) })
}

/// ── O(W×H) baseline for A/B benchmarking ────────────────────────────
/// This is the pre-optimization approach: iterates all 4000 blocks
/// every phase regardless of whether they contain active cells.
/// Used only for measuring the speedup from active-block iteration.

pub fn steps_naive(state: SimState, count: Int) -> SimState {
  list.fold(list.range(0, count), state, fn(acc_state, _) {
    step_naive(acc_state)
  })
}

fn step_naive(state: SimState) -> SimState {
  let current_phase = state.phase
  let new_grid = process_phase_naive(state.grid, current_phase)

  let next_phase = case current_phase {
    3 -> 0
    _ -> current_phase + 1
  }
  let new_step = case next_phase == 0 {
    True -> state.step + 1
    False -> state.step
  }
  SimState(new_grid, next_phase, new_step)
}

fn process_phase_naive(grid: Grid, phase: Int) -> Grid {
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

  // O(W×H): iterate every 2×2 block regardless of content
  list.range(offset_y, height - 2)
  |> list.filter(fn(y) {
    let dy = y - offset_y
    dy % 2 == 0
  })
  |> list.fold(grid, fn(acc_grid, y) {
    list.range(offset_x, width - 2)
    |> list.filter(fn(x) {
      let dx = x - offset_x
      dx % 2 == 0
    })
    |> list.fold(acc_grid, fn(inner_grid, x) {
      process_block(inner_grid, x, y)
    })
  })
}

/// Pseudo-random boolean using spatial position as seed.
/// Produces organic 50/50 patterns without true RNG.
pub fn pseudo_random_bool(x: Int, y: Int) -> Bool {
  // Simple hash mixing spatial coordinates for visual variety
  let hash = x * 374_761_393 + y * 668_265_263
  hash % 2 == 0
}

/// Pseudo-random chance with configurable threshold (0-100).
/// Uses a seed parameter so different behaviours get different patterns.
pub fn pseudo_random_chance(x: Int, y: Int, seed: Int, threshold: Int) -> Bool {
  let hash = x * 374_761_393 + y * 668_265_263 + seed * 91_138_233
  let abs_hash = case hash < 0 {
    True -> -hash
    False -> hash
  }
  abs_hash % 100 < threshold
}

/// Set a cell in the grid during simulation
pub fn set_cell(state: SimState, x: Int, y: Int, cell: Cell) -> SimState {
  SimState(grid.set(state.grid, x, y, cell), state.phase, state.step)
}
