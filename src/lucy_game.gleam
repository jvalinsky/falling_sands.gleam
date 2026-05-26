/// Falling Sands Game - Main application
/// Built with Paint for JavaScript target
import gleam/float
import gleam/int
import gleam/list
import paint
import paint/canvas
import paint/event

import grid.{type CellType, type Grid}
import renderer
import sim_bridge

// ============================================================================
// MODEL
// ============================================================================

pub type Model {
  Model(
    grid: Grid,
    is_running: Bool,
    paused: Bool,
    brush_type: CellType,
    brush_size: Int,
    speed: Int,
    steps_per_frame: Int,
    pixel_scale: Int,
    mouse_down: Bool,
    fps: Float,
    worker_timing: String,
  )
}

fn init(_config: canvas.Config) -> Model {
  let initial_grid = sim_bridge.init_grid(160, 100)
  Model(
    grid: initial_grid,
    is_running: False,
    paused: False,
    brush_type: grid.Sand,
    brush_size: 3,
    speed: 1,
    steps_per_frame: 4,
    pixel_scale: 6,
    mouse_down: False,
    fps: 0.0,
    worker_timing: "",
  )
}

// ============================================================================
// UPDATE
// ============================================================================

fn update(model: Model, evt: event.Event) -> Model {
  case evt {
    event.Tick(delta) -> {
      let new_fps = case delta >. 0.0 {
        True -> 0.9 *. model.fps +. 0.1 /. delta
        False -> model.fps
      }
      let timing = sim_bridge.get_worker_timing()
      case model.is_running && !model.paused {
        True -> {
          let new_grid = sim_bridge.tick_simulation(model.steps_per_frame)
          Model(..model, fps: new_fps, grid: new_grid, worker_timing: timing)
        }
        False -> Model(..model, fps: new_fps, worker_timing: timing)
      }
    }

    event.MousePressed(_button) -> {
      Model(..model, mouse_down: True)
    }

    event.MouseMoved(x, y) -> {
      case model.mouse_down {
        True -> {
          let pixel_x = float.round(x /. int.to_float(model.pixel_scale))
          let pixel_y = float.round(y /. int.to_float(model.pixel_scale))
          let type_idx = cell_type_index(model.brush_type)
          let new_grid =
            draw_brush_via_bridge(
              model.grid,
              pixel_x,
              pixel_y,
              model.brush_size,
              type_idx,
            )
          Model(..model, grid: new_grid)
        }
        False -> model
      }
    }

    event.MouseReleased(_button) -> {
      Model(..model, mouse_down: False)
    }

    event.KeyboardPressed(key) -> {
      case key {
        event.KeySpace -> {
          Model(..model, is_running: True, paused: False)
        }
        event.KeyEscape -> {
          case model.is_running {
            True -> {
              Model(..model, paused: !model.paused)
            }
            False -> {
              Model(..model, is_running: True, paused: False)
            }
          }
        }
        event.KeyEnter | event.KeyBackspace -> {
          let fresh_grid = sim_bridge.reset_grid(160, 100)
          Model(..model, grid: fresh_grid, is_running: False, paused: False)
        }
        event.KeyW -> {
          Model(..model, brush_type: grid.Water)
        }
        event.KeyS -> {
          Model(..model, brush_type: grid.Sand)
        }
        event.KeyX -> {
          Model(..model, brush_type: grid.Stone)
        }
        event.KeyZ -> {
          Model(..model, brush_type: grid.Air)
        }
        event.KeyA -> {
          Model(..model, brush_type: grid.Acid)
        }
        event.KeyC -> {
          Model(..model, brush_type: grid.Ice)
        }
        event.KeyD -> {
          Model(..model, brush_type: grid.Oil)
        }
        event.KeyUpArrow -> {
          Model(..model, brush_type: grid.Steam)
        }
        event.KeyDownArrow -> {
          Model(..model, brush_type: grid.Lava)
        }
        event.KeyLeftArrow -> {
          let new_speed = case model.speed > 1 {
            True -> model.speed - 1
            False -> 1
          }
          let new_steps = new_speed * 4
          let _ = sim_bridge.set_worker_config(new_steps)
          Model(..model, speed: new_speed, steps_per_frame: new_steps)
        }
        event.KeyRightArrow -> {
          let new_speed = case model.speed < 10 {
            True -> model.speed + 1
            False -> 10
          }
          let new_steps = new_speed * 4
          let _ = sim_bridge.set_worker_config(new_steps)
          Model(..model, speed: new_speed, steps_per_frame: new_steps)
        }
      }
    }

    event.KeyboardRelased(_) -> model
  }
}

// ============================================================================
// VIEW
// ============================================================================

fn view(model: Model) -> paint.Picture {
  let game_picture = renderer.render_grid(model.grid, model.pixel_scale)

  let status_text = case model.is_running, model.paused {
    False, _ -> "Stopped"
    True, True -> "Paused"
    True, False -> "Running"
  }

  let info_text =
    "FPS: "
    <> int.to_string(float.round(model.fps))
    <> " | Iter: "
    <> int.to_string(sim_bridge.get_step_count())
    <> " | "
    <> status_text
    <> " | Speed: "
    <> int.to_string(model.speed)
    <> "x | Brush: "
    <> case model.brush_type {
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
    <> " | Space=Start Esc=Pause Enter=Reset ←/→=Speed W/S/X/Z/A/C/D/↑/↓=Brushes"

  let hud_y = int.to_float(100 * model.pixel_scale + 20)

  let pictures = case model.worker_timing {
    "" ->
      [
        game_picture,
        paint.text(info_text, 12)
          |> paint.translate_x(10.0)
          |> paint.translate_y(hud_y),
      ]
    _ ->
      [
        game_picture,
        paint.text(info_text, 12)
          |> paint.translate_x(10.0)
          |> paint.translate_y(hud_y),
        paint.text(model.worker_timing, 11)
          |> paint.translate_x(10.0)
          |> paint.translate_y(hud_y +. 14.0),
      ]
  }

  paint.combine(pictures)
}

// ============================================================================
// MAIN
// ============================================================================

pub fn main() {
  canvas.interact(init, update, view, "#game-canvas")
  Nil
}

// ============================================================================
// HELPERS
// ============================================================================

/// Convert CellType to index for bridge communication
fn cell_type_index(ct: CellType) -> Int {
  case ct {
    grid.Air -> 0
    grid.Sand -> 1
    grid.Water -> 2
    grid.Stone -> 3
    grid.Lava -> 4
    grid.Steam -> 5
    grid.Oil -> 6
    grid.Acid -> 7
    grid.Ice -> 8
  }
}

/// Draw a brush using the bridge (updates both local grid and worker)
fn draw_brush_via_bridge(
  grid: Grid,
  cx: Int,
  cy: Int,
  radius: Int,
  type_idx: Int,
) -> Grid {
  let ys = list.range(-radius, radius + 1)
  let xs = list.range(-radius, radius + 1)
  list.fold(ys, grid, fn(acc_grid, dy) {
    list.fold(xs, acc_grid, fn(_acc, dx) {
      sim_bridge.draw_cell(cx + dx, cy + dy, type_idx)
    })
  })
}
