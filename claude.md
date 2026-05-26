# Lucy Game - Architecture & Implementation Guide

## Overview

Lucy Game is a falling sands cellular automaton simulator written in Gleam. It demonstrates advanced concepts like parallelizable physics (Margolus Neighbourhoods), sparse grid data structures, and functional game programming.

## Architecture

### Technology Stack

- **Language**: Gleam (type-safe, functional)
- **UI**: Paint 1.0+ (functional graphics library)
- **Target**: JavaScript (browser)
- **Build System**: Gleam + build.mjs bundler

### Project Layout

```
src/
├── lucy_game.gleam       # Main app: Paint.interact entry point (264 lines)
├── simulation.gleam      # Physics engine with Margolus algorithm (295 lines)
├── grid.gleam            # Sparse grid (Dict-based) data structure (188 lines)
└── renderer.gleam        # Paint rendering layer (101 lines)
```

### Module Responsibilities

#### lucy_game.gleam (Main App)
- Uses `paint/canvas.interact()` for game loop
- Initializes Model with simulation state
- Updates on events (Tick, Mouse, Keyboard)
- Renders grid using renderer
- Handles user input:
  - Mouse drag to draw particles
  - Keyboard shortcuts: S=Sand, W=Water, X=Stone, Z=Eraser, A=Acid, C=Ice, D=Oil
  - Space=Start, Enter/Backspace=Reset

#### simulation.gleam (Physics)
- **Margolus Neighbourhoods**: 4-phase parallelizable block processing
- **Cell Types**: Sand, Water, Stone, Air, Lava, Steam, Oil, Acid, Ice
- **Physics Rules** (applied to 2×2 blocks):
  1. Vertical falling (gravity)
  2. Diagonal sliding (when blocked below)
  3. Horizontal spreading (water/oil on surfaces)
  4. Reactions (lava+water→steam+stone, acid dissolves solids, ice freezing, etc.)
- **Key Functions**:
  - `step(state)`: Process one Margolus phase
  - `steps(state, count)`: Run multiple steps
  - `process_block(grid, x, y)`: Apply physics to 2×2 block
  - `set_cell(state, x, y, cell)`: Place a cell during simulation

#### grid.gleam (Data Structure)
- **Sparse Grid**: `Dict(#(Int, Int), Cell)` — only stores non-air cells
- **Cell Type**: Opaque type with metadata (type, density, temperature)
- **9 Cell Types**: Air(0,20), Sand(10,20), Water(5,20), Stone(20,20), Lava(15,800), Steam(1,100), Oil(3,20), Acid(6,20), Ice(8,-20)
- **Default**: Out-of-bounds or missing cells are Air
- **Memory**: O(active_cells) — air cells are deleted from dict, not stored

#### renderer.gleam (Rendering)
- Converts grid to Paint pictures via `render_grid(grid, scale)`
- Colors per cell type (9 distinct colors)
- Brush drawing via `draw_brush(grid, x, y, radius, cell_type)`
- Uses Paint's transformation system for positioning

## Build & Deployment

### Prerequisites
- Gleam ≥1.11.0
- Node.js 14+

### Build Pipeline

1. **Gleam Compilation**
   ```bash
   gleam build --target javascript
   ```
   - Compiles all .gleam files to JavaScript
   - Output: `build/dev/javascript/lucy_game/*.mjs`

2. **Artifact Bundling**
   ```bash
   node build.mjs
   ```
   - Copies build artifacts to `priv/javascript/`
   - Creates `priv/javascript/index.mjs` entry point

3. **Web Serving** (ES modules require HTTP server)
   ```bash
   python3 -m http.server
   open http://localhost:8000
   ```

### Key Implementation Details

#### Margolus Algorithm

The algorithm divides each iteration into 4 phases based on x/y offsets:

```
Phase 0: offset_x=0, offset_y=0 → blocks at (0,0), (2,0), (4,0), ...
Phase 1: offset_x=0, offset_y=1 → blocks at (0,1), (2,1), (4,1), ...
Phase 2: offset_x=1, offset_y=0 → blocks at (1,0), (3,0), (5,0), ...
Phase 3: offset_x=1, offset_y=1 → blocks at (1,1), (3,1), (5,1), ...
```

**Benefit**: Each phase's blocks are independent → fully parallelizable!

#### Physics Rules (Priority Order)

All rules are applied to 2×2 blocks. Cells are SWAPPED, never created/destroyed:

1. Vertical falling — sand/water fall straight down into air
2. Diagonal falling — particles slide diagonally when blocked below by same type or stone
3. Water horizontal spreading — water spreads sideways when sitting on solid
4. Lava interactions — melts sand, vaporizes water→steam+stone, burns oil→steam
5. Steam — rises upward, condenses on stone→water
6. Oil — floats on water (density sort), falls/spreads like water
7. Acid — dissolves sand/stone→air, neutralized by water→water
8. Ice — melted by lava/steam, freezes adjacent water→ice

#### Sparse Grid

```gleam
pub fn set(grid: Grid, x: Int, y: Int, cell: Cell) -> Grid {
  let new_cells = case cell_type(cell) {
    Air -> dict.delete(grid.cells, #(x, y))   // Remove air cells
    _ -> dict.insert(grid.cells, #(x, y), cell)
  }
  Grid(grid.width, grid.height, new_cells)
}
```

#### Grid Configuration

- Default size: 160×100 cells
- Pixel scale: 6 (canvas: 960×600)
- Steps per frame: 4 (1 complete Margolus iteration)

## Common Issues & Solutions

### Issue: Build fails with "Incompatible Gleam version"

**Cause**: gleam_stdlib requires Gleam ≥1.11.0

**Solution**: Upgrade Gleam to latest version

### Issue: Nothing draws to canvas

**Cause**: Old compiled code in priv directory

**Solution**:
```bash
rm -rf priv/javascript
gleam clean
gleam build --target javascript
node build.mjs
```

### Issue: Import errors in browser console

**Cause**: Paint library not in `priv/javascript/paint/`

**Solution**: Run `node build.mjs` to copy Paint from build directory

### Issue: Page loads but canvas is blank / no errors

**Cause**: Must serve via HTTP server (ES modules don't work with file:// protocol)

**Solution**: Use `python3 -m http.server` or `npx http-server`

## Performance Notes

### Memory Usage

- **Sparse Grid**: Only non-air cells stored; air cells deleted from dict
- **Functional Updates**: No in-place mutations, dict operations are O(log n)

### Simulation Speed

- **Grid**: 160×100 = 16,000 cells
- **Per Phase**: O(width × height / 4) cell operations
- **Per Frame**: 4 phases (1 complete Margolus iteration)
- **Rendering**: O(active_cells) drawing operations
- **Bottleneck**: JavaScript event loop (single-threaded)

## References

- [Gleam Language](https://gleam.run/)
- [Paint Library](https://hexdocs.pm/paint/)
- [Margolus Neighbourhoods](https://en.wikipedia.org/wiki/Block_cellular_automaton)
- [Cellular Automata](https://en.wikipedia.org/wiki/Cellular_automaton)
- [Falling Sand Simulators (HN)](https://news.ycombinator.com/item?id=11152881)

<!-- deciduous:start -->
## Decision Graph Workflow

**THIS IS MANDATORY. Log decisions IN REAL-TIME, not retroactively.**

### Available Slash Commands

| Command | Purpose |
|---------|---------|
| `/decision` | Manage decision graph - add nodes, link edges, sync |
| `/recover` | Recover context from decision graph on session start |
| `/work` | Start a work transaction - creates goal node before implementation |
| `/document` | Generate comprehensive documentation for a file or directory |
| `/build-test` | Build the project and run the test suite |
| `/serve-ui` | Start the decision graph web viewer |
| `/sync-graph` | Export decision graph to GitHub Pages |
| `/decision-graph` | Build a decision graph from commit history |
| `/sync` | Multi-user sync - pull events, rebuild, push |

### Available Skills

| Skill | Purpose |
|-------|---------|
| `/pulse` | Map current design as decisions (Now mode) |
| `/narratives` | Understand how the system evolved (History mode) |
| `/archaeology` | Transform narratives into queryable graph |

### The Node Flow Rule - CRITICAL

The canonical flow through the decision graph is:

```
goal -> options -> decision -> actions -> outcomes
```

- **Goals** lead to **options** (possible approaches to explore)
- **Options** lead to a **decision** (choosing which option to pursue)
- **Decisions** lead to **actions** (implementing the chosen approach)
- **Actions** lead to **outcomes** (results of the implementation)
- **Observations** attach anywhere relevant
- Goals do NOT lead directly to decisions -- there must be options first
- Options do NOT come after decisions -- options come BEFORE decisions
- Decision nodes should only be created when an option is actually chosen, not prematurely

### The Core Rule

```
BEFORE you do something -> Log what you're ABOUT to do
AFTER it succeeds/fails -> Log the outcome
CONNECT immediately -> Link every node to its parent
AUDIT regularly -> Check for missing connections
```

### Behavioral Triggers - MUST LOG WHEN:

| Trigger | Log Type | Example |
|---------|----------|---------|
| User asks for a new feature | `goal` **with -p** | "Add dark mode" |
| Exploring possible approaches | `option` | "Use Redux for state" |
| Choosing between approaches | `decision` | "Choose state management" |
| About to write/edit code | `action` | "Implementing Redux store" |
| Something worked or failed | `outcome` | "Redux integration successful" |
| Notice something interesting | `observation` | "Existing code uses hooks" |

### Document Attachments

Attach files (images, PDFs, diagrams, specs, screenshots) to decision graph nodes for rich context.

```bash
# Attach a file to a node
deciduous doc attach <node_id> <file_path>
deciduous doc attach <node_id> <file_path> -d "Architecture diagram"
deciduous doc attach <node_id> <file_path> --ai-describe

# List documents
deciduous doc list              # All documents
deciduous doc list <node_id>    # Documents for a specific node

# Manage documents
deciduous doc show <doc_id>     # Show document details
deciduous doc describe <doc_id> "Updated description"
deciduous doc describe <doc_id> --ai   # AI-generate description
deciduous doc open <doc_id>     # Open in default application
deciduous doc detach <doc_id>   # Soft-delete (recoverable)
deciduous doc gc                # Remove orphaned files from disk
```

**When to suggest document attachment:**

| Situation | Action |
|-----------|--------|
| User shares an image or screenshot | Ask: "Want me to attach this to the current goal/action node?" |
| User references an external document | Ask: "Should I attach a copy to the decision graph?" |
| Architecture diagram is discussed | Suggest attaching it to the relevant goal node |
| Files not in the project are dropped in | Attach to the most relevant active node |

**Do NOT aggressively prompt for documents.** Only suggest when files are directly relevant to a decision node. Files are stored in `.deciduous/documents/` with content-hash naming for deduplication.

### CRITICAL: Capture VERBATIM User Prompts

**Prompts must be the EXACT user message, not a summary.** When a user request triggers new work, capture their full message word-for-word.

**BAD - summaries are useless for context recovery:**
```bash
# DON'T DO THIS - this is a summary, not a prompt
deciduous add goal "Add auth" -p "User asked: add login to the app"
```

**GOOD - verbatim prompts enable full context recovery:**
```bash
# Use --prompt-stdin for multi-line prompts
deciduous add goal "Add auth" -c 90 --prompt-stdin << 'EOF'
I need to add user authentication to the app. Users should be able to sign up
with email/password, and we need OAuth support for Google and GitHub. The auth
should use JWT tokens with refresh token rotation.
EOF

# Or use the prompt command to update existing nodes
deciduous prompt 42 << 'EOF'
The full verbatim user message goes here...
EOF
```

**When to capture prompts:**
- Root `goal` nodes: YES - the FULL original request
- Major direction changes: YES - when user redirects the work
- Routine downstream nodes: NO - they inherit context via edges

**Updating prompts on existing nodes:**
```bash
deciduous prompt <node_id> "full verbatim prompt here"
cat prompt.txt | deciduous prompt <node_id>  # Multi-line from stdin
```

Prompts are viewable in the web viewer.

### CRITICAL: Maintain Connections

**The graph's value is in its CONNECTIONS, not just nodes.**

| When you create... | IMMEDIATELY link to... |
|-------------------|------------------------|
| `outcome` | The action that produced it |
| `action` | The decision that spawned it |
| `decision` | The option(s) it chose between |
| `option` | Its parent goal |
| `observation` | Related goal/action |
| `revisit` | The decision/outcome being reconsidered |

**Root `goal` nodes are the ONLY valid orphans.**

### Quick Commands

```bash
deciduous add goal "Title" -c 90 -p "User's original request"
deciduous add action "Title" -c 85
deciduous link FROM TO -r "reason"  # DO THIS IMMEDIATELY!
deciduous serve   # View live (auto-refreshes every 30s)
deciduous sync    # Export for static hosting

# Metadata flags
# -c, --confidence 0-100   Confidence level
# -p, --prompt "..."       Store the user prompt (use when semantically meaningful)
# -f, --files "a.rs,b.rs"  Associate files
# -b, --branch <name>      Git branch (auto-detected)
# --commit <hash|HEAD>     Link to git commit (use HEAD for current commit)
# --date "YYYY-MM-DD"      Backdate node (for archaeology)

# Branch filtering
deciduous nodes --branch main
deciduous nodes -b feature-auth
```

### CRITICAL: Link Commits to Actions/Outcomes

**After every git commit, link it to the decision graph!**

```bash
git commit -m "feat: add auth"
deciduous add action "Implemented auth" -c 90 --commit HEAD
deciduous link <goal_id> <action_id> -r "Implementation"
```

The `--commit HEAD` flag captures the commit hash and links it to the node. The web viewer will show commit messages, authors, and dates.

### Git History & Deployment

```bash
# Export graph AND git history for web viewer
deciduous sync

# This creates:
# - docs/graph-data.json (decision graph)
# - docs/git-history.json (commit info for linked nodes)
```

To deploy to GitHub Pages:
1. `deciduous sync` to export
2. Push to GitHub
3. Settings > Pages > Deploy from branch > /docs folder

Your graph will be live at `https://<user>.github.io/<repo>/`

### Branch-Based Grouping

Nodes are auto-tagged with the current git branch. Configure in `.deciduous/config.toml`:
```toml
[branch]
main_branches = ["main", "master"]
auto_detect = true
```

### Audit Checklist (Before Every Sync)

1. Does every **outcome** link back to what caused it?
2. Does every **action** link to why you did it?
3. Any **dangling outcomes** without parents?

### Git Staging Rules - CRITICAL

**NEVER use broad git add commands that stage everything:**
- ❌ `git add -A` - stages ALL changes including untracked files
- ❌ `git add .` - stages everything in current directory
- ❌ `git add -a` or `git commit -am` - auto-stages all tracked changes
- ❌ `git add *` - glob patterns can catch unintended files

**ALWAYS stage files explicitly by name:**
- ✅ `git add src/main.rs src/lib.rs`
- ✅ `git add Cargo.toml Cargo.lock`
- ✅ `git add .claude/commands/decision.md`

**Why this matters:**
- Prevents accidentally committing sensitive files (.env, credentials)
- Prevents committing large binaries or build artifacts
- Forces you to review exactly what you're committing
- Catches unintended changes before they enter git history

### Session Start Checklist

```bash
deciduous check-update    # Update needed? Run 'deciduous update' if yes
deciduous nodes           # What decisions exist?
deciduous edges           # How are they connected? Any gaps?
deciduous doc list        # Any attached documents to review?
git status                # Current state
```

### Multi-User Sync

Sync decisions with teammates via event logs:

```bash
# Check sync status
deciduous events status

# Apply teammate events (after git pull)
deciduous events rebuild

# Compact old events periodically
deciduous events checkpoint --clear-events
```

Events auto-emit on add/link/status commands. Git merges event files automatically.
<!-- deciduous:end -->
