/// Renderer for the falling sands simulation
/// Converts grid state to visual representation using Paint
import gleam/int
import gleam/io
import gleam/list
import grid.{type Grid}
import paint

/// Get color for a cell type as RGB tuple
fn cell_color(cell_type: grid.CellType) -> paint.Colour {
  case cell_type {
    grid.Air -> paint.colour_rgb(240, 240, 240)
    grid.Sand -> paint.colour_rgb(218, 165, 32)
    grid.Water -> paint.colour_rgb(64, 164, 223)
    grid.Stone -> paint.colour_rgb(128, 128, 128)
    grid.Lava -> paint.colour_rgb(255, 100, 0)
    grid.Steam -> paint.colour_rgb(200, 220, 230)
    grid.Oil -> paint.colour_rgb(101, 67, 33)
    grid.Acid -> paint.colour_rgb(100, 255, 100)
    grid.Ice -> paint.colour_rgb(180, 220, 255)
  }
}

/// Render entire grid as a Paint Picture
pub fn render_grid(grid: Grid, scale: Int) -> paint.Picture {
  let cells = grid.to_list(grid)
  let scale_float = int.to_float(scale)
  let cell_count = list.length(cells)
  let active_count = grid.active_cell_count(grid)
  let #(sand, water, stone) = grid.get_stats(grid)

  let _ = case cell_count > 0 && cell_count % 50 == 0 {
    True -> io.println("🎨 Rendering " <> int.to_string(cell_count) <> " cells | Active: " <> int.to_string(active_count) <> " (Sand: " <> int.to_string(sand) <> " Water: " <> int.to_string(water) <> " Stone: " <> int.to_string(stone) <> ")")
    False -> Nil
  }

  let cell_pictures =
    list.map(cells, fn(entry) {
      let #(#(x, y), cell) = entry
      let x_float = int.to_float(x) *. scale_float
      let y_float = int.to_float(y) *. scale_float

      paint.rectangle(scale_float, scale_float)
      |> paint.fill(cell_color(grid.cell_type(cell)))
      |> paint.translate_x(x_float)
      |> paint.translate_y(y_float)
    })

  paint.combine(cell_pictures)
}

/// Draw a brush stroke (place multiple cells)
pub fn draw_brush(
  grid: Grid,
  center_x: Int,
  center_y: Int,
  radius: Int,
  cell_type: grid.CellType,
) -> Grid {
  let cell = case cell_type {
    grid.Sand -> grid.sand()
    grid.Water -> grid.water()
    grid.Stone -> grid.stone()
    grid.Air -> grid.air()
    grid.Lava -> grid.lava()
    grid.Steam -> grid.steam()
    grid.Oil -> grid.oil()
    grid.Acid -> grid.acid()
    grid.Ice -> grid.ice()
  }

  let type_name = case cell_type {
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

  let _ = io.println("🖌️ Drawing brush (" <> type_name <> ") at (" <> int.to_string(center_x) <> ", " <> int.to_string(center_y) <> ") radius=" <> int.to_string(radius))

  // Create a list of all positions in the brush area using nested list operations
  let ys = list.range(-radius, radius + 1)
  let xs = list.range(-radius, radius + 1)

  // Generate all positions
  let positions =
    list.flat_map(ys, fn(dy) {
      list.map(xs, fn(dx) { #(center_x + dx, center_y + dy) })
    })

  // Paint all positions in the grid
  list.fold(positions, grid, fn(acc_grid, pos) {
    let #(x, y) = pos
    grid.set(acc_grid, x, y, cell)
  })
}
