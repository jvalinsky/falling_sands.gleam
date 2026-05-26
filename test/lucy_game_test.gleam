import gleam/list
import gleeunit
import gleeunit/should

import grid
import simulation

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================================
// GRID TESTS - Verify sparse grid behavior
// ============================================================================

// Test 1: Empty grid has 0 active cells
pub fn test_empty_grid_has_zero_cells() {
  let g = grid.filled_with_air(160, 100)
  let cells = grid.to_list(g)
  cells
  |> list.length()
  |> should.equal(0)
}

// Test 2: Adding sand increases cell count by 1
pub fn test_adding_one_sand_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let cells = grid.to_list(g2)
  cells
  |> list.length()
  |> should.equal(1)
}

// Test 3: Adding multiple cells
pub fn test_adding_multiple_cells() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 11, 10, grid.sand())
  let g4 = grid.set(g3, 12, 10, grid.water())
  let cells = grid.to_list(g4)
  cells
  |> list.length()
  |> should.equal(3)
}

// Test 4: Overwriting a cell doesn't increase count
pub fn test_overwriting_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 10, 10, grid.water())
  // Overwrite
  let cells = grid.to_list(g3)
  cells
  |> list.length()
  |> should.equal(1)
}

// Test 5: Setting air REMOVES cell (sparse grid!)
pub fn test_setting_air_removes_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 10, 10, grid.air())
  // Set to air (erase)
  let cells = grid.to_list(g3)
  cells
  |> list.length()
  |> should.equal(0)
  // Should be 0 in truly sparse grid!
}

// Test 6: Get returns correct cell type
pub fn test_get_returns_correct_type() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 5, 5, grid.sand())
  let cell = grid.get(g2, 5, 5)
  let cell_type = grid.cell_type(cell)
  case cell_type {
    grid.Sand -> Nil
    _ -> should.fail()
  }
}

// Test 7: Get empty cell returns air
pub fn test_get_empty_returns_air() {
  let g = grid.filled_with_air(160, 100)
  let cell = grid.get(g, 50, 50)
  let cell_type = grid.cell_type(cell)
  case cell_type {
    grid.Air -> Nil
    _ -> should.fail()
  }
}

// Test 8: Grid active cell count function
pub fn test_active_cell_count() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 0, 0, grid.sand())
  let g3 = grid.set(g2, 1, 0, grid.sand())
  let g4 = grid.set(g3, 2, 0, grid.water())
  let count = grid.active_cell_count(g4)
  count
  |> should.equal(3)
}

// ============================================================================
// PHYSICS TESTS - Verify particles move, not duplicate!
// ============================================================================

// Test 9: Sand falls without duplicating (THE CRITICAL TEST)
pub fn test_sand_falls_without_duplicating() {
  let g = grid.filled_with_air(160, 100)
  // Place 1 sand particle
  let g2 = grid.set(g, 10, 10, grid.sand())

  let sim = simulation.new(g2)
  // Run 4 phases (1 full iteration)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)
  let #(sand, _water, _) = grid.get_stats(final_grid)

  // CRITICAL: Should still be 1 particle, not 2!
  count
  |> should.equal(1)
  sand
  |> should.equal(1)
}

// Test 10: Multiple sand particles don't explode exponentially
pub fn test_multiple_sand_no_explosion() {
  let g = grid.filled_with_air(160, 100)
  // Place 10 sand particles
  let g2 =
    list.fold(list.range(0, 10), g, fn(grid, i) {
      grid.set(grid, 10 + i, 10, grid.sand())
    })

  let sim = simulation.new(g2)
  // Run 40 phases (10 full iterations)
  let sim_final = simulation.steps(sim, 40)

  let final_grid = simulation.grid(sim_final)
  let #(sand, _, _) = grid.get_stats(final_grid)

  // Should still be 11 sand particles (list.range(0, 10) creates 11 elements)
  sand
  |> should.equal(11)
}

// Test 11: Water particle doesn't duplicate
pub fn test_water_particle_no_duplication() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 50, 50, grid.water())

  let sim = simulation.new(g2)
  let sim2 = simulation.steps(sim, 8)
  // 2 full iterations

  let final_grid = simulation.grid(sim2)
  let #(_, water, _) = grid.get_stats(final_grid)

  // Should be 1 water particle (not duplicated)
  water
  |> should.equal(1)
}

// Test 12: Sand falls with water (mixed particles)
pub fn test_mixed_particles_dont_duplicate() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 11, 10, grid.water())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let #(sand, water, stone) = grid.get_stats(final_grid)
  let final_count = sand + water + stone

  // Should still be 2 total particles (1 sand + 1 water)
  final_count
  |> should.equal(2)
}

// Test 13: CRITICAL - Sand actually falls after complete Margolus iteration
pub fn test_sand_falls_after_complete_iteration() {
  let g = grid.filled_with_air(10, 10)
  // Place sand at top middle
  let g2 = grid.set(g, 5, 0, grid.sand())

  let sim = simulation.new(g2)
  // Run 4 phases = 1 complete Margolus iteration
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  // Sand falls 1 cell per phase, so after 4 phases it should have moved down
  let sand_at_top = grid.get(final_grid, 5, 0)

  // Count active cells - should still be 1 (particle conservation)
  let active_count = grid.active_cell_count(final_grid)

  // Verify sand moved (original position is now air)
  let sand_moved = case grid.cell_type(sand_at_top) {
    grid.Air -> True
    _ -> False
  }

  let conserved = active_count == 1

  case sand_moved, conserved {
    True, True -> Nil
    False, _ -> should.fail()
    True, False -> should.fail()
  }
}

// ============================================================================
// REACTION TESTS - Verify conservation for instant reactions
// ============================================================================

// Test 14: Lava + Water → Steam + Stone (2 cells → 2 cells)
pub fn test_lava_water_vaporization_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place lava and water adjacent (NW=LAVA, NE=WATER → STEAM, STONE)
  let g2 = grid.set(g, 2, 4, grid.lava())
  let g3 = grid.set(g2, 3, 4, grid.water())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Lava+Water → Steam+Stone: 2 particles go in, 2 come out
  count
  |> should.equal(2)
}

// Test 15: Steam + Stone → Water + Stone (condensation, 2 cells → 2 cells)
pub fn test_steam_stone_condensation_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place steam and stone horizontally at same y so they share a 2×2 block
  // In phase 0, block (4,4) covers (4,4),(5,4),(4,5),(5,5): NW=Stone, NE=Steam
  // Condensation rule (priority 5) fires before steam can rise
  let g2 = grid.set(g, 4, 4, grid.stone())
  let g3 = grid.set(g2, 5, 4, grid.steam())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Steam+Stone → Water+Stone: 2 → 2
  count
  |> should.equal(2)
}

// Test 16: Acid + Water → Water + Water (neutralization, 2 cells → 2 cells)
pub fn test_acid_water_neutralization_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place acid and water adjacent (NW=ACID, NE=WATER → WATER, WATER)
  let g2 = grid.set(g, 2, 4, grid.acid())
  let g3 = grid.set(g2, 3, 4, grid.water())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Acid+Water → Water+Water: 2 → 2
  count
  |> should.equal(2)
}

// Test 17: Lava + Oil → Steam + Steam (burning, 2 cells → 2 cells)
pub fn test_lava_oil_burning_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place lava and oil adjacent (NW=LAVA, NE=OIL → STEAM, STEAM)
  let g2 = grid.set(g, 2, 4, grid.lava())
  let g3 = grid.set(g2, 3, 4, grid.oil())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Lava+Oil → Steam+Steam: 2 → 2
  count
  |> should.equal(2)
}

// ============================================================================
// GRADUAL REACTION TESTS - Verify no particle duplication over many steps
// ============================================================================

// Test 18: Lava + Sand — gradual melting, no duplication
// Lava melts sand into more lava slowly (30% chance). Over 40 phases,
// some melting should occur, but particle count must never exceed input.
pub fn test_lava_sand_melting_no_duplication() {
  let g = grid.filled_with_air(10, 10)
  // Place lava ABOVE sand (they will end up NW=LAVA, SW=SAND in a block)
  let g2 = grid.set(g, 4, 4, grid.lava())
  let g3 = grid.set(g2, 4, 5, grid.sand())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 40)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // In Margolus, one sand + one lava: melting produces TWO lava (NW + SW)
  // But the total count stays 2. Sand turns to lava, never creates new cells.
  // So count should be exactly 2 (sand was consumed or still sand).
  count
  |> should.equal(2)
}

// Test 19: Acid + Sand — gradual dissolution, cell destruction is OK
// Acid dissolves sand into air (25% chance). Particles CAN decrease.
// But they must never increase beyond the starting count.
pub fn test_acid_sand_dissolution_no_duplication() {
  let g = grid.filled_with_air(10, 10)
  // Place acid ABOVE sand
  let g2 = grid.set(g, 4, 4, grid.acid())
  let g3 = grid.set(g2, 4, 5, grid.sand())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 40)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Acid dissolves sand into air → sand is deleted from dict
  // Count can only go DOWN (2 → 1), never up
  case count >= 1 && count <= 2 {
    True -> Nil
    False -> should.fail()
  }
}

// Test 20: Acid + Stone — slow dissolution, no duplication
// Acid dissolves stone into air (10% chance). Very slow.
pub fn test_acid_stone_dissolution_no_duplication() {
  let g = grid.filled_with_air(10, 10)
  // Place acid ABOVE stone
  let g2 = grid.set(g, 4, 4, grid.acid())
  let g3 = grid.set(g2, 4, 5, grid.stone())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 40)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Acid dissolves stone into air → stone is deleted from dict
  // Count can only go DOWN (2 → 1), never up.
  case count >= 1 && count <= 2 {
    True -> Nil
    False -> should.fail()
  }
}

// Test 21: Lava + Ice → Water + Stone (instant melting, 2 cells → 2 cells)
pub fn test_lava_ice_melting_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place lava and ice adjacent (NW=LAVA, NE=ICE → STONE, WATER)
  let g2 = grid.set(g, 2, 4, grid.lava())
  let g3 = grid.set(g2, 3, 4, grid.ice())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Lava+Ice → Stone+Water: 2 → 2
  count
  |> should.equal(2)
}

// Test 22: Steam + Ice → Water + Water (condensation + melting, 2 cells → 2 cells)
pub fn test_steam_ice_condensation_conserves_particles() {
  let g = grid.filled_with_air(10, 10)
  // Place steam and ice horizontally at same y so they share a 2×2 block
  // In phase 0, block (4,4) covers (4,4),(5,4),(4,5),(5,5): NW=Ice, NE=Steam
  // Condensation rule (priority 5) fires before steam can rise
  let g2 = grid.set(g, 4, 4, grid.ice())
  let g3 = grid.set(g2, 5, 4, grid.steam())

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)

  // Steam+Ice → Water+Water: 2 → 2
  count
  |> should.equal(2)
}

// ============================================================================
// PSEUDORANDOM TESTS - Verify deterministic hashing for physics steering
// ============================================================================

// Test 23: pseudo_random_bool is deterministic
pub fn test_pseudo_random_bool_is_deterministic() {
  let a = simulation.pseudo_random_bool(10, 20)
  let b = simulation.pseudo_random_bool(10, 20)
  case a == b {
    True -> Nil
    False -> should.fail()
  }
}

// Test 24: pseudo_random_bool gives different results for different positions
pub fn test_pseudo_random_bool_varies_by_position() {
  // Count how many positions return True out of 101 — should be roughly 50
  let count =
    list.fold(list.range(0, 100), 0, fn(acc, i) {
      case simulation.pseudo_random_bool(i, 0) {
        True -> acc + 1
        False -> acc
      }
    })
  // With 100 samples, 50/50 hash should give 30-70 range (very conservative)
  case count >= 30 && count <= 70 {
    True -> Nil
    False -> should.fail()
  }
}

// Test 25: pseudo_random_chance threshold 0 always returns False
pub fn test_pseudo_random_chance_zero_threshold() {
  let result =
    list.fold(list.range(0, 50), True, fn(acc, i) {
      acc && !simulation.pseudo_random_chance(i, 0, 1, 0)
    })
  case result {
    True -> Nil
    False -> should.fail()
  }
}

// Test 26: pseudo_random_chance threshold 100 always returns True
pub fn test_pseudo_random_chance_hundred_threshold() {
  let result =
    list.fold(list.range(0, 50), True, fn(acc, i) {
      acc && simulation.pseudo_random_chance(i, 0, 1, 100)
    })
  case result {
    True -> Nil
    False -> should.fail()
  }
}

// Test 27: pseudo_random_chance respects threshold scaling
// Higher threshold → more True results.
pub fn test_pseudo_random_chance_higher_threshold_more_true() {
  let count_low =
    list.fold(list.range(0, 200), 0, fn(acc, i) {
      case simulation.pseudo_random_chance(i, 0, 1, 10) {
        True -> acc + 1
        False -> acc
      }
    })
  let count_high =
    list.fold(list.range(0, 200), 0, fn(acc, i) {
      case simulation.pseudo_random_chance(i, 0, 1, 90) {
        True -> acc + 1
        False -> acc
      }
    })
  // Higher threshold (90) should produce more True than lower (10)
  case count_high > count_low {
    True -> Nil
    False -> should.fail()
  }
}

// Test 28: pseudo_random_chance different seeds produce different patterns
pub fn test_pseudo_random_chance_seeds_are_independent() {
  // Two seeds should NOT produce identical results across many positions
  let match_count =
    list.fold(list.range(0, 100), 0, fn(acc, i) {
      let a = simulation.pseudo_random_chance(i, 0, 1, 50)
      let b = simulation.pseudo_random_chance(i, 0, 2, 50)
      case a == b {
        True -> acc + 1
        False -> acc
      }
    })
  // If seeds are truly independent, matches should be well below 100
  // With 50% threshold, roughly half would match by chance. Allow 25-75.
  case match_count <= 75 {
    True -> Nil
    False -> should.fail()
  }
}

// Test 29: pseudo_random_chance threshold 50 gives roughly 50/50 distribution
pub fn test_pseudo_random_chance_50_percent() {
  let count =
    list.fold(list.range(0, 200), 0, fn(acc, i) {
      case simulation.pseudo_random_chance(i, 0, 1, 50) {
        True -> acc + 1
        False -> acc
      }
    })
  // 200 samples at 50% should give 75-125 range (very conservative)
  case count >= 75 && count <= 125 {
    True -> Nil
    False -> should.fail()
  }
}
