/// Falling Sands Game - Main application
/// Built with Paint for JavaScript target
import gleam/float
import gleam/int
import gleam/io
import paint
import paint/canvas
import paint/event

import grid.{type CellType, type Grid}
import renderer
import simulation.{type SimState}

// ============================================================================
// MODEL
// ============================================================================

pub type Model {
  Model(
    sim_state: SimState,
    grid: Grid,
    is_running: Bool,
    paused: Bool,
    brush_type: CellType,
    brush_size: Int,
    speed: Int,
    steps_per_frame: Int,
    pixel_scale: Int,
    mouse_down: Bool,
  )
}

fn init(_config: canvas.Config) -> Model {
  let _ = io.println("🎮 Lucy Game - Initializing model...")
  let initial_grid = grid.filled_with_air(160, 100)
  let model = Model(
    sim_state: simulation.new(initial_grid),
    grid: initial_grid,
    is_running: False,
    paused: False,
    brush_type: grid.Sand,
    brush_size: 3,
    speed: 1,
    steps_per_frame: 4,
    pixel_scale: 6,
    mouse_down: False,
  )
  let _ = io.println("✓ Model initialized - Grid: 160x100, pixel scale: 6")
  let _ = io.println("📊 Simulation: 4 phases per frame (1 complete Margolus iteration)")
  model
}

// ============================================================================
// UPDATE
// ============================================================================

fn update(model: Model, evt: event.Event) -> Model {
  case evt {
    event.Tick(_delta) -> {
      case model.is_running && !model.paused {
        True -> {
          let updated_state =
            simulation.steps(model.sim_state, model.steps_per_frame)
          let new_grid = simulation.grid(updated_state)
          let step = simulation.step_count(updated_state)
          let phase = simulation.phase(updated_state)
          case step % 10 == 0 {
            True -> {
              let _ =
                io.println(
                  "📊 Step: "
                  <> int.to_string(step)
                  <> ", Phase: "
                  <> int.to_string(phase),
                )
              Nil
            }
            False -> Nil
          }
          Model(..model, sim_state: updated_state, grid: new_grid)
        }
        False -> model
      }
    }

    event.MousePressed(_button) -> {
      let _ = io.println("🖱️ Mouse pressed")
      Model(..model, mouse_down: True)
    }

    event.MouseMoved(x, y) -> {
      case model.mouse_down {
        True -> {
          let pixel_x = float.round(x /. int.to_float(model.pixel_scale))
          let pixel_y = float.round(y /. int.to_float(model.pixel_scale))
          let brush_name = case model.brush_type {
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
          let _ =
            io.println(
              "✏️ Drawing "
              <> brush_name
              <> " at pixel ("
              <> int.to_string(pixel_x)
              <> ", "
              <> int.to_string(pixel_y)
              <> ")",
            )
          let new_grid =
            renderer.draw_brush(
              model.grid,
              pixel_x,
              pixel_y,
              model.brush_size,
              model.brush_type,
            )
          let new_cell = case model.brush_type {
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
          let new_sim =
            simulation.set_cell(model.sim_state, pixel_x, pixel_y, new_cell)
          Model(..model, grid: new_grid, sim_state: new_sim)
        }
        False -> model
      }
    }

    event.MouseReleased(_button) -> {
      let _ = io.println("🖱️ Mouse released")
      Model(..model, mouse_down: False)
    }

    event.KeyboardPressed(key) -> {
      case key {
        event.KeySpace -> {
          let _ = io.println("⏯️ Space pressed - Starting simulation")
          Model(..model, is_running: True, paused: False)
        }
        event.KeyEnter | event.KeyBackspace -> {
          let _ = io.println("🔄 Reset pressed - Clearing grid")
          let fresh_grid = grid.filled_with_air(160, 100)
          Model(
            ..model,
            sim_state: simulation.new(fresh_grid),
            grid: fresh_grid,
            is_running: False,
            paused: False,
          )
        }
        event.KeyW -> {
          let _ = io.println("💧 Water brush selected")
          Model(..model, brush_type: grid.Water)
        }
        event.KeyS -> {
          let _ = io.println("🟫 Sand brush selected")
          Model(..model, brush_type: grid.Sand)
        }
        event.KeyX -> {
          let _ = io.println("🪨 Stone brush selected")
          Model(..model, brush_type: grid.Stone)
        }
        event.KeyZ -> {
          let _ = io.println("🗑️ Eraser selected")
          Model(..model, brush_type: grid.Air)
        }
        event.KeyA -> {
          let _ = io.println("🧪 Acid brush selected")
          Model(..model, brush_type: grid.Acid)
        }
        event.KeyC -> {
          let _ = io.println("❄️ Ice brush selected")
          Model(..model, brush_type: grid.Ice)
        }
        event.KeyD -> {
          let _ = io.println("🛢️ Oil brush selected")
          Model(..model, brush_type: grid.Oil)
        }
        _ -> {
          let _ = io.println("⌨️ Unknown key pressed")
          model
        }
      }
    }

    _ -> {
      let _ = io.println("❓ Unknown event")
      model
    }
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
    "Iteration: "
    <> int.to_string(simulation.step_count(model.sim_state))
    <> " | "
    <> status_text
    <> " | Brush: "
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
    <> " | Keys: Space=Start, Enter=Reset, W=Water, S=Sand, X=Stone, Z=Eraser, A=Acid, C=Ice, D=Oil"

  let _ = case simulation.step_count(model.sim_state) % 100 == 0 {
    True -> io.println("🎨 Rendered frame, step: " <> int.to_string(simulation.step_count(model.sim_state)))
    False -> Nil
  }

  paint.combine([
    game_picture,
    paint.text(info_text, 12)
      |> paint.translate_x(10.0)
      |> paint.translate_y(int.to_float(100 * model.pixel_scale + 20)),
  ])
}

// ============================================================================
// MAIN
// ============================================================================

pub fn main() {
  let _ = io.println("🚀 Lucy Game - Starting application...")
  let _ = io.println("📍 Looking for canvas element: #game-canvas")
  let _ = io.println("🎨 Initializing Paint canvas framework...")
  canvas.interact(init, update, view, "#game-canvas")
  let _ = io.println("✓ Canvas interactive mode started!")
  Nil
}
