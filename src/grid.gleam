/// Core grid and cell data structures for the falling sands simulation
import gleam/dict.{type Dict}

/// Cell types in the simulation
pub type CellType {
  Air
  Sand
  Water
  Stone
  Lava
  Steam
  Oil
  Acid
  Ice
}

/// Individual cell with its type and optional data
pub opaque type Cell {
  Cell(type_: CellType, density: Int, temperature: Int)
}

/// Create an air cell
pub fn air() -> Cell {
  Cell(Air, 0, 20)
}

/// Create a sand cell
pub fn sand() -> Cell {
  Cell(Sand, 10, 20)
}

/// Create a water cell
pub fn water() -> Cell {
  Cell(Water, 5, 20)
}

/// Create a stone cell (immovable)
pub fn stone() -> Cell {
  Cell(Stone, 20, 20)
}

/// Create a lava cell (hot liquid)
pub fn lava() -> Cell {
  Cell(Lava, 15, 800)
}

/// Create a steam cell (rising gas)
pub fn steam() -> Cell {
  Cell(Steam, 1, 100)
}

/// Create an oil cell (floats on water)
pub fn oil() -> Cell {
  Cell(Oil, 3, 20)
}

/// Create an acid cell (corrosive liquid)
pub fn acid() -> Cell {
  Cell(Acid, 6, 20)
}

/// Create an ice cell (frozen water)
pub fn ice() -> Cell {
  Cell(Ice, 8, -20)
}

/// Get the type of a cell
pub fn cell_type(cell: Cell) -> CellType {
  cell.type_
}

/// Get the density of a cell (affects flow and settling)
pub fn density(cell: Cell) -> Int {
  cell.density
}

/// Get the temperature of a cell
pub fn temperature(cell: Cell) -> Int {
  cell.temperature
}

/// Grid representation using sparse Dict
/// Key is (x, y), value is Cell
pub opaque type Grid {
  Grid(width: Int, height: Int, cells: Dict(#(Int, Int), Cell))
}

/// Create an empty grid
pub fn new(width: Int, height: Int) -> Grid {
  Grid(width, height, dict.new())
}

/// Create a grid filled with air
pub fn filled_with_air(width: Int, height: Int) -> Grid {
  // Start with empty grid - air cells are the default when not in dict
  Grid(width, height, dict.new())
}

/// Get grid width
pub fn width(grid: Grid) -> Int {
  grid.width
}

/// Get grid height
pub fn height(grid: Grid) -> Int {
  grid.height
}

/// Get a cell at coordinates, returns Air if out of bounds
pub fn get(grid: Grid, x: Int, y: Int) -> Cell {
  case dict.get(grid.cells, #(x, y)) {
    Ok(cell) -> cell
    Error(Nil) -> air()
  }
}

/// Set a cell at coordinates
/// NOTE: Air cells are NOT stored (sparse grid) - they're removed from dict
pub fn set(grid: Grid, x: Int, y: Int, cell: Cell) -> Grid {
  case is_in_bounds(grid, x, y) {
    True -> {
      // Only store non-air cells in sparse grid
      // This keeps memory usage O(active_cells) not O(width*height)
      let new_cells = case cell_type(cell) {
        Air -> dict.delete(grid.cells, #(x, y))  // Remove air cells
        _ -> dict.insert(grid.cells, #(x, y), cell)  // Store other types
      }
      Grid(grid.width, grid.height, new_cells)
    }
    False -> grid
  }
}

/// Check if coordinates are within grid bounds
pub fn is_in_bounds(grid: Grid, x: Int, y: Int) -> Bool {
  x >= 0 && x < grid.width && y >= 0 && y < grid.height
}

/// Swap two cells in the grid
pub fn swap(grid: Grid, x1: Int, y1: Int, x2: Int, y2: Int) -> Grid {
  let cell1 = get(grid, x1, y1)
  let cell2 = get(grid, x2, y2)
  grid
  |> set(x1, y1, cell2)
  |> set(x2, y2, cell1)
}

/// Get all cells as a list of (#(x, y), cell) tuples
pub fn to_list(grid: Grid) -> List(#(#(Int, Int), Cell)) {
  dict.to_list(grid.cells)
}

/// Get internal dict for advanced operations
@internal
pub fn get_cells(grid: Grid) -> Dict(#(Int, Int), Cell) {
  grid.cells
}

/// Create grid from dict (for internal use in simulation)
@internal
pub fn from_dict(width: Int, height: Int, cells: Dict(#(Int, Int), Cell)) -> Grid {
  Grid(width, height, cells)
}

/// Count active cells (debugging)
pub fn active_cell_count(grid: Grid) -> Int {
  dict.size(grid.cells)
}

/// Get stats about the grid (debugging)
pub fn get_stats(grid: Grid) -> #(Int, Int, Int) {
  let cells = grid.cells
  let _total_stored = dict.size(cells)

  // Count by type (legacy - counts Sand, Water, Stone)
  let counts =
    dict.fold(cells, #(0, 0, 0), fn(acc, _key, cell) {
      let #(sand_count, water_count, stone_count) = acc
      case cell_type(cell) {
        Sand -> #(sand_count + 1, water_count, stone_count)
        Water -> #(sand_count, water_count + 1, stone_count)
        Stone -> #(sand_count, water_count, stone_count + 1)
        Air | Lava | Steam | Oil | Acid | Ice -> acc
      }
    })

  counts
}
