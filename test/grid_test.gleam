import gleam/int
import gleam/io
import gleam/list
import gleeunit
import gleeunit/should

import grid

pub fn main() {
  gleeunit.main()
}

// Test 1: Empty grid has 0 active cells
pub fn test_empty_grid_has_zero_cells() {
  let g = grid.filled_with_air(160, 100)
  let cells = grid.to_list(g)

  io.println("TEST 1: Empty grid cell count = " <> int.to_string(list.length(cells)))

  cells
  |> list.length()
  |> should.equal(0)
}

// Test 2: Adding sand increases cell count by 1
pub fn test_adding_one_sand_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let cells = grid.to_list(g2)

  io.println("TEST 2: After adding 1 sand cell, count = " <> int.to_string(list.length(cells)))

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

  io.println("TEST 3: After adding 3 cells, count = " <> int.to_string(list.length(cells)))

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

  io.println("TEST 4: After overwriting 1 cell, count = " <> int.to_string(list.length(cells)))

  cells
  |> list.length()
  |> should.equal(1)
}

// Test 5: Setting air removes cell (if sparse grid works correctly)
pub fn test_setting_air_removes_cell() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 10, 10, grid.sand())
  let g3 = grid.set(g2, 10, 10, grid.air())  // Set to air (erase)
  let cells = grid.to_list(g3)

  io.println("TEST 5: After setting cell to air, count = " <> int.to_string(list.length(cells)))

  cells
  |> list.length()
  |> should.equal(1)  // ISSUE: Should be 0 if we're truly sparse!
}

// Test 6: Get returns correct cell type
pub fn test_get_returns_correct_type() {
  let g = grid.filled_with_air(160, 100)
  let g2 = grid.set(g, 5, 5, grid.sand())

  let cell = grid.get(g2, 5, 5)
  let cell_type = grid.cell_type(cell)

  io.println("TEST 6: Got cell type at (5,5)")

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

  io.println("TEST 7: Got cell from empty position, type = ...")

  case cell_type {
    grid.Air -> Nil
    _ -> should.fail()
  }
}
