/// Renderer for the falling sands simulation
/// Converts grid state to visual representation using Paint
import gleam/int
import gleam/list
import grid.{type Grid}
import paint

/// Render entire grid as a Paint Picture
pub fn render_grid(grid: Grid, scale: Int) -> paint.Picture {
  let cells = grid.to_list(grid)
  let scale_float = int.to_float(scale)

  let cell_pictures =
    list.map(cells, fn(entry) {
      let #(#(x, y), cell) = entry
      let x_float = int.to_float(x) *. scale_float
      let y_float = int.to_float(y) *. scale_float

      let color = case grid.cell_type(cell) {
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

      paint.rectangle(scale_float, scale_float)
      |> paint.fill(color)
      |> paint.translate_x(x_float)
      |> paint.translate_y(y_float)
    })

  paint.combine(cell_pictures)
}
