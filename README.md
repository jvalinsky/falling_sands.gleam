# Falling Sands Simulation Game - Built with Gleam

A browser-based falling sands cellular automaton simulator written in **Gleam**, compiled to **JavaScript**, demonstrating:

- **Margolus Neighbourhoods** for parallelizable cellular automata
- **Functional Programming** in Gleam for game logic
- **Paint Library** for interactive canvas rendering
- **Sparse Grid Data Structure** for memory efficiency
- **Interactive Simulation** with mouse drawing and physics

## Quick Start

```bash
# 1. Build Gleam → JavaScript (requires Gleam ≥1.11.0)
gleam build --target javascript

# 2. Copy artifacts to web directory
node build.mjs

# 3. Serve and open (ES modules require an HTTP server)
python3 -m http.server
# Then open http://localhost:8000
```

## Controls

| Key | Action |
|-----|--------|
| **Space** | Start simulation |
| **Enter / Backspace** | Reset (clear grid) |
| **S** | Sand brush |
| **W** | Water brush |
| **X** | Stone brush |
| **Z** | Eraser (Air) |
| **A** | Acid brush |
| **C** | Ice brush |
| **D** | Oil brush |
| **Mouse drag** | Draw with current brush |

## Architecture Overview

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Language** | Gleam | Type-safe functional language |
| **UI Library** | Paint 1.0+ | Canvas rendering & interaction |
| **Rendering** | HTML Canvas 2D | Direct pixel drawing |
| **Build Target** | JavaScript | Browser execution |
| **Build Tool** | build.mjs | Artifact bundling |

### Core Modules

```
src/
├── lucy_game.gleam       # Main app: Paint interactive loop (264 lines)
├── simulation.gleam      # Physics & Margolus algorithm (295 lines)
├── grid.gleam            # Grid & cell data structures (188 lines)
└── renderer.gleam        # Rendering with Paint library (101 lines)
```

~848 lines of Gleam total.

## Key Features

### 1. Margolus Neighbourhood Algorithm

Uses phase-based 2×2 block processing for true parallelizability:

```
Each iteration: 4 phases
Phase 0: Blocks at (0,0), (2,0), (4,0), ... [parallel]
Phase 1: Blocks at (1,0), (3,0), (5,0), ... [parallel]
Phase 2: Blocks at (0,1), (2,1), (4,1), ... [parallel]
Phase 3: Blocks at (1,1), (3,1), (5,1), ... [parallel]
```

**Benefit**: Each block is independent per phase → full parallelization possible.

### 2. Sparse Grid

Memory-efficient representation using `Dict(#(Int, Int), Cell)`:
- Air cells are implicit (not stored in the dict)
- O(active_cells) memory instead of O(width × height)
- Perfect for sparse simulations

### 3. Particle Types (9 types)

| Particle | Density | Temp | Behaviour |
|----------|---------|------|-----------|
| **Air** | 0 | 20 | Empty space (default, not stored) |
| **Sand** | 10 | 20 | Falls under gravity, piles up, diagonal sliding |
| **Water** | 5 | 20 | Falls, spreads horizontally on surfaces |
| **Stone** | 20 | 20 | Immovable solid |
| **Lava** | 15 | 800 | Falls like heavy water; melts sand→lava, vaporizes water→steam+stone, burns oil→steam |
| **Steam** | 1 | 100 | Rises (anti-gravity); condenses on stone→water |
| **Oil** | 3 | 20 | Floats on water (density separation), spreads horizontally |
| **Acid** | 6 | 20 | Dissolves sand and stone→air; neutralized by water |
| **Ice** | 8 | -20 | Solid; melted by lava→water+stone, by steam→water+water; freezes adjacent water→ice |

### 4. Physics Rules (Margolus 2×2 blocks)

All rules swap cells within a 2×2 block — particles are never created or destroyed within a block:

1. **Vertical falling** — gravity pulls sand/water/lava/oil/acid downward
2. **Diagonal sliding** — particles slide diagonally when blocked below
3. **Horizontal spreading** — water/oil spread sideways on solid surfaces
4. **Reactions** — lava+water→steam+stone, acid+sand→air, oil+lava→steam, ice+lava→water+stone, water+ice→ice+ice, etc.

### 5. Paint Interactive Canvas

Uses `paint/canvas.interact(init, update, view, "#game-canvas")` for the game loop:
- **init**: Creates 160×100 grid with pixel scale 6 (960×600 canvas)
- **update**: Handles Tick (simulation steps), Mouse (drawing), Keyboard (brush/controls)
- **view**: Renders grid cells as scaled rectangles + status text overlay

## Project Structure

```
lucy_game/
├── src/                    # Gleam source files
│   ├── lucy_game.gleam     # Main app entry point (Paint interactive)
│   ├── simulation.gleam    # Margolus physics engine
│   ├── grid.gleam          # Sparse grid + cell types
│   └── renderer.gleam      # Paint rendering + brush drawing
├── index.html              # Web page with canvas element
├── build.mjs               # Copies build artifacts to priv/javascript/
├── gleam.toml              # Gleam project config (target: javascript)
├── priv/javascript/        # Compiled JavaScript (generated)
└── build/                  # Gleam build artifacts (generated)
```

## Building & Running

### Prerequisites
- Gleam ≥1.11.0
- Node.js 14+
- Modern web browser

### Build Steps

```bash
# 1. Compile Gleam to JavaScript
gleam build --target javascript

# 2. Bundle artifacts into priv/javascript
node build.mjs

# 3. Open in browser (needs HTTP server for ES modules)
python3 -m http.server            # → http://localhost:8000
# or
npx http-server                   # → http://localhost:8080
```

### Development Workflow

```bash
# Terminal 1: Rebuild on changes
gleam build --target javascript && node build.mjs

# Terminal 2: Serve the app
python3 -m http.server
```

Then open http://localhost:8000 and refresh after rebuilding.

## Cellular Automata & the Margolus Neighbourhood

### The Problem with Naïve Falling Sand

A naïve falling sand simulator scans cells top-to-bottom, left-to-right, and moves each particle individually. This has two fundamental problems:

1. **Order dependence** — a particle moved early in the scan can be moved _again_ later in the same frame, causing it to "teleport" multiple cells per tick.
2. **Not parallelizable** — every cell read/write can conflict with its neighbours, so the entire grid must be processed sequentially.

### Block Cellular Automata

A [block cellular automaton](https://en.wikipedia.org/wiki/Block_cellular_automaton) (also called a _partitioning cellular automaton_) solves both problems by dividing the grid into non-overlapping blocks and applying a transition rule to each block as a unit. Because the blocks don't overlap within a single phase, they can all be processed independently — in parallel, with no locks or synchronisation.

Block cellular automata were first described by Tommaso Toffoli and Norman Margolus in _Cellular Automata Machines_ (MIT Press, 1987). They are particularly well-suited to physical simulations because it is straightforward to design transition rules that obey conservation laws (e.g. conservation of particle count).

### The Margolus Neighbourhood

The **Margolus neighbourhood** is the simplest and most common block partition scheme. Named after [Norman Margolus](https://en.wikipedia.org/wiki/Norman_Margolus), it divides a 2D grid into 2×2 blocks, then shifts the partition by one cell on alternate timesteps.

In this project, each full iteration cycles through **4 phases** with different block offsets:

```
Phase 0 (offset 0,0)       Phase 1 (offset 0,1)
┌──┬──┬──┬──┐              ┌──┬──┬──┬──┐
│  │  │  │  │              │  │  │  │  │
├──┼──┼──┼──┤              │──┼──┼──┼──│
│  │  │  │  │              │  │  │  │  │
├──┼──┼──┼──┤              ├──┼──┼──┼──┤
│  │  │  │  │              │  │  │  │  │
└──┴──┴──┴──┘              └──┴──┴──┴──┘

Phase 2 (offset 1,0)       Phase 3 (offset 1,1)
┌──┬──┬──┬──┐              ┌──┬──┬──┬──┐
│  │  │  │  │              │  │  │  │  │
│──┼──┼──┼──│              │  ├──┼──┤  │
│  │  │  │  │              │  │  │  │  │
│──┼──┼──┼──│              │  ├──┼──┤  │
│  │  │  │  │              │  │  │  │  │
└──┴──┴──┴──┘              └──┴──┴──┴──┘
```

After all 4 phases complete, every cell has participated in block processing from multiple alignments, allowing information (i.e. particle movement) to propagate across block boundaries.

### Why This Matters for Falling Sand

The Margolus neighbourhood gives us several important properties:

| Property | Benefit |
|----------|---------|
| **Parallelizable** | All blocks within a phase are independent — no read/write conflicts. Could be trivially distributed across Web Workers or GPU compute shaders. |
| **Conservation** | Each 2×2 block is a closed system. The transition rule _swaps_ cells within the block, so particles are never created or destroyed. Total particle count is conserved by construction. |
| **Deterministic** | Same input always produces same output. No scan-order artifacts, no teleportation bugs. |
| **Simple** | The entire physics engine is a single pattern-match function on the 4 cells of a 2×2 block (`apply_block_physics` in `simulation.gleam`). |

### How It's Implemented Here

```gleam
// simulation.gleam — process one Margolus phase
fn process_phase(grid: Grid, phase: Int) -> Grid {
  // Phase determines block offset
  let offset_x = case phase { 0 | 1 -> 0   2 | 3 -> 1  _ -> 0 }
  let offset_y = case phase { 0 | 2 -> 0   1 | 3 -> 1  _ -> 0 }

  // Generate all block positions for this phase, process independently
  list.fold(ys, grid, fn(grid_y, y) {
    list.fold(xs, grid_y, fn(grid_xy, x) {
      process_block(grid_xy, x, y)   // Apply physics to one 2×2 block
    })
  })
}
```

Each `process_block` call reads the 4 cells of a 2×2 block, pattern-matches against ~60 physics rules, and writes back the result. The rules always return exactly 4 cells — a permutation or transformation of the input, never a net gain or loss of matter.

### Trade-offs

- **4 phases per visible tick** — particles can only move 1 cell per phase, and you need all 4 phases for full-grid coverage. This project runs 4 steps per frame (= 1 complete Margolus iteration).
- **Block-local reasoning** — physics rules can only see a 2×2 window. Long-range effects (pressure, temperature propagation) require multiple iterations to spread across the grid.
- **Sequential in practice** — while the algorithm _is_ parallelizable, this implementation processes blocks sequentially via `list.fold` since JavaScript is single-threaded. Moving to Web Workers or WebGPU would unlock the parallelism.

### Further Reading

- Toffoli, T. & Margolus, N. (1987). _Cellular Automata Machines: A New Environment for Modeling_. MIT Press. §II.12 "The Margolus neighborhood".
- Margolus, N. (1984). "Physics-like models of computation". _Physica D_, 10(1–2), 81–95.
- Chopard, B. & Droz, M. (1998). "The sand pile rule". _Cellular Automata Modeling of Physical Systems_. Cambridge University Press. §2.2.6.
- [Block cellular automaton — Wikipedia](https://en.wikipedia.org/wiki/Block_cellular_automaton)

## Design Decisions

### Why Paint?

- Functional graphics library with no side effects
- Elm-inspired architecture: `init → update → view`
- Clean interaction model via `canvas.interact()`
- Type-safe event handling for mouse, keyboard, and tick events

### Why Sparse Grid?

- Only active (non-air) cells are stored in `Dict`
- Setting a cell to Air deletes it from the dict
- O(active_cells) memory vs O(width × height) for dense arrays

## Performance Characteristics

### Memory
- Sparse grid: only non-air cells stored
- Functional updates via dict operations

### CPU
- Margolus phases: O(width × height / 4) per phase
- 4 steps per frame (1 complete Margolus iteration)
- Rendering: O(active_cells) per frame

### Grid Size
- Default: 160×100 (16,000 cells) at pixel scale 6 → 960×600 canvas

## Testing

```bash
gleam test
```

## References

- [Gleam Language](https://gleam.run/)
- [Paint Library](https://hexdocs.pm/paint/)
- [Margolus Neighbourhoods (Wikipedia)](https://en.wikipedia.org/wiki/Block_cellular_automaton)
- [Cellular Automata](https://en.wikipedia.org/wiki/Cellular_automaton)
- [Falling Sand Simulator (HN Discussion)](https://news.ycombinator.com/item?id=11152881)

## License

MIT
