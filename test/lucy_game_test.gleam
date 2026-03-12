import gleam/int
import gleam/io
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
  let _ = io.println("[TEST 1] Empty grid cell count = " <> int.to_string(list.length(cells)))
  cells
  |> list.length()
  |> should.equal(0)
}

// Test 2: Adding sand increases cell count by 1
pub fn test_adding_one_sand_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let cells = grid.to_list(g2)
  let _ = io.println("[TEST 2] After adding 1 sand cell, count = " <> int.to_string(list.length(cells)))
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
  let _ = io.println("[TEST 3] After adding 3 cells, count = " <> int.to_string(list.length(cells)))
  cells
  |> list.length()
  |> should.equal(3)
}

// Test 4: Overwriting a cell doesn't increase count
pub fn test_overwriting_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 10, 10, grid.water())  // Overwrite
  let cells = grid.to_list(g3)
  let _ = io.println("[TEST 4] After overwriting 1 cell, count = " <> int.to_string(list.length(cells)))
  cells
  |> list.length()
  |> should.equal(1)
}

// Test 5: Setting air REMOVES cell (sparse grid!)
pub fn test_setting_air_removes_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 10, 10, grid.air())  // Set to air (erase)
  let cells = grid.to_list(g3)
  let _ = io.println("[TEST 5] After setting cell to air, count = " <> int.to_string(list.length(cells)))
  cells
  |> list.length()
  |> should.equal(0)  // Should be 0 in truly sparse grid!
}

// Test 6: Get returns correct cell type
pub fn test_get_returns_correct_type() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 5, 5, grid.sand())
  let cell = grid.get(g2, 5, 5)
  let cell_type = grid.cell_type(cell)
  let _ = io.println("[TEST 6] Got cell type at (5,5)")
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
  let _ = io.println("[TEST 7] Got cell from empty position")
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
  let _ = io.println("[TEST 8] Active cell count = " <> int.to_string(count))
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
  let _ = io.println("[TEST 9] Initial: 1 sand at (10,10)")

  let sim = simulation.new(g2)
  // Run 4 phases (1 full iteration)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let count = grid.active_cell_count(final_grid)
  let #(sand, water, stone) = grid.get_stats(final_grid)

  let _ = io.println("[TEST 9] After 4 phases: " <> int.to_string(count) <> " cells (Sand: " <> int.to_string(sand) <> ", Water: " <> int.to_string(water) <> ")")

  // CRITICAL: Should still be 1 particle, not 2!
  sand
  |> should.equal(1)
}

// Test 10: Multiple sand particles don't explode exponentially
pub fn test_multiple_sand_no_explosion() {
  let g = grid.filled_with_air(160, 100)
  // Place 10 sand particles
  let g2 = list.fold(list.range(0, 10), g, fn(grid, i) {
    grid.set(grid, 10 + i, 10, grid.sand())
  })

  let initial_count = grid.active_cell_count(g2)
  let _ = io.println("[TEST 10] Initial: " <> int.to_string(initial_count) <> " cells")

  let sim = simulation.new(g2)
  // Run 40 phases (10 full iterations)
  let sim_final = simulation.steps(sim, 40)

  let final_grid = simulation.grid(sim_final)
  let final_count = grid.active_cell_count(final_grid)
  let #(sand, _, _) = grid.get_stats(final_grid)

  let _ = io.println("[TEST 10] After 40 phases: " <> int.to_string(final_count) <> " cells")

  // Should still be 10 sand particles, maybe slightly more due to spreading, but NOT 160 or 1600!
  sand
  |> should.equal(10)
}

// Test 11: Water particle doesn't duplicate
pub fn test_water_particle_no_duplication() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 50, 50, grid.water())

  let sim = simulation.new(g2)
  let sim2 = simulation.steps(sim, 8)  // 2 full iterations

  let final_grid = simulation.grid(sim2)
  let #(sand, water, stone) = grid.get_stats(final_grid)

  let _ = io.println("[TEST 11] Water after 8 phases: count = " <> int.to_string(water))

  // Should be 1 water particle (not duplicated)
  water
  |> should.equal(1)
}

// Test 12: Sand falls with water (mixed particles)
pub fn test_mixed_particles_dont_duplicate() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 11, 10, grid.water())

  let _initial_sand = grid.active_cell_count(g3)
  let _ = io.println("[TEST 12] Initial: 2 mixed particles")

  let sim = simulation.new(g3)
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let #(sand, water, stone) = grid.get_stats(final_grid)
  let final_count = sand + water + stone

  let _ = io.println("[TEST 12] After 4 phases: Sand=" <> int.to_string(sand) <> " Water=" <> int.to_string(water))

  // Should still be 2 total particles (1 sand + 1 water)
  final_count
  |> should.equal(2)
}

// Test 13: CRITICAL - Sand actually falls after complete Margolus iteration
pub fn test_sand_falls_after_complete_iteration() {
  let g = grid.filled_with_air(10, 10)
  // Place sand at top middle
  let g2 = grid.set(g, 5, 0, grid.sand())
  let _ = io.println("[TEST 13] Initial: Sand at (5, 0)")

  let sim = simulation.new(g2)
  // Run 4 phases = 1 complete Margolus iteration
  let sim2 = simulation.steps(sim, 4)

  let final_grid = simulation.grid(sim2)
  let sand_at_top = grid.get(final_grid, 5, 0)
  let sand_below = grid.get(final_grid, 5, 1)

  let _ = io.println("[TEST 13] After 4 phases (1 iteration):")
  let _ = io.println("  (5,0): " <> case grid.cell_type(sand_at_top) {
    grid.Air -> "Air ✓"
    grid.Sand -> "Sand ✗"
    _ -> "?"
  })
  let _ = io.println("  (5,1): " <> case grid.cell_type(sand_below) {
    grid.Sand -> "Sand ✓"
    grid.Air -> "Air ✗"
    _ -> "?"
  })

  // Verify sand moved down
  let sand_moved = case grid.cell_type(sand_at_top), grid.cell_type(sand_below) {
    grid.Air, grid.Sand -> True
    _, _ -> False
  }

  case sand_moved {
    True -> Nil
    False -> should.fail()
  }
}
